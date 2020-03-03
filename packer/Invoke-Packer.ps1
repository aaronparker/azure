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

# Get elevation status
[System.Boolean] $Elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")

If ($Elevated) {
    # Make Invoke-WebRequest faster
    $ProgressPreference = "SilentlyContinue"

    # Trust the PSGallery for installing modules
    If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
        Write-Verbose "Trusting the repository: PSGallery"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }

    # Install the Az module
    Find-Module -Name Az -Repository PSGallery | Install-Module -AllowClobber
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
$fileName = [System.IO.Path]::GetFileNameWithoutExtension($templateFile)
$path = [System.IO.Path]::GetDirectoryName($templateFile)
$newTemplate = "$path\$filename-Temp.json"
If (Test-Path -Path $newTemplate) { Remove-Item -Path $newTemplate -Force -ErrorAction SilentlyContinue }
(Get-Content $Template).replace("<clientid>", $AppId) | Set-Content -Path $newTemplate
(Get-Content $newTemplate).replace("<clientsecrect>", $Secret) | Set-Content -Path $newTemplate
(Get-Content $newTemplate).replace("<subscriptionid>", $sub.Id) | Set-Content -Path $newTemplate
(Get-Content $newTemplate).replace("<tenantid>", $sub.TenantId) | Set-Content -Path $newTemplate
(Get-Content $newTemplate).replace("<resourcegroup>", $ResourceGroup) | Set-Content -Path $newTemplate
(Get-Content $newTemplate).replace("<imagename>", "$ImageName-$(Get-Date -Format "ddMMyyyy")") | Set-Content -Path $newTemplate

# Output strings
Write-Host "AppId:          $AppId" -ForegroundColor Green
Write-Host "Secret:         $Secret" -ForegroundColor Green
Write-Host "Subscription:   $($sub.Id)" -ForegroundColor Green
Write-Host "Subscription:   $($sub.TenantId)" -ForegroundColor Green
Write-Host "Resource group: $ResourceGroup" -ForegroundColor Green
Write-Host "Image name:     $ImageName-$(Get-Date -Format "ddMMyyyy")" -ForegroundColor Green
Write-Host "Template:       $newTemplate" -ForegroundColor Green

# Validate template
Write-Host "Validating: $newTemplate" -ForegroundColor Cyan
Start-Process -FilePath ".\Packer.exe" -ArgumentList "validate $newTemplate" -Wait -NoNewWindow

# Run Packer
Write-Host "Run: .\packer.exe build -force -on-error=ask -timestamp-ui $newTemplate" -ForegroundColor Cyan
