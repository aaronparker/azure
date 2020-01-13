<# 
    .SYSOPSIS
        Seal an RDSH image.
#>
[CmdletBinding()]
Param (
    [Parameter()] $Log = "$env:SystemRoot\Logs\AzureArmCustomSeal.log",
    [Parameter()] $Target = "$env:SystemDrive\Apps"
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
#endregion

# Start logging; Set $VerbosePreference so full details are sent to the log
$VerbosePreference = "Continue"
Start-Transcript -Path $Log
If (!(Test-Path $Target)) { New-Item -Path $Target -Type Directory -Force -ErrorAction SilentlyContinue }

# Set TLS to 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Run Windows Defender quick scan; Running via BISF doesn't exit
# Start-Process -FilePath "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -ArgumentList "-SignatureUpdate -MMPC" -Wait
# Start-Process -FilePath "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -ArgumentList "-Scan -ScanType 1" -Wait
# Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\RemovalTools\MRT" -Name "GUID" -Value ""

#region Citrix Optimizer
Write-Host "========== Citrix Optimizer"
$Dest = "$Target\CitrixOptimizer"
If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue }

Write-Host "=============== Downloading Citrix Optimizer"
$url = "https://github.com/aaronparker/build-azure-lab/raw/master/rds-packer/tools/CitrixOptimizer.zip"
Invoke-WebRequest -Uri $url -OutFile "$Dest\$(Split-Path $url -Leaf)" -UseBasicParsing
    
Expand-Archive -Path "$Dest\$(Split-Path $url -Leaf)" -DestinationPath "$Dest" -Force
& "$Dest\CtxOptimizerEngine.ps1" `
    -Source "$Dest\Templates\Citrix_Windows_Server_2019_1809.xml" `
    -Mode execute -OutputHtml "$Dest\CitrixOptimizer.html"
#endregion

#region BIS-F
Write-Host "========== Base Image Script Framework"
$Dest = "$Target\BISF"
If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue }

Write-Host "=============== Downloading BIS-F"
Set-Repository
Install-Module -Name Evergreen -AllowClobber
$url = (Get-BISF).URI
Invoke-WebRequest -Uri $url -OutFile "$Dest\$(Split-Path $url -Leaf)" -UseBasicParsing
    
Write-Host "=============== Installing BIS-F"
Start-Process -FilePath "$Dest\$(Split-Path $url -Leaf)"  -ArgumentList "/SILENT" -Wait
Remove-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Base Image Script Framework (BIS-F).lnk" -Force
# Copy-Item -Path "$Dest\*.xml" -Destination "${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)"

Write-Host "=============== Running BIS-F"
& "${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)\Framework\PrepBISF_Start.ps1"
#endregion

# Clean up
Get-ScheduledTask "Seal Image" | Unregister-ScheduledTask -Confirm:$False

# Stop Logging
Stop-Transcript
