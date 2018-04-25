<# 
    .SYSOPSIS
        Customise a Windows Server image for use as an RDS/XenApp VM in Azure
#>
[CmdletBinding()]
Param (
    [Parameter()]
    [String] $Log = "$env:SystemDrive\Apps\azureDeploy.log",

    [Parameter()]
    [String] $Target = "$env:SystemDrive\Apps",

    [Parameter()]
    [String] $User,

    [Parameter()]
    [String] $Pass
)

# Start logging; Set $VerbosePreference so full details are sent to the log
$VerbosePreference = "Continue"
Start-Transcript -Path $Log

# User / Pass
New-Item -Path $Target -ItemType Directory
$User | Out-File -FilePath "$Target\Pass.txt"
$Pass | ConvertTo-SecureString -AsPlainText -Force | Out-File -FilePath "$Target\Pass.txt" -Append

# Disable autoWorkplaceJoin
# Block the master image from registering with Azure AD.
# Enable autoWorkplaceJoin after the VMs are provisioned via GPO.
Set-ItemProperty -Path HKLM:\Software\Policies\Microsoft\Windows\WorkplaceJoin -Name autoWorkplaceJoin -Value 0

# Add / Remove roles (requires reboot)
Uninstall-WindowsFeature -Name BitLocker, EnhancedStorage, PowerShell-ISE
Add-WindowsFeature -Name RDS-RD-Server, Server-Media-Foundation, 'Search-Service', NET-Framework-Core

# Configure services
Set-Service Audiosrv -StartupType Automatic
Set-Service WSearch -StartupType Automatic

# Trust the PSGaller for installing modules
If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
    Write-Verbose "Trusting the repository: PSGallery"
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

# Install the VcRedist module
# https://docs.stealthpuppy.com/vcredist/
Install-Module VcRedist

# Install the VcRedists
$Dest = "$Target\VcRedist"
New-Item -Path $Dest -ItemType Directory
$VcList = Get-VcList | Get-VcRedist -Path $Dest
Install-VcRedist -VcList $VcList -Path $Dest

# Install Office 365 ProPlus
# manage installed options in configurationRDS.xml
$Dest = "$Target\Office"
New-Item -Path $Dest -ItemType Directory
$url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/140_rds-master-image/scripts/Office.zip"
Start-BitsTransfer -Source $url -Destination "$Dest\$(Split-Path $url -Leaf)"
Expand-Archive -Path "$Dest\$(Split-Path $url -Leaf)"  -DestinationPath "$Dest"
Start-Process -FilePath "$Dest\setup.exe" -ArgumentList "/configure $Dest\configurationRDS.xml" -Wait

# Install Adobe Reader DC
# control access to menu settings with GPO: https://www.adobe.com/devnet-docs/acrobatetk/tools/AdminGuide/gpo.html
$Dest = "$Target\Reader"
New-Item -Path $Dest -ItemType Directory
$url = "http://ardownload.adobe.com/pub/adobe/reader/win/AcrobatDC/1801120035/AcroRdrDC1801120035_en_US.exe"
Start-BitsTransfer -Source $url -Destination "$Dest\$(Split-Path $url -Leaf)"
$Arguments = "-sfx_nu /sALL /msi EULA_ACCEPT=YES " + `
    "ENABLE_CHROMEEXT=0 " + `
    "DISABLE_BROWSER_INTEGRATION=1 " + `
    "ENABLE_OPTIMIZATION=YES " + `
    "ADD_THUMBNAILPREVIEW=0 " + `
    "DISABLEDESKTOPSHORTCUT=1 " + `
    "UPDATE_MODE=0 " + `
    "DISABLE_ARM_SERVICE_INSTALL=1"
Start-Process -FilePath "$Dest\$(Split-Path $url -Leaf)" -ArgumentList $Arguments -Wait
$url = "http://ftp.adobe.com/pub/adobe/reader/win/AcrobatDC/1801120038/AcroRdrDCUpd1801120038.msp"
Start-BitsTransfer -Source $url -Destination "$Dest\$(Split-Path $url -Leaf)"
Start-Process -FilePath "$env:SystemRoot\System32\msiexec" -ArgumentList "/quiet /update $Dest\$(Split-Path $url -Leaf)" -Wait


# Customisations
# DisableIEEnhancedSecurity 
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Type DWord -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Type DWord -Value 0

# HideServerManagerOnLogin 
If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Server\ServerManager")) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Server\ServerManager" -Force
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Server\ServerManager" -Name "DoNotOpenAtLogon" -Type DWord -Value 1

# UninstallXPSPrinter, WindowsMediaPlayer
Disable-WindowsOptionalFeature -Online -FeatureName "Printing-XPSServices-Features", "WindowsMediaPlayer" -NoRestart -WarningAction SilentlyContinue

# EnableSmartScreen
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableSmartScreen" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter" -Name "EnabledV9" -ErrorAction SilentlyContinue

# DisableErrorReporting
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Type DWord -Value 1
Disable-ScheduledTask -TaskName "Microsoft\Windows\Windows Error Reporting\QueueReporting"

# DisableAutorun
If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer")) {
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -Type DWord -Value 255

# DisableDefragmentation
Disable-ScheduledTask -TaskName "Microsoft\Windows\Defrag\ScheduledDefrag"

# DisableSuperfetch
Stop-Service "SysMain" -WarningAction SilentlyContinue
Set-Service "SysMain" -StartupType Disabled


# Clean up
$Path = "$env:SystemDrive\Logs"
If (Test-Path $Path) { Remove-Item -Path $Path -Recurse }

# Profile etc.
$Dest = "$Target\Customise"
New-Item -Path $Dest -ItemType Directory
$url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/140_rds-master-image/scripts/Customise.zip"
Start-BitsTransfer -Source $url -Destination "$Dest\$(Split-Path $url -Leaf)"
Expand-Archive -Path "$Dest\$(Split-Path $url -Leaf)"  -DestinationPath "$Dest"
Push-Location $Dest
Get-ChildItem -Path $Dest -Filter *.ps1 | ForEach-Object { & $_.FullName }
Pop-Location


# Windows Updates
Install-Module PSWindowsUpdate
Add-WUServiceManager -ServiceID "7971f918-a847-4430-9279-4a52d1efe18d" -Confirm:$False
Get-WUInstall -MicrosoftUpdate -Confirm:$False -IgnoreReboot -AcceptAll -Install

# Stop Logging
Stop-Transcript
