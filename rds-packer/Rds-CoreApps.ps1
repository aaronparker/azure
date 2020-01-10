<# 
    .SYNOPSIS
        Customise a Windows Server image for use as an RDS/XenApp VM in Azure.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [string] $Log = "$env:SystemRoot\Logs\AzureArmCustomDeploy.log",

    [Parameter(Mandatory = $False)]
    [string] $Target = "$env:SystemDrive\Apps",
    
    [Parameter(Mandatory = $False)]
    [string] $VerbosePreference = "Continue"
)

#region Functions
Function Set-Repository {
    # Trust the PSGallery for modules
    If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
        Write-Verbose "Trusting the repository: PSGallery"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
}

Function Invoke-Process {
    <# 
    .DESCRIPTION 
        Invoke-Process is a simple wrapper function that aims to "PowerShellyify" launching typical external processes. There 
        are lots of ways to invoke processes in PowerShell with Start-Process, Invoke-Expression, & and others but none account 
        well for the various streams and exit codes that an external process returns. Also, it's hard to write good tests 
        when launching external proceses. 
    
        This function ensures any errors are sent to the error stream, standard output is sent via the Output stream and any 
        time the process returns an exit code other than 0, treat it as an error. 
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ArgumentList
    )

    $ErrorActionPreference = 'Stop'

    try {
        $stdOutTempFile = "$env:TEMP\$((New-Guid).Guid)"
        $stdErrTempFile = "$env:TEMP\$((New-Guid).Guid)"

        $startProcessParams = @{
            FilePath               = $FilePath
            ArgumentList           = $ArgumentList
            RedirectStandardError  = $stdErrTempFile
            RedirectStandardOutput = $stdOutTempFile
            Wait                   = $true;
            PassThru               = $true;
            NoNewWindow            = $true;
        }
        if ($PSCmdlet.ShouldProcess("Process [$($FilePath)]", "Run with args: [$($ArgumentList)]")) {
            $cmd = Start-Process @startProcessParams
            $cmdOutput = Get-Content -Path $stdOutTempFile -Raw
            $cmdError = Get-Content -Path $stdErrTempFile -Raw
            if ($cmd.ExitCode -ne 0) {
                if ($cmdError) {
                    throw $cmdError.Trim()
                }
                if ($cmdOutput) {
                    throw $cmdOutput.Trim()
                }
            }
            else {
                if ([string]::IsNullOrEmpty($cmdOutput) -eq $false) {
                    Write-Output -InputObject $cmdOutput
                }
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        Remove-Item -Path $stdOutTempFile, $stdErrTempFile -Force -ErrorAction Ignore
    }
}

Function Install-CoreApps {
    #region VcRedist
    # Install the VcRedist module
    # https://docs.stealthpuppy.com/vcredist/
    Install-Module -Name VcRedist -AllowClobber

    Write-Host "========== Microsoft Visual C++ Redistributables"
    $Dest = "$Target\VcRedist"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue }
    $VcList = Get-VcList
    Save-VcRedist -Path $Dest -VcList $VcList -ForceWebRequest -Verbose
    Install-VcRedist -VcList $VcList -Path $Dest -Verbose
    #endregion

    # Install the Evergreen module
    Install-Module -Name Evergreen -AllowClobber

    #region FSLogix Apps
    Write-Host "========== Microsoft FSLogix agent"
    $Dest = "$Target\FSLogix"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue }

    $FSLogix = Get-MicrosoftFSLogixApps
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $FSLogix.URI -OutFile "$Dest\$(Split-Path -Path $FSLogix.URI -Leaf)" -UseBasicParsing
    Expand-Archive -Path "$Dest\$(Split-Path -Path $FSLogix.URI -Leaf)" -DestinationPath $Dest -Force
    Start-Process -FilePath "$Dest\x64\Release\FSLogixAppsSetup.exe" -ArgumentList "/install /quiet /norestart" -Wait
    #region


    #region Edge
    Write-Host "========== Microsoft Edge"
    $Dest = "$Target\Edge"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue }

    Write-Host "=============== Downloading Microsoft Edge"
    $url = "http://dl.delivery.mp.microsoft.com/filestreamingservice/files/89e511fc-33dd-4869-b781-81b4264b3e1e/MicrosoftEdgeBetaEnterpriseX64.msi"
    Invoke-WebRequest -Uri $url -OutFile "$Dest\$(Split-Path -Path $url -Leaf)" -UseBasicParsing

    Write-Host "=============== Installing Microsoft Edge"
    Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/package $Dest\$(Split-Path -Path $url -Leaf) /quiet /norestart" -Wait
    Remove-Item -Path "$env:Public\Desktop\Microsoft Edge*.lnk" -Force
    #endregion


    #region Office
    Write-Host "========== Microsoft Office"
    # Install Office 365 ProPlus; manage installed options in configurationRDS.xml
    $Dest = "$Target\Office"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue }

    # Get the Office configuration.xml
    $url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/scripts/rds/Office/configurationRDS.xml"
    Invoke-WebRequest -Uri $url -OutFile "$Dest\$(Split-Path -Path $url -Leaf)" -UseBasicParsing

    $Office = Get-MicrosoftOffice
    Invoke-WebRequest -Uri $Office[0].URI -OutFile "$Dest\$(Split-Path -Path $Office[0].URI -Leaf)"
    Push-Location -Path $Dest
    Write-Host "=============== Downloading Microsoft Office"
    Invoke-Process -FilePath "$Dest\$(Split-Path -Path $Office[0].URI -Leaf)" -ArgumentList "/download $Dest\$(Split-Path -Path $url -Leaf)"
    Write-Host "=============== Installing Microsoft Office"
    Invoke-Process -FilePath "$Dest\$(Split-Path -Path $Office[0].URI -Leaf)" -ArgumentList "/configure $Dest\$(Split-Path -Path $url -Leaf)"
    Pop-Location
    #endregion


    #region Reader
    # Install Adobe Reader DC
    # Enforce settings with GPO: https://www.adobe.com/devnet-docs/acrobatetk/tools/AdminGuide/gpo.html
    Write-Host "========== Adobe Acrobat Reader DC"
    $Dest = "$Target\Reader"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue }

    # Download Reader installer and updater
    Write-Host "=============== Downloading Reader"
    $Reader = Get-AdobeAcrobatReaderDC | Where-Object { $_.Platform -eq "Windows" -and ($_.Language -eq "English" -or $_.Language -eq "Neutral") }
    ForEach ($File in $Reader) {
        Invoke-WebRequest -Uri $File.Uri -OutFile (Join-Path -Path $Dest -ChildPath (Split-Path -Path $File.Uri -Leaf)) -UseBasicParsing
    }

    # Get resource strings
    $res = Export-EvergreenFunctionStrings -AppName "AdobeAcrobatReaderDC"

    # Install Adobe Reader
    Write-Host "=============== Installing Reader"
    $exe = Get-ChildItem -Path $Dest -Filter "*.exe"
    Start-Process -FilePath $exe.FullName -ArgumentList $res.Install.Virtual.Arguments -Wait

    # Run post install actions
    Write-Host "=============== Post install configuration Reader"
    ForEach ($command in $res.Install.Virtual.PostInstall) {
        Invoke-Command -ScriptBlock ($executioncontext.invokecommand.NewScriptBlock($command))
    }

    # Update Adobe Reader
    Write-Host "=============== Update Reader"
    $msp = Get-ChildItem -Path $Dest -Filter "*.msp"
    Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/update $($msp.FullName) /quiet" -Wait
    #endregion
}
#endregion

#region Script logic
# Start logging
Write-Host "========== Running: $($MyInvocation.MyCommand)."
Start-Transcript -Path $Log -Append

# If local path for script doesn't exist, create it
If (!(Test-Path $Target)) { New-Item -Path $Target -ItemType Directory -Force -ErrorAction SilentlyContinue }

# Block the master image from registering with Azure AD; Enable autoWorkplaceJoin after the VMs are provisioned via GPO.
Set-ItemProperty -Path HKLM:\Software\Policies\Microsoft\Windows\WorkplaceJoin -Name autoWorkplaceJoin -Value 0 -Force

# Run tasks
Set-Repository
Install-CoreApps

# Stop Logging
Stop-Transcript
Write-Host "========== Complete: $($MyInvocation.MyCommand)."
#endregion
