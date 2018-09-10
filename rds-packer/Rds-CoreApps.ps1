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

Function Install-CoreApps {
    # Install the VcRedist module and VcRedists
    # https://docs.stealthpuppy.com/vcredist/
    Set-Repository
    Install-Module VcRedist
    $Dest = "$Target\VcRedist"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory }
    $VcList = Get-VcList | Get-VcRedist -Path $Dest
    Install-VcRedist -VcList $VcList -Path $Dest

    # Install Office 365 ProPlus; manage installed options in configurationRDS.xml
    $Dest = "$Target\Office"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory }
    $url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/scripts/rds/Office.zip"
    Start-BitsTransfer -Source $url -Destination "$Dest\$(Split-Path $url -Leaf)"
    Expand-Archive -Path "$Dest\$(Split-Path $url -Leaf)" -DestinationPath "$Dest" -Force
    Start-Process -FilePath "$Dest\setup.exe" -ArgumentList "/configure $Dest\configurationRDS.xml" -Wait

    # Install Adobe Reader DC
    # Enforce settings with GPO: https://www.adobe.com/devnet-docs/acrobatetk/tools/AdminGuide/gpo.html
    $urlInstall = "http://ardownload.adobe.com/pub/adobe/reader/win/AcrobatDC/1801120058/AcroRdrDC1801120058_en_US.exe"
    $urlUpdate = "http://ardownload.adobe.com/pub/adobe/reader/win/AcrobatDC/1801120058/AcroRdrDCUpd1801120058.msp"
    $Dest = "$Target\Reader"
    New-Item -Path $Dest -ItemType Directory
    Start-BitsTransfer -Source $urlInstall -Destination "$Dest\$(Split-Path $urlInstall -Leaf)"
    $Arguments = "-sfx_nu /sALL /msi EULA_ACCEPT=YES " + `
        "ENABLE_CHROMEEXT=0 " + `
        "DISABLE_BROWSER_INTEGRATION=1 " + `
        "ENABLE_OPTIMIZATION=YES " + `
        "ADD_THUMBNAILPREVIEW=0 " + `
        "DISABLEDESKTOPSHORTCUT=1 " + `
        "UPDATE_MODE=0 " + `
        "DISABLE_ARM_SERVICE_INSTALL=1"
    Start-Process -FilePath "$Dest\$(Split-Path $urlInstall -Leaf)" -ArgumentList $Arguments -Wait
    Start-BitsTransfer -Source $urlUpdate -Destination "$Dest\$(Split-Path $urlUpdate -Leaf)"
    Start-Process -FilePath "$env:SystemRoot\System32\msiexec" -ArgumentList "/quiet /update $Dest\$(Split-Path $urlUpdate -Leaf)" -Wait
    Start-Sleep 20
    Get-Service -Name AdobeARMservice -ErrorAction SilentlyContinue | Set-Service -StartupType Disabled
    Get-ScheduledTask "Adobe Acrobat Update Task*" | Unregister-ScheduledTask -Confirm:$False
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
Install-CoreApps

# Stop Logging
Stop-Transcript

# Replace clear text passwords in the log file
(Get-Content $Log).replace($Pass, "") | Set-Content $Log
#endregion
