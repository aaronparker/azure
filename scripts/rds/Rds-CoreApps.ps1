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
    Write-Host "================ Installing required modules"
    # Install the Evergreen module; https://github.com/aaronparker/Evergreen
    Install-Module -Name Evergreen -AllowClobber

    # Install the VcRedist module; https://docs.stealthpuppy.com/vcredist/
    Install-Module -Name VcRedist -AllowClobber
}

Function Install-VcRedistributables ($Path) {
    Write-Host "================ Microsoft Visual C++ Redistributables"
    If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }
    $VcList = Get-VcList -Release 2010, 2012, 2013, 2019

    Write-Host "================ Downloading Microsoft Visual C++ Redistributables"
    Save-VcRedist -Path $Path -VcList $VcList > $Null
    Write-Host "================ Installing Microsoft Visual C++ Redistributables"
    Install-VcRedist -VcList $VcList -Path $Path -Silent
    Write-Host "================ Done"
}

Function Install-FSLogix ($Path) {
    Write-Host "================ Microsoft FSLogix agent"
    $FSLogix = Get-MicrosoftFSLogixApps

    If ($FSLogix) {
        Write-Host "================ Microsoft FSLogix: $($FSLogix.Version)"
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

        # Download
        $OutFile = $(Split-Path -Path $FSLogix.URI -Leaf)
        Write-Host "================ Downloading to: $Path\$OutFile"
        try {
            Invoke-WebRequest -Uri $FSLogix.URI -OutFile "$Path\$OutFile" -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
        }
        catch {
            Throw "Failed to download FSLogix Apps"
        }

        # Unpack and install
        Expand-Archive -Path "$Path\$OutFile" -DestinationPath $Path -Force
        Write-Host "================ Installing FSLogix agent"
        try {
            Invoke-Process -FilePath "$Path\x64\Release\FSLogixAppsSetup.exe" -ArgumentList "/install /quiet /norestart" -Verbose
        }
        catch {
            Throw "Failed to install the FSlogix Apps agent."
        }
        try {
            Invoke-Process -FilePath "$Path\x64\Release\FSLogixAppsRuleEditorSetup.exe" -ArgumentList "/install /quiet /norestart" -Verbose
        }
        catch {
            Throw "Failed to install the FSlogix Apps Rules Editor."
        }
        Write-Host "================ Done"
    }
    Else {
        Write-Host "================ Failed to retreive Microsoft FSLogix Apps"
    }
}

Function Install-MicrosoftEdge ($Path) {
    Write-Host "================ Microsoft Edge"
    $Edge = Get-MicrosoftEdge | Where-Object { $_.Architecture -eq "x64" -and $_.Channel -eq "Stable" }
    $Edge = $Edge | Sort-Object -Property Version -Descending | Select-Object -First 1

    If ($Edge) {
        Write-Host "================ Downloading Microsoft Edge"
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

        # Download
        $url = $Edge.URI
        $OutFile = Join-Path -Path $Path -ChildPath $(Split-Path -Path $url -Leaf)
        Write-Host "================ Downloading to: $OutFile"
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
        Write-Host "================ Post-install config"
        $prefs = @{
            "homepage"               = "https://www.office.com"
            "homepage_is_newtabpage" = $False
            "browser"                = @{
                "show_home_button" = $True
            }
            "distribution"           = @{
                "skip_first_run_ui"              = $True
                "show_welcome_page"              = $False
                "import_search_engine"           = $False
                "import_history"                 = $False
                "do_not_create_any_shortcuts"    = $False
                "do_not_create_taskbar_shortcut" = $False
                "do_not_create_desktop_shortcut" = $True
                "do_not_launch_chrome"           = $True
                "make_chrome_default"            = $True
                "make_chrome_default_for_user"   = $True
                "system_level"                   = $True
            }
        }
        $prefs | ConvertTo-Json | Set-Content -Path "${Env:ProgramFiles(x86)}\Microsoft\Edge\Application\master_preferences" -Force
        Remove-Item -Path "$env:Public\Desktop\Microsoft Edge*.lnk" -Force -ErrorAction SilentlyContinue
        $services = "edgeupdate", "edgeupdatem", "MicrosoftEdgeElevationService"
        ForEach ($service in $services) { Get-Service -Name $service | Set-Service -StartupType "Disabled" }
        ForEach ($task in (Get-ScheduledTask -TaskName *Edge*)) { Unregister-ScheduledTask -TaskName $Task -Confirm:$False -ErrorAction SilentlyContinue }
        Write-Host "================ Done"
    }
    Else {
        Write-Host "================ Failed to retreive Microsoft Edge"
    }
}

