<# 
    .SYNOPSIS
        Enable/disable Windows roles and features and set language/regional settings.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Log = "$env:SystemRoot\Logs\AzureArmCustomDeploy.log",

    [Parameter(Mandatory = $False)]
    [System.String] $Target = "$env:SystemDrive\Apps"
)

#region Functions
Function Set-RegionalSettings ($Path, $Locale) {
    If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" }

    # Select the locale
    Switch ($Locale) {
        "en-US" {
            # United States
            $GeoId = 244
            $Timezone = "Pacific Standard Time"
        }
        "en-GB" {
            # Great Britain
            $GeoId = 242
            $Timezone = "GMT Standard Time"
        }
        "en-AU" {
            # Australia
            $GeoId = 12
            $Timezone = "AUS Eastern Standard Time"
        }
        Default {
            # Australia
            $GeoId = 12
            $Timezone = "AUS Eastern Standard Time"
        }
    }

    # Set regional settings
    Import-Module -Name "International"
    Set-WinSystemLocale -SystemLocale $Locale
    Set-WinUserLanguageList -LanguageList $Locale -Force
    Set-WinHomeLocation -GeoId $GeoId
    Set-TimeZone -Id $Timezone -Verbose
    
    try {
        # Download the language file
        $url = "https://raw.githubusercontent.com/aaronparker/build-azure/master/tools/$Locale-Language.xml"
        $OutFile = "$Path\$(Split-Path $url -Leaf)"
        Invoke-WebRequest -Uri $url -OutFile $OutFile
    }
    catch {
        Throw "Failed to download language file."
        Break
    }
    try {
        & $env:SystemRoot\System32\control.exe "intl.cpl,,/f:$OutFile"
    }
    catch {
        Throw "Failed to set regional settings."
    }
}

Function Set-Roles {
    Switch -Regex ((Get-WmiObject Win32_OperatingSystem).Caption) {
        "Microsoft Windows Server*" {
            # Add / Remove roles (requires reboot at end of deployment)
            Disable-WindowsOptionalFeature -Online -FeatureName "Printing-XPSServices-Features", "WindowsMediaPlayer" -NoRestart -WarningAction SilentlyContinue
            Uninstall-WindowsFeature -Name BitLocker, EnhancedStorage, PowerShell-ISE
            Add-WindowsFeature -Name RDS-RD-Server, Server-Media-Foundation, 'Search-Service', NET-Framework-Core

            # Configure services
            Set-Service Audiosrv -StartupType Automatic
            Set-Service WSearch -StartupType Automatic
            Break
        }
        "Microsoft Windows 10 Enterprise for Virtual Desktops" {
            Break
        }
        "Microsoft Windows 10 Enterprise" {
            Break
        }
        "Microsoft Windows 10*" {
            Break
        }
        Default {
        }
    }
}
#endregion

#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Start logging
Start-Transcript -Path $Log -Append -ErrorAction SilentlyContinue

# Set TLS to 1.2; Create target folder
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
New-Item -Path $Target -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

# Ready image
Write-Output "====== Disable Windows Defender real time scan"
Set-MpPreference -DisableRealtimeMonitoring $true

# Run tasks
If (Test-Path -Path env:Locale) {
    $Locale = $env:Locale
}
Else {
    Write-Output "====== Can't find passed parameter, setting Locale to en-AU."
    $Locale = "en-AU"
}
Set-RegionalSettings -Path $Target -Locale $Locale
Set-Roles

# Stop Logging
Stop-Transcript -ErrorAction SilentlyContinue
Write-Host "Complete: $($MyInvocation.MyCommand)."
