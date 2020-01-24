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
If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }

Write-Host "=============== Downloading Citrix Optimizer"
$url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/rds-packer/tools/CitrixOptimizer.zip"
Invoke-WebRequest -Uri $url -OutFile "$Dest\$(Split-Path $url -Leaf)" -UseBasicParsing
Expand-Archive -Path "$Dest\$(Split-Path $url -Leaf)" -DestinationPath $Dest -Force

# Download templates
If (!(Test-Path $Dest)) { New-Item -Path "$Dest\Templates" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }
Switch -Regex ((Get-WmiObject Win32_OperatingSystem).Caption) {
    "Microsoft Windows Server*" {
        $url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/rds-packer/tools/WindowsServer2019-Defender-Azure.xml"
    }
    "Microsoft Windows 10 Enterprise for Virtual Desktops" {
        $url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/rds-packer/tools/Windows101903-Defender-Azure.xml"
    }
    "Microsoft Windows 10*" {
        $url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/rds-packer/tools/Windows101903-Defender-Azure.xml"
    }
}


Invoke-WebRequest -Uri $url -OutFile "$Dest\Templates\$(Split-Path $url -Leaf)" -UseBasicParsing

& "$Dest\CtxOptimizerEngine.ps1" -Source "$Dest\Templates\$(Split-Path $url -Leaf)" -Mode execute -OutputHtml "$Dest\CitrixOptimizer.html"
#endregion

<#
#region BIS-F
Write-Host "========== Base Image Script Framework"
$Dest = "$Target\BISF"
If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }

Write-Host "=============== Downloading BIS-F"
Set-Repository
Install-Module -Name Evergreen -AllowClobber
$url = (Get-BISF).URI
Invoke-WebRequest -Uri $url -OutFile "$Dest\$(Split-Path $url -Leaf)" -UseBasicParsing
$url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/rds-packer/tools/BisfConfig.zip"
Invoke-WebRequest -Uri $url -OutFile "$Dest\$(Split-Path $url -Leaf)" -UseBasicParsing
Expand-Archive -Path "$Dest\$(Split-Path $url -Leaf)" -DestinationPath "$Dest" -Force

Write-Host "=============== Installing BIS-F"
Start-Process -FilePath "$Dest\$(Split-Path $url -Leaf)" -ArgumentList "/SILENT" -Wait
Remove-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Base Image Script Framework (BIS-F).lnk" -Force
Copy-Item -Path "$Dest\BISFSharedConfig.json" -Destination "${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)\BISFSharedConfig.json"

Write-Host "=============== Running BIS-F"
& "${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)\Framework\PrepBISF_Start.ps1"
#endregion
#>

# Stop Logging
Stop-Transcript