Function Install-MicrosoftOffice ($Path) {

    $OfficeXml = @"
    <Configuration ID="a39b1c70-558d-463b-b3d4-9156ddbcbb05">
    <Add OfficeClientEdition="64" Channel="MonthlyEnterprise" MigrateArch="TRUE">
      <Product ID="O365ProPlusRetail">
        <Language ID="MatchOS" />
        <Language ID="MatchPreviousMSI" />
        <ExcludeApp ID="Access" />
        <ExcludeApp ID="Groove" />
        <ExcludeApp ID="Lync" />
        <ExcludeApp ID="Publisher" />
        <ExcludeApp ID="Bing" />
        <ExcludeApp ID="Teams" />
      </Product>
    </Add>
    <Property Name="SharedComputerLicensing" Value="0" />
    <Property Name="PinIconsToTaskbar" Value="FALSE" />
    <Property Name="SCLCacheOverride" Value="0" />
    <Property Name="AUTOACTIVATE" Value="0" />
    <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
    <Property Name="DeviceBasedLicensing" Value="0" />
    <Updates Enabled="FALSE" />
    <RemoveMSI />
    <AppSettings>
    <User Key="software\microsoft\office\16.0\common\toolbars" Name="customuiroaming" Value="1" Type="REG_DWORD" App="office16" Id="L_AllowRoamingQuickAccessToolBarRibbonCustomizations" />
    <User Key="software\microsoft\office\16.0\common\general" Name="shownfirstrunoptin" Value="1" Type="REG_DWORD" App="office16" Id="L_DisableOptinWizard" />
    <User Key="software\microsoft\office\16.0\common\languageresources" Name="installlanguage" Value="3081" Type="REG_DWORD" App="office16" Id="L_PrimaryEditingLanguage" />
    <User Key="software\microsoft\office\16.0\common\fileio" Name="disablelongtermcaching" Value="1" Type="REG_DWORD" App="office16" Id="L_DeleteFilesFromOfficeDocumentCache" />
    <User Key="software\microsoft\office\16.0\common\graphics" Name="disablehardwareacceleration" Value="1" Type="REG_DWORD" App="office16" Id="L_DoNotUseHardwareAcceleration" />
    <User Key="software\microsoft\office\16.0\common\general" Name="disablebackgrounds" Value="1" Type="REG_DWORD" App="office16" Id="L_DisableBackgrounds" />
    <User Key="software\microsoft\office\16.0\firstrun" Name="disablemovie" Value="1" Type="REG_DWORD" App="office16" Id="L_DisableMovie" />
    <User Key="software\microsoft\office\16.0\firstrun" Name="bootedrtm" Value="1" Type="REG_DWORD" App="office16" Id="L_DisableOfficeFirstrun" />
    <User Key="software\microsoft\office\16.0\common" Name="default ui theme" Value="0" Type="REG_DWORD" App="office16" Id="L_DefaultUIThemeUser" />
    <User Key="software\microsoft\office\16.0\excel\options" Name="defaultformat" Value="51" Type="REG_DWORD" App="excel16" Id="L_SaveExcelfilesas" />
    <User Key="software\microsoft\office\16.0\onenote\options\other" Name="runsystemtrayapp" Value="0" Type="REG_DWORD" App="onent16" Id="L_AddOneNoteicontonotificationarea" />
    <User Key="software\microsoft\office\16.0\outlook\preferences" Name="disablemanualarchive" Value="1" Type="REG_DWORD" App="outlk16" Id="L_DisableFileArchive" />
    <User Key="software\microsoft\office\16.0\outlook\options\rss" Name="disable" Value="1" Type="REG_DWORD" App="outlk16" Id="L_TurnoffRSSfeature" />
    <User Key="software\microsoft\office\16.0\outlook\setup" Name="disableroamingsettings" Value="0" Type="REG_DWORD" App="outlk16" Id="L_DisableRoamingSettings" />
    <User Key="software\microsoft\office\16.0\powerpoint\options" Name="defaultformat" Value="27" Type="REG_DWORD" App="ppt16" Id="L_SavePowerPointfilesas" />
    <User Key="software\microsoft\office\16.0\word\options" Name="defaultformat" Value="" Type="REG_SZ" App="word16" Id="L_SaveWordfilesas" />
    </AppSettings>
    <Display Level="None" AcceptEULA="TRUE" />
    <Logging Level="Standard" Path="C:\Apps" />
  </Configuration>
"@

    # Get Office version
    Write-Host "================ Microsoft Office"
    $Office = Get-MicrosoftOffice | Where-Object { $_.Channel -eq "Monthly" }
    
    If ($Office) {
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }
        
        # Download setup.exe
        $url = $Office.URI
        $OutFile = Join-Path -Path $Path -ChildPath $(Split-Path -Path $url -Leaf)
        Write-Host "================ Downloading to: $OutFile"
        try {
            Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
        }
        catch {
            Throw "Failed to download Microsoft Office setup."
        }

        # Download Office package, Setup fails to exit, so wait 9-10 mins for Office install to complete
        Write-Host "================ Installing Microsoft Office"

        Push-Location -Path $Path
        $XmlFile = Join-Path -Path $Path -ChildPath "Office.xml"
        Out-File -FilePath $XmlFile -InputObject $OfficeXml -Encoding utf8

        Invoke-Process -FilePath $OutFile -ArgumentList "/configure $XmlFile" -Verbose
        Pop-Location
        Remove-Variable -Name url
        Write-Host "================ Done"
    }
    Else {
        Write-Host "================ Failed to retreive Microsoft Office"
    }
}

