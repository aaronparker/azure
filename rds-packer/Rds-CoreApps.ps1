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
Function Set-Repository {
    # Trust the PSGallery for installing modules
    If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
        Write-Verbose "Trusting the repository: PSGallery"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
}

Function Install-CoreApps {
    #region VcRedist
    $Dest = "$Target\VcRedist"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue }
    $VcList = Get-VcList | Get-VcRedist -Path $Dest
    Install-VcRedist -VcList $VcList -Path $Dest
    #endregion

    #region FSLogix Apps
    $Dest = "$Target\FSLogix"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue }

    $FSLogix = Get-MicrosoftFSLogixApps
    Start-BitsTransfer -Source $FSLogix.URI -Destination "$Dest\$(Split-Path -Path $FSLogix.URI -Leaf)"
    Expand-Archive -Path "$Dest\$(Split-Path -Path $FSLogix.URI -Leaf)" -DestinationPath $Dest -Force
    
    Start-Process -FilePath "$Dest\x64\Release\$(Split-Path -Path $FSLogix.URI -Leaf)" -ArgumentList "/install /quiet /norestart" -Wait
    #region


    #region Edge
    $Dest = "$Target\Edge"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue }

    $url = "http://dl.delivery.mp.microsoft.com/filestreamingservice/files/89e511fc-33dd-4869-b781-81b4264b3e1e/MicrosoftEdgeBetaEnterpriseX64.msi"
    Start-BitsTransfer -Source $url -Destination "$Dest\$(Split-Path -Path $url -Leaf)"
    Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/package $Dest\$(Split-Path -Path $url -Leaf) /quiet /norestart" -Wait
    #endregion


    #region Office
    # Install Office 365 ProPlus; manage installed options in configurationRDS.xml
    $Dest = "$Target\Office"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue }

    # Get the Office configuration.xml
    $url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/scripts/rds/Office/configurationRDS.xml"
    Start-BitsTransfer -Source $url -Destination "$Dest\$(Split-Path -Path $url -Leaf)"

    $Office = Get-MicrosoftOffice
    Start-BitsTransfer -Source $Office[0].URI -Destination "$Dest\$(Split-Path -Path $Office[0].URI -Leaf)"
    Start-Process -FilePath "$Dest\$(Split-Path -Path $Office[0].URI -Leaf)" -ArgumentList "/configure $Dest\$(Split-Path -Path $url -Leaf)" -Wait
    #endregion


    #region Reader
    # Install Adobe Reader DC
    # Enforce settings with GPO: https://www.adobe.com/devnet-docs/acrobatetk/tools/AdminGuide/gpo.html
    $Dest = "$Target\Reader"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue }

    # Download Reader installer and updater
    $Reader = Get-AdobeAcrobatReaderDC | Where-Object { $_.Platform -eq "Windows" -and ($_.Language -eq "English" -or $_.Language -eq "Neutral") }
    ForEach ($File in $Reader) {
        Invoke-WebRequest -Uri $File.Uri -OutFile (Join-Path -Path $Dest -ChildPath (Split-Path -Path $File.Uri -Leaf))
    }

    # Get resource strings
    $res = Export-EvergreenFunctionStrings -AppName "AdobeAcrobatReaderDC"

    # Install Adobe Reader
    $exe = Get-ChildItem -Path $Dest -Filter "*.exe"
    Start-Process -FilePath $exe.FullName -ArgumentList $res.Install.Virtual.Arguments -Wait

    # Run post install actions
    ForEach ($command in $res.Install.Virtual.PostInstall) {
        Invoke-Command -ScriptBlock ($executioncontext.invokecommand.NewScriptBlock($command))
    }

    # Update Adobe Reader
    $msp = Get-ChildItem -Path $Dest -Filter "*.msp"
    Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/update $($msp.FullName) /quiet" -Wait
    #endregion
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
Install-CoreApps

# Stop Logging
Stop-Transcript

# Replace clear text passwords in the log file
(Get-Content $Log).replace($Pass, "") | Set-Content $Log
#endregion
