[CmdletBinding()]
param(
    [Parameter(Mandatory = $False)]
    [System.String] $AppId = "",

    [Parameter(Mandatory = $False)]
    [System.String] $Secret = "",

    [Parameter(Mandatory = $False)]
    [System.String] $ResourceGroup = "rg-WVD-AUE",

    [Parameter(Mandatory = $False)]
    [System.String] $Template = ".\WindowsServer2019RDS.json"
)

# Trust the PSGallery for installing modules
If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
    Write-Verbose "Trusting the repository: PSGallery"
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

# Install the Az module
Install-Module -Name Az -AllowClobber

# Get the subscription
$sub = Get-AzSubscription

# Replace strings
(Get-Content $Template).replace("<clientid>", $AppId) | Set-Content $Template
(Get-Content $Template).replace("<clientsecrect>", $Secret) | Set-Content $Template
(Get-Content $Template).replace("<subscriptionid>", $sub.Id) | Set-Content $Template
(Get-Content $Template).replace("<tenantid>", $sub.TenantId) | Set-Content $Template
(Get-Content $Template).replace("<resourcegroup>", $ResourceGroup) | Set-Content $Template

# Run Packer
Start-Process -FilePath ".\Packer.exe" -ArgumentList "build $Template" -Wait
