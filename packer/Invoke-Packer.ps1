[CmdletBinding()]
param(
    [Parameter(Mandatory = $False)]
    [System.String] $AppId = "",

    [Parameter(Mandatory = $False)]
    [System.String] $Secret = "",

    [Parameter(Mandatory = $False)]
    [System.String] $ResourceGroup = "rg-WVD-AUE",

    [Parameter(Mandatory = $False)]
    [System.String] $Template = ".\WindowsServer2019RDS.json",

    [Parameter(Mandatory = $False)]
    [System.String] $ImageName = "WindowsServer2019RemoteDesktopHost",

    [Parameter(Mandatory = $False)]
    [System.String] $KeyVault = "insentrawvd"
)

# Trust the PSGallery for installing modules
If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
    Write-Verbose "Trusting the repository: PSGallery"
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

# Install the Az module
Install-Module -Name Az -AllowClobber

# Test if logged in and get the subscription
If ($Null -eq (Get-AzAccount)) { Connect-AzAccount }
$sub = Get-AzSubscription

# Get values from the Key Vault
If ($Null -eq $Secret) {
    $Secret = (Get-AzKeyVaultSecret -VaultName $KeyVault -Name PackerSecret).SecretValueText
}
If ($Null -eq $AppId) {
    $AppId = (Get-AzKeyVaultSecret -VaultName $KeyVault -Name PackerAppId).SecretValueText
}

# Get UTC date/time
$date = Get-Date
$dateFormat = "$($date.Day)$($date.Month)$($date.Year)"

# Install the Windows Update Packer plugin via Chocolatey; requires 0.9.0 or above
# https://github.com/rgl/packer-provisioner-windows-update
Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco install packer-provisioner-windows-update -yes

# Replace strings
(Get-Content $Template).replace("<clientid>", $AppId) | Set-Content $Template
(Get-Content $Template).replace("<clientsecrect>", $Secret) | Set-Content $Template
(Get-Content $Template).replace("<subscriptionid>", $sub.Id) | Set-Content $Template
(Get-Content $Template).replace("<tenantid>", $sub.TenantId) | Set-Content $Template
(Get-Content $Template).replace("<resourcegroup>", $ResourceGroup) | Set-Content $Template
(Get-Content $Template).replace("<imagename>", "$ImageName-$dateFormat") | Set-Content $Template

# Validate template
Start-Process -FilePath ".\Packer.exe" -ArgumentList "validate $Template" -Wait -NoNewWindow

# Run Packer
.\packer.exe validate $ImageName
# .\packer.exe build -force -on-error=ask -timestamp-ui .\WindowsServer2019RDS.json
