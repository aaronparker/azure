<# 
    .SYNOPSIS
        Install evergreen core applications.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Log = "$env:SystemRoot\Logs\PackerImagePrep.log",

    [Parameter(Mandatory = $False)]
    [System.String] $Target = "$env:SystemDrive\Apps"
)

#region Functions
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
    $OneDrive = Get-MicrosoftOneDrive | Where-Object { $_.Ring -eq "Production" -and $_.Type -eq "Exe" } | `
        Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true } | Select-Object -First 1

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
Install-MicrosoftOffice -Path "$Target\Office"
Install-MicrosoftTeams -Path "$Target\Teams"
Set-TeamsAutostart
Install-MicrosoftOneDrive -Path "$Target\OneDrive"

# Stop Logging
Stop-Transcript -ErrorAction SilentlyContinue
Write-Host "================ Complete: $($MyInvocation.MyCommand)."
#endregion
