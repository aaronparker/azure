[CmdletBinding()]
param(
    [Parameter(Mandatory = $False)]
    [System.String] $ResourceGroup = "rg-Images-AustraliaEast",

    [Parameter(Mandatory = $False)]
    [System.String] $TemplateFile = ".\PackerTemplate-Windows.json",

    [Parameter(Mandatory = $False)]
    [System.String] $VariablesFile = ".\PackerVariables-Windows10Multisession.json",

    [Parameter(Mandatory = $False)]
    [System.String] $KeyVault = "stpywvdaustraliaeast",

    [Parameter(Mandatory = $False)]
    [System.String] $AppsUrl = "https://stpywvdaue.blob.core.windows.net/apps/",

    [Parameter(Mandatory = $False)]
    [System.String] $PackagesUrl = "https://stpywvdaue.blob.core.windows.net/apps/"
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
    # Find-Module -Name Az -Repository PSGallery | Install-Module -AllowClobber
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
    #TODO - update for multiple subscriptions
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

# Get date, locale
$Locale = (Get-WinSystemLocale).Name
$Date = Get-Date -Format $([System.Globalization.CultureInfo]::CurrentUICulture.DateTimeFormat.ShortDatePattern -replace "/", "")

# Create a copy of the variables file
$fileName = [System.IO.Path]::GetFileNameWithoutExtension($(Resolve-Path -Path $VariablesFile))
$path = [System.IO.Path]::GetDirectoryName($VariablesFile)
$newVariablesFile = Join-Path -Path $path -ChildPath "$filename-$Date.json"

# Replace values
$json = Get-Content -Path $VariablesFile | ConvertFrom-Json
$json.client_id = $AppId
$json.client_secret = $Secret
$json.subscription_id = $sub.Id
$json.tenant_id = $sub.TenantId
$json.managed_image_resource_group_name = $ResourceGroup
$json.Locale = $Locale
If ($AppsUrl.Length -gt 0) { $json.AppsUrl = $AppsUrl }
If ($PackagesUrl.Length -gt 0) { $json.PackagesUrl = $PackagesUrl }

# Output the new variables file
$json | ConvertTo-Json | Set-Content -Path $newVariablesFile -Force

# Output strings
Write-Host "AppId:          $AppId" -ForegroundColor Green
Write-Host "Secret:         $Secret" -ForegroundColor Green
Write-Host "Subscription:   $($sub.Id)" -ForegroundColor Green
Write-Host "Subscription:   $($sub.TenantId)" -ForegroundColor Green
Write-Host "Resource group: $ResourceGroup" -ForegroundColor Green
Write-Host "Image date:     $Date" -ForegroundColor Green
Write-Host "Locale:         $Locale" -ForegroundColor Green
If ($AppsUrl.Length -gt 0) { Write-Host "Apps blob storage:   $AppsUrl" -ForegroundColor Green }
If ($PackagesUrl.Length -gt 0) { Write-Host "Packages blob storage:   $PackagesUrl" -ForegroundColor Green }
Write-Host "Template file:  $TemplateFile" -ForegroundColor Green
Write-Host "Variables file: $newVariablesFile" -ForegroundColor Green

# Validate template
$Template = Resolve-Path -Path $TemplateFile
$Arguments = "-var-file $newVariablesFile -var 'image_date=$($Date)' $Template"
$Validate = "& packer.exe validate $Arguments"
Write-Host "Validate template: 'packer.exe validate $Arguments'." -ForegroundColor Cyan
Invoke-Expression -Command $Validate

# Run Packer
Write-Host "Packer command line sent to the clipboard. Paste here to run." -ForegroundColor Cyan
"packer.exe build -force -on-error=ask -timestamp-ui $Arguments" | Set-Clipboard
