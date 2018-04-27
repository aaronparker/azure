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
    [String] $Pass,

    [Parameter()]
    [String] $AppShare
)

# Start logging; Set $VerbosePreference so full details are sent to the log
$VerbosePreference = "Continue"
Start-Transcript -Path $Log


#region Configure system
# Block the master image from registering with Azure AD; Enable autoWorkplaceJoin after the VMs are provisioned via GPO.
Set-ItemProperty -Path HKLM:\Software\Policies\Microsoft\Windows\WorkplaceJoin -Name autoWorkplaceJoin -Value 0

# Regional settings - set to en-AU / Australia
Import-Module International
Set-WinHomeLocation -GeoId 12
Set-WinSystemLocale -SystemLocale en-AU
Set-TimeZone -Id "AUS Eastern Standard Time" -Verbose
& $env:SystemRoot\System32\control.exe "intl.cpl,,/f:`"$PSScriptRoot\language.xml`""

# Add / Remove roles (requires reboot at end of deployment)
Uninstall-WindowsFeature -Name BitLocker, EnhancedStorage, PowerShell-ISE
Add-WindowsFeature -Name RDS-RD-Server, Server-Media-Foundation, 'Search-Service', NET-Framework-Core

# Uninstall features
Disable-WindowsOptionalFeature -Online -FeatureName "Printing-XPSServices-Features", "WindowsMediaPlayer" -NoRestart -WarningAction SilentlyContinue

# Configure services
Set-Service Audiosrv -StartupType Automatic
Set-Service WSearch -StartupType Automatic
#endregion


#region Applications - source Internet
# Trust the PSGaller for installing modules
If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
    Write-Verbose "Trusting the repository: PSGallery"
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

# Install the VcRedist module and VcRedists
# https://docs.stealthpuppy.com/vcredist/
Install-Module VcRedist
$Dest = "$Target\VcRedist"
If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory }
$VcList = Get-VcList | Get-VcRedist -Path $Dest
Install-VcRedist -VcList $VcList -Path $Dest

# Install Office 365 ProPlus; manage installed options in configurationRDS.xml
$Dest = "$Target\Office"
If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory }
# $url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/scripts/rds/Office.zip"
# Start-BitsTransfer -Source $url -Destination "$Dest\$(Split-Path $url -Leaf)"
# Expand-Archive -Path "$Dest\$(Split-Path $url -Leaf)" -DestinationPath "$Dest"
Expand-Archive -Path "$PSScriptRoot\Office.zip" -DestinationPath "$Dest"
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
#endregion


#region Applications - Source local
# Create credential to authenticate
If ($AppShare) {
    
    # Create PS drive to apps share (Apps:)
    $password = ($Pass | ConvertTo-SecureString -AsPlainText -Force)
    $cred = New-Object System.Management.Automation.PSCredential ($User, $password)
    $drive = New-PSDrive -Name Apps -PSProvider FileSystem -Root $AppShare -Credential $cred

    If ($drive) {
        $current = $PWD
        Push-Location Apps:

        # Copy each folder locally and install
        ForEach ($folder in (Get-ChildItem -Path ".\" -Directory)) {
            Copy-Item -Path $folder.FullName -Destination "$target\$($folder.Name)" -Recurse -Force
            Push-Location "$target\$($folder.Name)"
            If (Test-Path "$target\$($folder.Name)\install.cmd") {
                Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList "/c $target\$($folder.Name)\install.cmd" -Wait
            }
        }
        Push-Location $current
    }
}
#endregion


#region Customisations
# DisableIEEnhancedSecurity 
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Type DWORD -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Type DWORD -Value 0

# HideServerManagerOnLogin 
If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Server\ServerManager")) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Server\ServerManager" -Force
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Server\ServerManager" -Name "DoNotOpenAtLogon" -Type DWORD -Value 1

# EnableSmartScreen
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableSmartScreen" -Type DWORD -Value 2
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter" -Name "EnabledV9" -Type DWORD -Value 1

# DisableErrorReporting
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Type DWORD -Value 1
Disable-ScheduledTask -TaskName "Microsoft\Windows\Windows Error Reporting\QueueReporting"

# DisableAutorun
If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer")) {
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -Type DWORD -Value 255

# DisableDefragmentation
Disable-ScheduledTask -TaskName "Microsoft\Windows\Defrag\ScheduledDefrag"

# DisableSuperfetch
Stop-Service "SysMain" -WarningAction SilentlyContinue
Set-Service "SysMain" -StartupType Disabled

# Profile etc.
$Dest = "$Target\Customise"
If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory }
# $url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/scripts/rds/Customise.zip"
# Start-BitsTransfer -Source $url -Destination "$Dest\$(Split-Path $url -Leaf)"
# Expand-Archive -Path "$Dest\$(Split-Path $url -Leaf)"  -DestinationPath "$Dest"
Expand-Archive -Path "$PSScriptRoot\Customise.zip" -DestinationPath "$Dest"
Push-Location $Dest
Get-ChildItem -Path $Dest -Filter *.ps1 | ForEach-Object { & $_.FullName }
Pop-Location
#endregion


# Clean up
$Path = "$env:SystemDrive\Logs"
If (Test-Path $Path) { Remove-Item -Path $Path -Recurse }

# Windows Updates
Install-Module PSWindowsUpdate
Add-WUServiceManager -ServiceID "7971f918-a847-4430-9279-4a52d1efe18d" -Confirm:$False
Get-WUInstall -MicrosoftUpdate -Confirm:$False -IgnoreReboot -AcceptAll -Install


# Stop Logging
Stop-Transcript

# Replace clear text passwords in the log file
(Get-Content $Log).replace($Pass, "pass") | Set-Content $Log
