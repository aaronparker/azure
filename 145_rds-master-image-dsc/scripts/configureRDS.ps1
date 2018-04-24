[CmdletBinding()]
Param (
    [Parameter()]
    [String] $Log = "$env:SystemDrive\Apps\azureDeploy.log",

    [Parameter()]
    [String] $Target = "$env:SystemDrive\Apps"
)

If ($VerbosePreference -ne [System.Management.Automation.ActionPreference]::Continue) {
    $VerbosePreference = "Continue"
}

# Start logging
Start-Transcript -Path $Log

<#
    Disable autoWorkplaceJoin
    Block the master image from registering with Azure AD.
    Enable autoWorkplaceJoin after the VMs are provisioned via GPO.
#>
Set-ItemProperty -Path HKLM:\Software\Policies\Microsoft\Windows\WorkplaceJoin -Name autoWorkplaceJoin -Value 0

# Add / Remove roles
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
$Dest = "$Target\Office"
New-Item -Path $Dest -ItemType Directory
$url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/140_rds-master-image/scripts/Office.zip"
Start-BitsTransfer -Source $url -Destination "$Dest\$(Split-Path $url -Leaf)"
Expand-Archive -Path "$Dest\$(Split-Path $url -Leaf)"  -DestinationPath "$Dest"
Start-Process -FilePath "$Dest\setup.exe" -ArgumentList "/configure $Dest\configurationRDS.xml" -Wait

# Stop Logging
Stop-Transcript