Function Install-MicrosoftWvdRtcService ($Path) {
    Write-Host "================ Microsoft Remote Desktop WebRTC"
    Write-Host "================ Downloading Microsoft Remote Desktop WebRTC"
    $Rtc = Get-MicrosoftWvdRtcService | Where-Object { $_.Architecture -eq "x64" }
    
    If ($Rtc) {
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

        # Download
        $OutFile = Join-Path -Path $Path -ChildPath $Rtc.Filename
        Write-Host "================ Downloading to: $OutFile"
        try {
            Invoke-WebRequest -Uri $Rtc.URI -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
        }
        catch {
            Throw "Failed to download Microsoft Remote Desktop WebRTC."
        }

        # Install
        Write-Host "================ Installing Microsoft Remote Desktop WebRTC"
        try {
            $ArgumentList = "/package $OutFile ALLUSERS=1 /quiet"
            Invoke-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList $ArgumentList -Verbose
        }
        catch {
            Throw "Failed to install Microsoft Remote Desktop WebRTC."
        }
        Write-Host "================ Done"
    }
    Else {
        Write-Host "================ Failed to retreive Microsoft Remote Desktop WebRTC"
    }
}

Function Install-MicrosoftWvdRtcService2 ($Path) {
    $Url = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RE4AQBt"
    $File = "MsRdcWebRTCSvc_HostSetup_1.0.2006.11001_x64.msi"

    If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }
    $OutFile = Join-Path -Path $Path -ChildPath $File
    Write-Host "================ Downloading to: $OutFile"
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -ErrorAction "SilentlyContinue"

    # Install
    Write-Host "================ Installing Microsoft Remote Desktop WebRTC"
    try {
        $ArgumentList = "/package $OutFile ALLUSERS=1 /quiet"
        Invoke-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList $ArgumentList -Verbose
    }
    catch {
        Throw "Failed to install Microsoft Remote Desktop WebRTC."
    }
    Write-Host "================ Done"
}

