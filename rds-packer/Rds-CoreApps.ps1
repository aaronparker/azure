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
Function Set-Repository {
    # Trust the PSGallery for modules
    If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
        Write-Verbose "Trusting the repository: PSGallery"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
}

Function Install-CoreApps {
    # Set TLS to 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    #region VcRedist
    # Install the VcRedist module
    # https://docs.stealthpuppy.com/vcredist/
    Install-Module -Name VcRedist -AllowClobber

    Write-Host "========== Microsoft Visual C++ Redistributables"
    $Dest = "$Target\VcRedist"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }
    $VcList = Get-VcList
    Save-VcRedist -Path $Dest -VcList $VcList -ForceWebRequest -Verbose
    Install-VcRedist -VcList $VcList -Path $Dest -Verbose
    #endregion

    # Install the Evergreen module
    Install-Module -Name Evergreen -AllowClobber

    #region FSLogix Apps
    Write-Host "========== Microsoft FSLogix agent"
    $Dest = "$Target\FSLogix"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }

    $FSLogix = Get-MicrosoftFSLogixApps
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $FSLogix.URI -OutFile "$Dest\$(Split-Path -Path $FSLogix.URI -Leaf)" -UseBasicParsing
    Expand-Archive -Path "$Dest\$(Split-Path -Path $FSLogix.URI -Leaf)" -DestinationPath $Dest -Force
    Start-Process -FilePath "$Dest\x64\Release\FSLogixAppsSetup.exe" -ArgumentList "/install /quiet /norestart" -Wait
    #region


    #region Edge
    Write-Host "========== Microsoft Edge"
    $Dest = "$Target\Edge"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }

    Write-Host "=============== Downloading Microsoft Edge"
    $url = "http://dl.delivery.mp.microsoft.com/filestreamingservice/files/89e511fc-33dd-4869-b781-81b4264b3e1e/MicrosoftEdgeBetaEnterpriseX64.msi"
    Invoke-WebRequest -Uri $url -OutFile "$Dest\$(Split-Path -Path $url -Leaf)" -UseBasicParsing

    Write-Host "=============== Installing Microsoft Edge"
    Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/package $Dest\$(Split-Path -Path $url -Leaf) /quiet /norestart" -Wait
    Remove-Item -Path "$env:Public\Desktop\Microsoft Edge*.lnk" -Force
    #endregion


    #region Office 365 ProPlus
    Write-Host "========== Microsoft Office"
    # Install Office 365 ProPlus; manage installed options in configurationRDS.xml
    $Dest = "$Target\Office"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }

    # Get the Office configuration.xml
    $url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/rds-packer/Office365ProPlusRDS.xml"
    Invoke-WebRequest -Uri $url -OutFile "$Dest\$(Split-Path -Path $url -Leaf)" -UseBasicParsing

    $Office = Get-MicrosoftOffice
    Invoke-WebRequest -Uri $Office[0].URI -OutFile "$Dest\$(Split-Path -Path $Office[0].URI -Leaf)"
    Push-Location -Path $Dest
    Write-Host "=============== Downloading Microsoft Office"
    Start-Process -FilePath "$Dest\$(Split-Path -Path $Office[0].URI -Leaf)" -ArgumentList "/download $Dest\$(Split-Path -Path $url -Leaf)" -Wait
    Write-Host "=============== Installing Microsoft Office"
    Start-Process -FilePath "$Dest\$(Split-Path -Path $Office[0].URI -Leaf)" -ArgumentList "/configure $Dest\$(Split-Path -Path $url -Leaf)"
    Start-Sleep -Seconds 600
    Pop-Location
    #endregion

    #region Teams
    $Dest = "$Target\Teams"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }

    Write-Host "=============== Downloading Microsoft Teams"
    $url = "https://statics.teams.cdn.office.net/production-windows-x64/1.2.00.32462/Teams_windows_x64.msi"
    Invoke-WebRequest -Uri $url -OutFile "$Dest\$(Split-Path -Path $url -Leaf)" -UseBasicParsing

    Write-Host "=============== Installing Microsoft Teams"
    Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/package $Dest\$(Split-Path -Path $url -Leaf) ALLUSER=1"
    #endregion

    #region OneDrive
    $Dest = "$Target\Teams"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }
    
    Write-Host "=============== Downloading Microsoft Teams"
    $url = "https://oneclient.sfx.ms/Win/Prod/19.192.0926.0012/OneDriveSetup.exe"
    Invoke-WebRequest -Uri $url -OutFile "$Dest\$(Split-Path -Path $url -Leaf)" -UseBasicParsing
    
    Write-Host "=============== Installing Microsoft Teams"
    Start-Process -FilePath "$Dest\$(Split-Path -Path $url -Leaf)" -ArgumentList "/allusers"
    #endregion

        
    #region Reader
    # Install Adobe Reader DC
    # Enforce settings with GPO: https://www.adobe.com/devnet-docs/acrobatetk/tools/AdminGuide/gpo.html
    Write-Host "========== Adobe Acrobat Reader DC"
    $Dest = "$Target\Reader"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }

    # Download Reader installer and updater
    Write-Host "=============== Downloading Reader"
    $Reader = Get-AdobeAcrobatReaderDC | Where-Object { $_.Platform -eq "Windows" -and ($_.Language -eq "English" -or $_.Language -eq "Neutral") }
    ForEach ($File in $Reader) {
        Invoke-WebRequest -Uri $File.Uri -OutFile (Join-Path -Path $Dest -ChildPath (Split-Path -Path $File.Uri -Leaf)) -UseBasicParsing
    }

    # Get resource strings
    $res = Export-EvergreenFunctionStrings -AppName "AdobeAcrobatReaderDC"

    # Install Adobe Reader
    Write-Host "=============== Installing Reader"
    $exe = Get-ChildItem -Path $Dest -Filter "*.exe"
    Start-Process -FilePath $exe.FullName -ArgumentList $res.Install.Virtual.Arguments -Wait

    # Run post install actions
    Write-Host "=============== Post install configuration Reader"
    ForEach ($command in $res.Install.Virtual.PostInstall) {
        Invoke-Command -ScriptBlock ($executioncontext.invokecommand.NewScriptBlock($command))
    }

    # Update Adobe Reader
    Write-Host "=============== Update Reader"
    $msp = Get-ChildItem -Path $Dest -Filter "*.msp"
    Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/update $($msp.FullName) /quiet" -Wait
    #endregion
}
#endregion

#region Script logic
# Start logging
Write-Host "========== Running: $($MyInvocation.MyCommand)."
Start-Transcript -Path $Log -Append

# If local path for script doesn't exist, create it
If (!(Test-Path $Target)) { New-Item -Path $Target -ItemType Directory -Force -ErrorAction SilentlyContinue }

# Run tasks
Set-Repository
Install-CoreApps

# Stop Logging
Stop-Transcript
Write-Host "========== Complete: $($MyInvocation.MyCommand)."
#endregion
