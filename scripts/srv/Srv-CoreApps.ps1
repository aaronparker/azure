<# 
    .SYNOPSIS
        Install evergreen core applications.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Log = "$env:SystemRoot\Logs\AzureArmCustomDeploy.log",

    [Parameter(Mandatory = $False)]
    [System.String] $Target = "$env:SystemDrive\Apps"
)

#region Functions
Function Set-Repository {
    # Trust the PSGallery for modules
    If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
        Write-Verbose "Trusting the repository: PSGallery"
        Install-PackageProvider -Name "NuGet" -MinimumVersion 2.8.5.208 -Force
        Set-PSRepository -Name "PSGallery" -InstallationPolicy "Trusted"
    }
}

Function Invoke-Process {
    <#PSScriptInfo 
    .VERSION 1.4 
    .GUID b787dc5d-8d11-45e9-aeef-5cf3a1f690de 
    .AUTHOR Adam Bertram 
    .COMPANYNAME Adam the Automator, LLC 
    .TAGS Processes 
    #>

    <# 
    .DESCRIPTION 
    Invoke-Process is a simple wrapper function that aims to "PowerShellyify" launching typical external processes. There 
    are lots of ways to invoke processes in PowerShell with Invoke-Process, Invoke-Expression, & and others but none account 
    well for the various streams and exit codes that an external process returns. Also, it's hard to write good tests 
    when launching external proceses. 
 
    This function ensures any errors are sent to the error stream, standard output is sent via the Output stream and any 
    time the process returns an exit code other than 0, treat it as an error. 
    #> 
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $FilePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String] $ArgumentList
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
            Wait                   = $true
            PassThru               = $true
            NoNewWindow            = $true
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
                if ([System.String]::IsNullOrEmpty($cmdOutput) -eq $false) {
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

Function Install-RequiredModules {
    Write-Host "=========== Installing required modules"
    # Install the Evergreen module; https://github.com/aaronparker/Evergreen
    Install-Module -Name Evergreen -AllowClobber

    # Install the VcRedist module; https://docs.stealthpuppy.com/vcredist/
    Install-Module -Name VcRedist -AllowClobber
}

Function Install-VcRedistributables ($Path) {
    Write-Host "=========== Microsoft Visual C++ Redistributables"
    If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null }
    $VcList = Get-VcList -Release 2010, 2012, 2013, 2019

    Save-VcRedist -Path $Path -VcList $VcList -ForceWebRequest -Verbose
    Install-VcRedist -VcList $VcList -Path $Path -Verbose
    Write-Host "=========== Done"
}

Function Install-MicrosoftEdge ($Path) {
    Write-Host "=========== Microsoft Edge"
    $Edge = Get-MicrosoftEdge | Where-Object { $_.Architecture -eq "x64" -and $_.Channel -eq "Stable" }
    $Edge = $Edge | Sort-Object -Property Version -Descending | Select-Object -First 1

    If ($Edge) {
        Write-Host "================ Downloading Microsoft Edge"
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null }

        # Download
        $url = $Edge.URI
        $OutFile = Join-Path -Path $Path -ChildPath $(Split-Path -Path $url -Leaf)
        Write-Host "=========== Downloading to: $OutFile"
        try {
            Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
        }
        catch {
            Throw "Failed to download Microsoft Edge."
        }

        # Install
        Write-Host "================ Installing Microsoft Edge"
        try {
            Invoke-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/package $OutFile /quiet /norestart DONOTCREATEDESKTOPSHORTCUT=true" -Verbose
        }
        catch {
            Throw "Failed to install Microsoft Edge."
        }

        # Post install configuration
        Remove-Item -Path "$env:Public\Desktop\Microsoft Edge*.lnk" -Force -ErrorAction SilentlyContinue
        $url = "https://raw.githubusercontent.com/aaronparker/build-azure/master/tools/rds/master_preferences"
        Invoke-WebRequest -Uri $url -OutFile "${Env:ProgramFiles(x86)}\Microsoft\Edge\Application\$(Split-Path -Path $url -Leaf)" -UseBasicParsing
        $services = "edgeupdate", "edgeupdatem", "MicrosoftEdgeElevationService"
        ForEach ($service in $services) { Get-Service -Name $service | Set-Service -StartupType "Disabled" }
        ForEach ($task in (Get-ScheduledTask -TaskName *Edge*)) { Unregister-ScheduledTask -TaskName $Task -Confirm:$False -ErrorAction SilentlyContinue }
        Remove-Variable -Name url
        Write-Host "=========== Done"
    }
    Else {
        Write-Host "================ Failed to retreive Microsoft Edge"
    }
}
#endregion Functions


#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Start logging
Start-Transcript -Path $Log -Append -ErrorAction SilentlyContinue
If (!(Test-Path $Target)) { New-Item -Path $Target -Type Directory -Force -ErrorAction SilentlyContinue }

# Set TLS to 1.2; Create target folder
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
If (!(Test-Path $Target)) { New-Item -Path $Target -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" }

# Run tasks/install apps
Set-Repository
Install-RequiredModules
Install-VcRedistributables -Path "$Target\VcRedist"
Install-MicrosoftEdge -Path "$Target\Edge"

# Stop Logging
Stop-Transcript -ErrorAction SilentlyContinue
Write-Host "=========== Complete: $($MyInvocation.MyCommand)."
#endregion
