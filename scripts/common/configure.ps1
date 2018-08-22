<# 
    .SYNOPSIS
        Customise a Windows Server image in Azure.
        Sets regional settings, installs Windows Updates, configures the default profile.
        Runs Windows Defender quick scan
#>
[CmdletBinding()]
Param (
    [Parameter()] $Log = "$env:SystemRoot\Logs\AzureArmCustomDeploy.log",
    [Parameter()] $VerbosePreference = "Continue"
)

# Start logging
Start-Transcript -Path $Log

#region Configure system

# Regional settings - set to en-AU / Australia
Import-Module International
Set-WinHomeLocation -GeoId 12
Set-WinSystemLocale -SystemLocale en-AU
Set-TimeZone -Id "AUS Eastern Standard Time" -Verbose
$url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/scripts/common/language.xml"
Start-BitsTransfer -Source $url -Destination "$Target\$(Split-Path $url -Leaf)"
& $env:SystemRoot\System32\control.exe "intl.cpl,,/f:`"$Target\language.xml`""

# Add / Remove roles (requires reboot at end of deployment)
Disable-WindowsOptionalFeature -Online -FeatureName "Printing-XPSServices-Features", "FS-SMB1" -NoRestart -WarningAction SilentlyContinue
# Add-WindowsFeature -Name NET-Framework-Core

#endregion

#region Customisations
# DisableIEEnhancedSecurity 
If (Test-Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}") {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Type DWORD -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Type DWORD -Value 0
}

# HideServerManagerOnLogin 
If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Server\ServerManager")) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Server\ServerManager" -Force
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Server\ServerManager" -Name "DoNotOpenAtLogon" -Type DWORD -Value 1

# EnableSmartScreen
If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System")) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Force
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableSmartScreen" -Type DWORD -Value 2

# DisableAutorun
If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer")) {
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -Type DWORD -Value 255
#endregion

# Stop Logging
Stop-Transcript

# Replace clear text passwords in the log file
(Get-Content $Log).replace($Pass, "") | Set-Content $Log
