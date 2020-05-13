<# 
    .SYNOPSIS
        Customise a Windows image for use as an WVD/XenApp VM in Azure.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Log = "$env:SystemRoot\Logs\AzureArmCustomDeploy.log",

    [Parameter(Mandatory = $False)]
    [System.String] $Target = "$env:SystemDrive\Apps"
)

#region Functions
Function Set-Customise ($Path) {
    If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null }

    # Customisation scripts
    $url = "https://github.com/aaronparker/build-azure/raw/master/tools/rds/Customise.zip"
    Invoke-WebRequest -Uri $url -OutFile "$Path\$(Split-Path $url -Leaf)" -UseBasicParsing
    Expand-Archive -Path "$Path\$(Split-Path $url -Leaf)" -DestinationPath "$Path" -Force
    
    Push-Location $Path
    . .\Invoke-Scripts.ps1 -Verbose
    Pop-Location
}
#endregion

#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Start logging
Start-Transcript -Path $Log -Append -ErrorAction SilentlyContinue
If (!(Test-Path $Target)) { New-Item -Path $Target -Type Directory -Force -ErrorAction SilentlyContinue }

# Set TLS to 1.2; Create target folder
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
If (!(Test-Path $Target)) { New-Item -Path $Target -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" }

# Run tasks
Set-Customise -Path "$Target\Customise"

# Stop Logging
Stop-Transcript -ErrorAction SilentlyContinue
Write-Host "Complete: $($MyInvocation.MyCommand)."
#endregion
