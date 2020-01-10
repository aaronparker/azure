<# 
    .SYNOPSIS
        Customise a Windows Server image for use as an RDS/XenApp VM in Azure.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [string] $Log = "$env:SystemRoot\Logs\AzureArmCustomDeploy.log",

    [Parameter(Mandatory = $False)]
    [string] $Target = "$env:SystemDrive\Apps",
        
    [Parameter(Mandatory = $False)]
    [string] $VerbosePreference = "Continue"
)

#region Functions
Function Set-Customise {
    $Dest = "$Target\Customise"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue }

    # Customisation scripts
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $url = "https://github.com/aaronparker/MDT/archive/master.zip"
    Invoke-WebRequest -Uri $url -OutFile "$Dest\$(Split-Path $url -Leaf)" -UseBasicParsing
    Expand-Archive -Path "$Dest\$(Split-Path $url -Leaf)" -DestinationPath "$Dest" -Force
    
    Push-Location "$Dest\MDT-master\Customise"
    . .\Invoke-Scripts.ps1
    Pop-Location
}
#endregion

#region Script logic
# Start logging
Write-Host "Running: $($MyInvocation.MyCommand)."
Start-Transcript -Path $Log -Append

# If local path for script doesn't exist, create it
If (!(Test-Path $Target)) { New-Item -Path $Target -ItemType Directory -Force -ErrorAction SilentlyContinue }

# Block the master image from registering with Azure AD; Enable autoWorkplaceJoin after the VMs are provisioned via GPO.
Set-ItemProperty -Path HKLM:\Software\Policies\Microsoft\Windows\WorkplaceJoin -Name autoWorkplaceJoin -Value 0 -Force

# Run tasks
Set-Customise

# Stop Logging
Stop-Transcript
Write-Host "Complete: $($MyInvocation.MyCommand)."
#endregion
