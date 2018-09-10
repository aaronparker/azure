<# 
    .SYNOPSIS
        Customise a Windows Server image for use as an RDS/XenApp VM in Azure.
        Installs Office 365 ProPlus, Adobe Reader DC, Visual C++ Redistributables. Installs applications from a network path specified in AppShare.
        Sets regional settings, installs Windows Updates, configures the default profile.
        Runs Windows Defender quick scan, Citrix Optimizer, BIS-F
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [string] $Log = "$env:SystemRoot\Logs\AzureArmCustomDeploy.log",

    [Parameter(Mandatory = $False)]
    [string] $Target = "$env:SystemDrive\Apps",
    
    [Parameter(Mandatory = $False)]
    [string] $User,
    
    [Parameter(Mandatory = $False)]
    [string] $Pass,
    
    [Parameter(Mandatory = $False)]
    [string] $AppShare,
    
    [Parameter(Mandatory = $False)]
    [string] $VerbosePreference = "Continue"
)

#region Functions
Function Set-Repository {
    # Trust the PSGallery for installing modules
    If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
        Write-Verbose "Trusting the repository: PSGallery"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
}

Function Set-RegionalSettings {
    Set-Repository
    # Regional settings - set to en-AU / Australia
    Import-Module International
    Set-WinHomeLocation -GeoId 12
    Set-WinSystemLocale -SystemLocale en-AU
    Set-TimeZone -Id "AUS Eastern Standard Time" -Verbose
    $url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/scripts/common/language.xml"
    Start-BitsTransfer -Source $url -Destination "$Target\$(Split-Path $url -Leaf)"
    & $env:SystemRoot\System32\control.exe "intl.cpl,,/f:`"$Target\language.xml`""
}

Function Set-Roles {
    # Add / Remove roles (requires reboot at end of deployment)
    Disable-WindowsOptionalFeature -Online -FeatureName "Printing-XPSServices-Features", "WindowsMediaPlayer" -NoRestart -WarningAction SilentlyContinue
    Uninstall-WindowsFeature -Name BitLocker, EnhancedStorage, PowerShell-ISE
    Add-WindowsFeature -Name RDS-RD-Server, Server-Media-Foundation, 'Search-Service', NET-Framework-Core

    # Configure services
    Set-Service Audiosrv -StartupType Automatic
    Set-Service WSearch -StartupType Automatic
}
#endregion

#region Script logic
# Start logging
Start-Transcript -Path $Log -Append

# If local path for script doesn't exist, create it
If (!(Test-Path $Target)) { New-Item -Path $Target -Type Directory -Force }

# Block the master image from registering with Azure AD; Enable autoWorkplaceJoin after the VMs are provisioned via GPO.
Set-ItemProperty -Path HKLM:\Software\Policies\Microsoft\Windows\WorkplaceJoin -Name autoWorkplaceJoin -Value 0 -Force

# Run tasks
Set-RegionalSettings
Set-Roles

# Stop Logging
Stop-Transcript

# Replace clear text passwords in the log file
(Get-Content $Log).replace($Pass, "") | Set-Content $Log
#endregion
