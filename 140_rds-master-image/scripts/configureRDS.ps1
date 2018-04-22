[CmdletBinding()]
Param (
    [Parameter()]
    [String] $Log = "$env:SystemRoot\Temp\azureDeploy.log"
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

# Trust the PSGaller for installing modules
If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
    Write-Verbose "Trusting the repository: PSGallery"
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

# Install the VcRedist module
Install-Module VcRedist

# Install the VcRedists
$VcPath = "$env:SystemDrive\Apps\VcRedist"
New-Item -Path $VcPath -ItemType Directory
$VcList = Get-VcList | Get-VcRedist -Path $VcPath
Install-VcRedist -VcList $VcList -Path $VcPath

# Stop Logging
Stop-Transcript
