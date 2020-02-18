<# 
    .SYNOPSIS
        Customise a Windows Server image for use as an RDS/XenApp VM in Azure.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Log = "$env:SystemRoot\Logs\AzureArmCustomDeploy.log",

    [Parameter(Mandatory = $False)]
    [System.String] $Target = "$env:SystemDrive\Apps"
)

# Make Invoke-WebRequest faster
$ProgressPreference = "SilentlyContinue"

#region Functions
Function Set-Customise {
    $Dest = "$Target\Customise"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }

    # Customisation scripts
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $url = "https://github.com/aaronparker/build-azure/raw/master/tools/rds/Customise.zip"
    Invoke-WebRequest -Uri $url -OutFile "$Dest\$(Split-Path $url -Leaf)" -UseBasicParsing
    Expand-Archive -Path "$Dest\$(Split-Path $url -Leaf)" -DestinationPath "$Dest" -Force
    
    Push-Location $Dest
    . .\Invoke-Scripts.ps1 -Verbose
    Pop-Location
}
#endregion

#region Script logic
# Start logging
Write-Host "Running: $($MyInvocation.MyCommand)."
Start-Transcript -Path $Log -Append

# If local path for script doesn't exist, create it
If (!(Test-Path $Target)) { New-Item -Path $Target -ItemType Directory -Force -ErrorAction SilentlyContinue }

# Run tasks
Set-Customise

# Stop Logging
Stop-Transcript
Write-Host "Complete: $($MyInvocation.MyCommand)."
#endregion