Function Install-MicrosoftTeams ($Path) {
    Write-Host "================ Microsoft Teams"
    Write-Host "================ Downloading Microsoft Teams"
    $Teams = Get-MicrosoftTeams | Where-Object { $_.Architecture -eq "x64" }
    
    If ($Teams) {
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

        # Download
        $url = $Teams.URI
        $OutFile = Join-Path -Path $Path -ChildPath $(Split-Path -Path $url -Leaf)
        Write-Host "================ Downloading to: $OutFile"
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
            reg add "HKLM\SOFTWARE\Microsoft\Teams" /v "IsWVDEnvironment" /t REG_DWORD /d 1 /f
            reg add "HKLM\SOFTWARE\Citrix\PortICA" /v "IsWVDEnvironment" /t REG_DWORD /d 1 /f
            $params = @{
                FilePath     = "$env:SystemRoot\System32\msiexec.exe"
                # ArgumentList = "/package $OutFile ALLUSER=1 ALLUSERS=1 " + 'OPTIONS="noAutoStart=true" /quiet'
                ArgumentList = "/package $OutFile ALLUSER=1 ALLUSERS=1 /quiet"
                Verbose      = $True
            }
            Invoke-Process @params
            Remove-Variable -Name url
        }
        catch {
            Throw "Failed to install Microsoft Teams."
        }
        Write-Host "================ Done"
    }
    Else {
        Write-Host "================ Failed to retreive Microsoft Teams"
    }
}

Function Set-TeamsAutostart {
    # Teams JSON files
    $Paths = @((Join-Path -Path "${env:ProgramFiles(x86)}\Teams Installer" -ChildPath "setup.json"), 
        (Join-Path -Path "${env:ProgramFiles(x86)}\Microsoft\Teams" -ChildPath "setup.json"))

    # Read the file and convert from JSON
    ForEach ($Path in $Paths) {
        If (Test-Path -Path $Path) {
            try {
                $Json = Get-Content -Path $Path | ConvertFrom-Json
                $Json.noAutoStart = $true
                $Json | ConvertTo-Json | Set-Content -Path $Path -Force
            }
            catch {
                Throw "Failed to set Teams autostart file: $Path."
            }
        }
    }

    # Delete the registry auto-start
    reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run" /v "Teams" /f
}

