<# 
    .SYNOPSIS
        Customise a Windows Server image for use as an RDS/XenApp VM in Azure.
        Installs Office 365 ProPlus, Adobe Reader DC, Visual C++ Redistributables. Installs applications from a network path specified in AppShare.
        Sets regional settings, installs Windows Updates, configures the default profile.
        Runs Windows Defender quick scan, Citrix Optimizer, BIS-F
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [string] $Log = "$env:SystemRoot\Logs\AzureArmCustomDeploy.log",

    [Parameter(Mandatory = $False)]
    [string] $Target = "$env:SystemDrive\Apps",
    
    [Parameter(Mandatory = $False)]
    [string] $User,
    
    [Parameter(Mandatory = $False)]
    [string] $Pass,
    
    [Parameter(Mandatory = $False)]
    [string] $AppShare,
    
    [Parameter(Mandatory = $False)]
    [string] $VerbosePreference = "Continue"
)

#region Functions
Function Set-Customise {
    $Dest = "$Target\Customise"

    # Customisation scripts
    $url = "https://github.com/aaronparker/MDT/archive/master.zip"
    Invoke-WebRequest -Uri $url -OutFile "$Dest\$(Split-Path $url -Leaf)"
    Expand-Archive -Path "$Dest\$(Split-Path $url -Leaf)" -DestinationPath "$Dest" -Force
    
    Push-Location "$Dest\MDT-master\Customise"
    . \Invoke-Scripts.ps1
    Pop-Location
}
#endregion

#region Script logic
# Start logging
Start-Transcript -Path $Log -Append

# If local path for script doesn't exist, create it
If (!(Test-Path $Target)) { New-Item -Path $Target -ItemType Directory -Force -ErrorAction SilentlyContinue }

# Block the master image from registering with Azure AD; Enable autoWorkplaceJoin after the VMs are provisioned via GPO.
Set-ItemProperty -Path HKLM:\Software\Policies\Microsoft\Windows\WorkplaceJoin -Name autoWorkplaceJoin -Value 0 -Force

# Run tasks
Set-Customise

# Stop Logging
Stop-Transcript

# Replace clear text passwords in the log file
(Get-Content $Log).replace($Pass, "") | Set-Content $Log
#endregion
