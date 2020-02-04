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
[System.Boolean] $Elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator") 

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
    Connect-AzAccount
    $sub = Get-AzSubscription
}
Else {
    $sub = Get-AzSubscription
}

# Get values from the Key Vault
$Secret = (Get-AzKeyVaultSecret -VaultName $KeyVault -Name PackerSecret).SecretValueText
$AppId = (Get-AzKeyVaultSecret -VaultName $KeyVault -Name PackerAppId).SecretValueText

# Get UTC date/time
$date = Get-Date
$dateFormat = "$($date.Day)$($date.Month)$($date.Year)"

# Install the Windows Update Packer plugin, https://github.com/rgl/packer-provisioner-windows-update
$url = "https://github.com/rgl/packer-provisioner-windows-update/releases/download/v0.9.0/packer-provisioner-windows-update-windows.zip"
$zip = "$env:Temp\packer-provisioner-windows-update-windows.zip"
$target = "$env:AppData\packer.d\plugins"
$exe = "packer-provisioner-windows-update.exe"
If (Test-Path -Path (Join-Path -Path $target -ChildPath $exe)) {
    Write-Host "Windows Update Packer plugin exists" -ForegroundColor Cyan
}
Else {
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $target
    Remove-Item -Path $zip
}

# Replace strings
(Get-Content $Template).replace("<clientid>", $AppId) | Set-Content $Template
(Get-Content $Template).replace("<clientsecrect>", $Secret) | Set-Content $Template
(Get-Content $Template).replace("<subscriptionid>", $sub.Id) | Set-Content $Template
(Get-Content $Template).replace("<tenantid>", $sub.TenantId) | Set-Content $Template
(Get-Content $Template).replace("<resourcegroup>", $ResourceGroup) | Set-Content $Template
(Get-Content $Template).replace("<imagename>", "$ImageName-$dateFormat") | Set-Content $Template

# Output strings
Write-Host "AppId: $AppId"
Write-Host "Secret: $Secret"
Write-Host "Subscription: $($sub.Id)"
Write-Host "Subscription: $($sub.TenantId)"
Write-Host "Resource group: $ResourceGroup"
Write-Host "Image name: $ImageName-$dateFormat"
Write-Host "Template: $Template"

# Validate template
Start-Process -FilePath ".\Packer.exe" -ArgumentList "validate $Template" -Wait -NoNewWindow

# Run Packer
# .\packer.exe build -force -on-error=ask -timestamp-ui $Template
