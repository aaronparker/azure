<# 
    .SYNOPSIS
        Customise a Windows Server image for use as an RDS/XenApp VM in Azure.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Log = "$env:SystemRoot\Logs\AzureArmCustomDeploy.log",

    [Parameter(Mandatory = $False)]
    [System.String] $Target = "$env:SystemDrive\Apps"
)

# Make Invoke-WebRequest faster
$ProgressPreference = "SilentlyContinue"

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

Function Install-CoreApps {
    # Set TLS to 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    #region Modules
    Write-Host "=========== Installing required modules"
    # Install the Evergreen module
    # https://github.com/aaronparker/Evergreen
    Install-Module -Name Evergreen -AllowClobber
    # Install the VcRedist module
    # https://docs.stealthpuppy.com/vcredist/
    Install-Module -Name VcRedist -AllowClobber
    #endregion


    #region VcRedist
    Write-Host "=========== Microsoft Visual C++ Redistributables"
    $Dest = "$Target\VcRedist"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }
    $VcList = Get-VcList -Release 2010, 2012, 2013, 2019
    Save-VcRedist -Path $Dest -VcList $VcList -ForceWebRequest -Verbose
    Install-VcRedist -VcList $VcList -Path $Dest -Verbose
    Write-Host "=========== Done"
    #endregion


    #region FSLogix Apps
    Write-Host "=========== Microsoft FSLogix agent"
    $FSLogix = Get-MicrosoftFSLogixApps

    If ($FSLogix) {
        Write-Host "=========== Microsoft FSLogix: $($FSLogix.Version)"
        $Dest = "$Target\FSLogix"
        If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }

        # Download
        $OutFile = $(Split-Path -Path $FSLogix.URI -Leaf)
        Write-Host "=========== Downloading to: $Dest\$OutFile"
        try {
            Invoke-WebRequest -Uri $FSLogix.URI -OutFile "$Dest\$OutFile" -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
        }
        catch {
            Throw "Failed to download FSLogix Apps"
        }

        # Unpack and install
        Expand-Archive -Path "$Dest\$OutFile" -DestinationPath $Dest -Force
        Write-Host "================ Installing FSLogix agent"
        try {
            Invoke-Process -FilePath "$Dest\x64\Release\FSLogixAppsSetup.exe" -ArgumentList "/install /quiet /norestart" -Verbose
        }
        catch {
            Throw "Failed to install the FSlogix Apps agent."
        }
        try {
            Invoke-Process -FilePath "$Dest\x64\Release\FSLogixAppsRuleEditorSetup.exe" -ArgumentList "/install /quiet /norestart" -Verbose
        }
        catch {
            Throw "Failed to install the FSlogix Apps Rules Editor."
        }
        Write-Host "=========== Done"
    }
    Else {
        Write-Host "================ Failed to retreive Microsoft FSLogix Apps"
    }
    #endregion


    #region Edge
    Write-Host "=========== Microsoft Edge"
    $Edge = Get-MicrosoftEdge | Where-Object { $_.Architecture -eq "x64" -and $_.Channel -eq "Stable" }
    $Edge = $Edge | Sort-Object -Property Version -Descending | Select-Object -First 1

    If ($Edge) {
        Write-Host "================ Downloading Microsoft Edge"
        $Dest = "$Target\Edge"
        If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }

        # Download
        $url = $Edge.URI
        $OutFile = Join-Path -Path $Dest -ChildPath $(Split-Path -Path $url -Leaf)
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
    #endregion


    #region Office 365 ProPlus
    Write-Host "=========== Microsoft Office"

    # Get Office version
    $Office = Get-MicrosoftOffice | Where-Object { $_.Channel -eq "Monthly" }
    $url = $Office.URI
    
    If ($Office) {

        $Dest = "$Target\Office"
        If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }

        $xml = "https://raw.githubusercontent.com/aaronparker/build-azure/master/tools/rds/Office365ProPlusRDS.xml"
        Write-Host "=========== Downloading to: $Dest\$(Split-Path -Path $xml -Leaf)"
        Invoke-WebRequest -Uri $xml -OutFile "$Dest\$(Split-Path -Path $xml -Leaf)" -UseBasicParsing
        
        # Download setup.exe
        $OutFile = Join-Path -Path $Dest -ChildPath $(Split-Path -Path $url -Leaf)
        Write-Host "=========== Downloading to: $OutFile"
        try {
            Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
        }
        catch {
            Throw "Failed to download Microsoft Office setup."
        }

        # Download Office package, Setup fails to exit, so wait 9-10 mins for Office install to complete
        Push-Location -Path $Dest
        Write-Host "================ Installing Microsoft Office"
        Invoke-Process -FilePath $OutFile -ArgumentList "/configure $Dest\$(Split-Path -Path $xml -Leaf)" -Verbose
        <#For ($i = 0; $i -le 9; $i++) {
            Write-Host "================ Sleep $(10 - $i) mins for Office setup"
            Start-Sleep -Seconds 60
        }#>
        Pop-Location
        Remove-Variable -Name url
        Write-Host "=========== Done"
    }
    Else {
        Write-Host "================ Failed to retreive Microsoft Office"
    }
    #endregion


    #region Teams
    Write-Host "=========== Microsoft Teams"
    Write-Host "================ Downloading Microsoft Teams"
    $Teams = Get-MicrosoftTeams | Where-Object { $_.Architecture -eq "x64" }
    
    If ($Teams) {
        $Dest = "$Target\Teams"
        If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }

        # Download
        $url = $Teams.URI
        $OutFile = Join-Path -Path $Dest -ChildPath $(Split-Path -Path $url -Leaf)
        Write-Host "=========== Downloading to: $OutFile"
        try {
            Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
        }
        catch {
            Throw "Failed to download Microsoft Teams."
        }

        # Install
        Write-Host "================ Installing Microsoft Teams"
        try {
            reg add "HKLM\SOFTWARE\Microsoft\Teams" /v "IsWVDEnvironment" /t REG_DWORD /d 1
            $ArgumentList = '/package $OutFile /quiet /qn ALLUSER=1 ALLUSERS=1 OPTIONS="noAutoStart=true"'
            Invoke-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList $ArgumentList -Verbose
            <#For ($i = 0; $i -le 2; $i++) {
                Write-Host "================ Sleep $(3 - $i) mins for Teams setup"
                Start-Sleep -Seconds 60
            }#>
            Remove-Variable -Name url
        }
        catch {
            Throw "Failed to install Microsoft Teams."
        }
        Write-Host "=========== Done"
    }
    Else {
        Write-Host "================ Failed to retreive Microsoft Teams"
    }
    #endregion


    #region OneDrive
    Write-Host "=========== Microsoft OneDrive"    
    Write-Host "================ Downloading Microsoft OneDrive"
    $OneDrive = Get-MicrosoftOneDrive | Where-Object { $_.Ring -eq "Enterprise" }

    If ($OneDrive) {
        $Dest = "$Target\OneDrive"
        If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }

        # Download
        $url = $OneDrive.URI
        $OutFile = Join-Path -Path $Dest -ChildPath $(Split-Path -Path $url -Leaf)
        Write-Host "=========== Downloading to: $OutFile"
        try {
            Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
        }
        catch {
            Throw "Failed to download Microsoft OneDrive."
        }
    
        # Install
        Write-Host "================ Installing Microsoft OneDrive"
        try {
            Invoke-Process -FilePath $OutFile -ArgumentList "/ALLUSERS=1" -Verbose
        }
        catch {
            Throw "Failed to install Microsoft OneDrive."
        }
        Remove-Variable -Name url
        Write-Host "=========== Done"
    }
    Else {
        Write-Host "================ Failed to retreive Microsoft OneDrive"
    }
    #endregion

        
    #region Reader
    # Install Adobe Reader DC
    # Enforce settings with GPO: https://www.adobe.com/devnet-docs/acrobatetk/tools/AdminGuide/gpo.html
    Write-Host "=========== Adobe Acrobat Reader DC"

    # Download Reader installer and updater
    Write-Host "================ Downloading Reader"
    $Reader = Get-AdobeAcrobatReaderDC | Where-Object { $_.Platform -eq "Windows" -and ($_.Language -eq "English" -or $_.Language -eq "Neutral") }

    If ($Reader) {
        $Dest = "$Target\Reader"
        If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null }
        
        # Download Adobe Reader
        ForEach ($File in $Reader) {
            $url = $File.Uri
            $OutFile = Join-Path -Path $Dest -ChildPath (Split-Path -Path $url -Leaf)
            Write-Host "=========== Downloading to: $OutFile."
            try {
                (New-Object System.Net.WebClient).DownloadFile($url, $OutFile)
                If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
            }
            catch {
                Throw "Failed to download Adobe Reader."
            }
        }

        # Get resource strings
        $res = Export-EvergreenFunctionStrings -AppName "AdobeAcrobatReaderDC"

        # Install Adobe Reader
        Write-Host "================ Installing Reader"
        try {
            $Installers = Get-ChildItem -Path $Dest -Filter "*.exe"
            ForEach ($exe in $Installers) {
                Invoke-Process -FilePath $exe.FullName -ArgumentList $res.Install.Virtual.Arguments -Verbose
            }
        }
        catch {
            "Throw failed to install Adobe Reader."
        }

        # Run post install actions
        Write-Host "================ Post install configuration Reader"
        ForEach ($command in $res.Install.Virtual.PostInstall) {
            Invoke-Command -ScriptBlock ($executioncontext.invokecommand.NewScriptBlock($command))
        }

        # Update Adobe Reader
        Write-Host "================ Update Reader"
        try {
            $Updates = Get-ChildItem -Path $Dest -Filter "*.msp"
            ForEach ($msp in $Updates) {
                Write-Host "================ Installing update: $($msp.FullName)."
                Invoke-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/update $($msp.FullName) /quiet /qn" -Verbose
            }
        }
        catch {
            "Throw failed to update Adobe Reader."
        }
        Write-Host "=========== Done"
    }
    Else {
        Write-Host "================ Failed to retreive Adobe Reader"
    }
    #endregion


    #region Default Apps & File Type Associations
    <#
    $url = "https://raw.githubusercontent.com/aaronparker/build-azure/master/tools/rds/FileTypeAssociations.xml"
    $output = "$Target\$(Split-Path -Path $url -Leaf)"
    Invoke-WebRequest -Uri $url -OutFile $output -UseBasicParsing
    Invoke-Process -FilePath "$env:SystemRoot\System32\dism.exe" -ArgumentList "/Online /Import-DefaultAppAssociations:$output" -Verbose
    Remove-Variable -Name url
    #>
    #endregion
}
#endregion


#region Script logic
# Start logging
Write-Host "=========== Running: $($MyInvocation.MyCommand)."
Start-Transcript -Path $Log -Append

# If local path for script doesn't exist, create it
If (!(Test-Path $Target)) { New-Item -Path $Target -ItemType Directory -Force -ErrorAction SilentlyContinue }

# Run tasks
Set-Repository
Install-CoreApps

# Stop Logging
Stop-Transcript
Write-Host "=========== Complete: $($MyInvocation.MyCommand)."
#endregion
