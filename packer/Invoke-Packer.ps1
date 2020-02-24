[CmdletBinding()]
param(
    [Parameter(Mandatory = $False)]
    [System.String] $ResourceGroup = "rg-WVD-AUE",

    [Parameter(Mandatory = $False)]
    [System.String] $Template = ".\WindowsServer2019RDS.json",

    [Parameter(Mandatory = $False)]
    [System.String] $ImageName = "WindowsServer2019RemoteDesktopHost",

    [Parameter(Mandatory = $False)]
    [System.String] $KeyVault = "insentrawvd"
)

$Tags = @{
    Function           = "Master image"
    "Operating System" = "Windows 10 Enterprise 1903"
    Environment        = "Windows Virtual Desktop"
}

# Get the Packer template and convert to an object
try {
    $json = Get-Content -Path $Template | ConvertFrom-Json
}
catch {
    Throw "Failed to read and convert $Template"
    Break
}

# Get elevation status
[System.Boolean] $Elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")

If ($Elevated) {
    # Trust the PSGallery for installing modules
    If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
        Write-Verbose "Trusting the repository: PSGallery"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }

    # Install the Az module
    Install-Module -Name Az -AllowClobber
}
Else {
    Write-Host "Not running elevated. Check modules are installed." -ForegroundColor Cyan
}

# Test if logged in and get the subscription
If ($Null -eq (Get-AzSubscription)) {
    Write-Host "Connecting to Azure subscription." -ForegroundColor Cyan
    try {
        Connect-AzAccount
        $sub = Get-AzSubscription
    }
    catch {
        Throw "Failed to connect to Azure subscription."
        Break
    }
}
Else {
    $sub = Get-AzSubscription
}

# Get values from the Key Vault
try {
    Write-Host "Getting Packer service principal credentails." -ForegroundColor Cyan
    $Secret = (Get-AzKeyVaultSecret -VaultName $KeyVault -Name PackerSecret).SecretValueText
    $AppId = (Get-AzKeyVaultSecret -VaultName $KeyVault -Name PackerAppId).SecretValueText
}
catch {
    Write-Warning "Failed to gather Packer secrets from the Key Vault."
    Write-Warning "Expected 'PackerSecret' and 'PackerAppId' in Key Vault $KeyVault."
}

# Get UTC date/time
$date = Get-Date -Format "ddMMyyyy"

# Install the Windows Update Packer plugin, https://github.com/rgl/packer-provisioner-windows-update
$url = "https://github.com/rgl/packer-provisioner-windows-update/releases/download/v0.9.0/packer-provisioner-windows-update-windows.zip"
$zip = "$env:Temp\packer-provisioner-windows-update-windows.zip"
$target = "$env:AppData\packer.d\plugins"
$exe = "packer-provisioner-windows-update.exe"
If (Test-Path -Path (Join-Path -Path $target -ChildPath $exe)) {
    Write-Host "Windows Update Packer plugin exists." -ForegroundColor Cyan
}
Else {
    Write-Host "Downloading Windows Update Packer plugin." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $target
    Remove-Item -Path $zip
}

# Replace values
$json.builders.client_id = $AppId
$json.builders.client_secret = $Secret
$json.builders.subscription_id = $sub.id
$json.builders.tenant_id = $sub.TenantId
$json.builders.managed_image_name = "$ImageName-$date"
$json.builders.managed_image_resource_group_name = $ResourceGroup
$json.builders.os_type = "Windows"
$json.builders.image_publisher = "MicrosoftWindowsDesktop"
$json.builders.image_offer = "Windows-10"
$json.builders.image_sku = "19h2-ent"
$json.builders.image_version = "latest"
$json.builders.winrm_timeout = "3m"
$json.builders.azure_tags = $Tags
$json.builders.location = "australiaeast"
$json.builders.vm_size = "Standard_D2s_v3"

# Output new values
$json | ConvertTo-Json | Set-Content -Path $Template -Force

# Output strings
Write-Host "AppId:          $AppId" -ForegroundColor Green
Write-Host "Secret:         $Secret" -ForegroundColor Green
Write-Host "Subscription:   $($sub.Id)" -ForegroundColor Green
Write-Host "Subscription:   $($sub.TenantId)" -ForegroundColor Green
Write-Host "Resource group: $ResourceGroup" -ForegroundColor Green
Write-Host "Image name:     $ImageName-$date" -ForegroundColor Green
Write-Host "Template:       $Template" -ForegroundColor Green

# Validate template
Start-Process -FilePath ".\Packer.exe" -ArgumentList "validate $Template" -Wait -NoNewWindow

# Run Packer
# .\packer.exe build -force -on-error=ask -timestamp-ui $Template
