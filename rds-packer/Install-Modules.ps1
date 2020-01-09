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
Function Install-Modules {
    # Trust the PSGallery for installing modules
    If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
        Write-Verbose "Trusting the repository: PSGallery"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }

    # Install the VcRedist module
    # https://docs.stealthpuppy.com/vcredist/
    Install-Module -Name VcRedist -AllowClobber

    # Install the Evergreen module
    Install-Module -Name Evergreen -AllowClobber

    # Install International module
    Import-Module -Name International -AllowClobber

    # Windows Update
    Install-Module PSWindowsUpdate -AllowClobber
}
#endregion

#region Script logic
# Start logging
Start-Transcript -Path $Log -Append

# If local path for script doesn't exist, create it
If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue }

# Block the master image from registering with Azure AD; Enable autoWorkplaceJoin after the VMs are provisioned via GPO.
Set-ItemProperty -Path HKLM:\Software\Policies\Microsoft\Windows\WorkplaceJoin -Name autoWorkplaceJoin -Value 0 -Force

# Run tasks
Install-Modules

# Stop Logging
Stop-Transcript

# Replace clear text passwords in the log file
(Get-Content $Log).replace($Pass, "") | Set-Content $Log
#endregion