Function Uninstall-MicrosoftOneDrive {
    If (Get-Process -Name "OneDrive.exe" -ErrorAction SilentlyContinue ) { Stop-Process -Name "OneDrive.exe" -PassThru -ErrorAction SilentlyContinue }
    If (Get-Process -Name "Explorer.exe" -ErrorAction SilentlyContinue ) { Stop-Process -Name "OneDrive.exe" -PassThru -ErrorAction SilentlyContinue }
    if (Test-Path "$env:SystemRoot\System32\OneDriveSetup.exe") {
        Start-Process "$env:SystemRoot\System32\OneDriveSetup.exe" -ArgumentList "/uninstall" -Wait 
    }
    if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") {
        Start-Process "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" -ArgumentList "/uninstall" -Wait
    }
    $Shortcuts = "$env:SystemRoot\ServiceProfiles\LocalService\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk", `
        "$env:SystemRoot\ServiceProfiles\NetworkService\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk"
    ForEach ($shortcut in $Shortcuts) { If (Test-Path -Path $shortcut) { Remove-Item -Path $shortcut -Force } }
    Start-Process $env:SystemRoot\System32\Reg.exe -ArgumentList "Load HKLM\Temp C:\Users\Default\NTUSER.DAT" -Wait
    Start-Process $env:SystemRoot\System32\Reg.exe -ArgumentList "Delete HKLM\Temp\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /v OneDriveSetup /f" -Wait
    Start-Process $env:SystemRoot\System32\Reg.exe -ArgumentList "Unload HKLM\Temp" -Wait
    Start-Process -FilePath $env:SystemRoot\Explorer.exe -Wait
}

Function Install-MicrosoftOneDrive ($Path) {
    Write-Host "================ Microsoft OneDrive"    
    Write-Host "================ Downloading Microsoft OneDrive"
    $OneDrive = Get-MicrosoftOneDrive | Where-Object { $_.Ring -eq "Production" } | Sort-Object -Property Version | Select-Object -First 1

    If ($OneDrive) {
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

        # Download
        $url = $OneDrive.URI
        $OutFile = Join-Path -Path $Path -ChildPath $(Split-Path -Path $url -Leaf)
        Write-Host "================ Downloading to: $OutFile"
        try {
            Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
        }
        catch {
            Write-Warning "Failed to download Microsoft OneDrive. Falling back to direct URL."
            $url = "https://oneclient.sfx.ms/Win/Prod/20.052.0311.0011/OneDriveSetup.exe"
            $OutFile = Join-Path -Path $Path -ChildPath $(Split-Path -Path $url -Leaf)
            Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
        }
    
        # Install
        Write-Host "================ Installing Microsoft OneDrive"
        try {
            Invoke-Process -FilePath $OutFile -ArgumentList "/ALLUSERS" -Verbose
        }
        catch {
            Throw "Failed to install Microsoft OneDrive."
        }
        Remove-Variable -Name url
        Write-Host "================ Done"
    }
    Else {
        Write-Host "================ Failed to retreive Microsoft OneDrive"
    }
}

Function Install-AdobeReaderDC ($Path) {
    # Enforce settings with GPO: https://www.adobe.com/devnet-docs/acrobatetk/tools/AdminGuide/gpo.html
    # Download Reader installer and updater
    Write-Host "================ Adobe Acrobat Reader DC"
    Write-Host "================ Downloading Reader"
    $Reader = Get-AdobeAcrobatReaderDC | Where-Object { $_.Platform -eq "Windows" -and ($_.Language -eq "English" -or $_.Language -eq "Neutral") }

    If ($Reader) {
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }
        
        # Download Adobe Reader
        ForEach ($File in $Reader) {
            $url = $File.Uri
            $OutFile = Join-Path -Path $Path -ChildPath (Split-Path -Path $url -Leaf)
            Write-Host "================ Downloading to: $OutFile."
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
            $Installers = Get-ChildItem -Path $Path -Filter "*.exe"
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
            $Updates = Get-ChildItem -Path $Path -Filter "*.msp"
            ForEach ($msp in $Updates) {
                Write-Host "================ Installing update: $($msp.FullName)."
                Invoke-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/update $($msp.FullName) /quiet /qn" -Verbose
            }
        }
        catch {
            "Throw failed to update Adobe Reader."
        }
        Write-Host "================ Done"
    }
    Else {
        Write-Host "================ Failed to retreive Adobe Reader"
    }
}

Function Install-ConnectionExperienceIndicator ($Path) {

    Write-Host "================ Connection Experience Indicator"
    Write-Host "================ Downloading Connection Experience Indicator"

    # Parameters
    $Url = "https://bit.ly/2RrQTd3"
    $OutFile = Join-Path -Path $Path -ChildPath "ConnectionExperienceIndicator.zip"
    If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

    # Download the file
    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
    }
    catch {
        Throw "Failed to download Connection Experience Indicator."
        Break
    }

    # Extract the zip file
    Expand-Archive -Path $OutFile -DestinationPath $Path
    Write-Host "================ Done"
}
#endregion Functions


#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Start logging
Start-Transcript -Path $Log -Append -ErrorAction SilentlyContinue

# Set TLS to 1.2; Create target folder
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
New-Item -Path $Target -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

# Run tasks/install apps
Set-Repository
Install-RequiredModules
Install-VcRedistributables -Path "$Target\VcRedist"
Install-FSLogix -Path "$Target\FSLogix"
Install-MicrosoftEdge -Path "$Target\Edge"
Install-MicrosoftOffice -Path "$Target\Office"
Install-MicrosoftTeams -Path "$Target\Teams"
Install-MicrosoftWvdRtcService2 -Path "$Target\Wvd"
Set-TeamsAutostart
Install-MicrosoftOneDrive -Path "$Target\OneDrive"
Install-AdobeReaderDC -Path "$Target\AdobeReader"
Install-ConnectionExperienceIndicator -Path "$Target\ConnectionExperienceIndicator"

# Stop Logging
Stop-Transcript -ErrorAction SilentlyContinue
Write-Host "================ Complete: $($MyInvocation.MyCommand)."
Exit 0
#endregion
