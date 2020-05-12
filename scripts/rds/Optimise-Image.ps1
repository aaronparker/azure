<# 
    .SYSOPSIS
        Optimise and seal a Windows image.
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

Function Install-RequiredModules {
    Write-Host "=========== Installing required modules"
    # Install the Evergreen module; https://github.com/aaronparker/Evergreen
    Install-Module -Name Evergreen -AllowClobber

    # Install the VcRedist module; https://docs.stealthpuppy.com/vcredist/
    Install-Module -Name VcRedist -AllowClobber
}

Function Invoke-WindowsDefender {
    # Run Windows Defender quick scan
    Write-Host "=============== Running Windows Defender"
    Start-Process -FilePath "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -ArgumentList "-SignatureUpdate -MMPC" -Wait
    Start-Process -FilePath "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -ArgumentList "-Scan -ScanType 1" -Wait
    # Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\RemovalTools\MRT" -Name "GUID" -Value ""
}

Function Invoke-CitrixOptimizer ($Path) {
    Write-Host "========== Citrix Optimizer"
    If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }

    Write-Host "=============== Downloading Citrix Optimizer"
    $url = "https://raw.githubusercontent.com/aaronparker/build-azure/master/tools/rds/CitrixOptimizer.zip"
    Invoke-WebRequest -Uri $url -OutFile "$Path\$(Split-Path $url -Leaf)" -UseBasicParsing
    Expand-Archive -Path "$Path\$(Split-Path $url -Leaf)" -DestinationPath $Path -Force

    # Download templates
    Write-Host "=============== Downloading Citrix Optimizer template"
    If (!(Test-Path $Path)) { New-Item -Path "$Path\Templates" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }
    Switch -Regex ((Get-WmiObject Win32_OperatingSystem).Caption) {
        "Microsoft Windows Server*" {
            $url = "https://raw.githubusercontent.com/aaronparker/build-azure/master/tools/rds/WindowsServer2019-Defender-Azure.xml"
        }
        "Microsoft Windows 10 Enterprise for Virtual Desktops" {
            $url = "https://raw.githubusercontent.com/aaronparker/build-azure/master/tools/rds/Windows101903-Defender-Azure.xml"
        }
        "Microsoft Windows 10*" {
            $url = "https://raw.githubusercontent.com/aaronparker/build-azure/master/tools/rds/Windows101903-Defender-Azure.xml"
        }
    }
    Invoke-WebRequest -Uri $url -OutFile "$Path\Templates\$(Split-Path $url -Leaf)" -UseBasicParsing

    Write-Host "=============== Running Citrix Optimizer"
    & "$Path\CtxOptimizerEngine.ps1" -Source "$Path\Templates\$(Split-Path $url -Leaf)" -Mode execute -OutputHtml "$Path\CitrixOptimizer.html"
}

Function Invoke-Bisf ($Path) {
    Write-Host "========== Base Image Script Framework"
    If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }

    Write-Host "=============== Downloading BIS-F"
    #$url = (Get-BISF).URI
    $url = "https://github.com/EUCweb/BIS-F/archive/master.zip"
    Invoke-WebRequest -Uri $url -OutFile "$Path\$(Split-Path $url -Leaf)" -UseBasicParsing
    Expand-Archive -Path "$Path\$(Split-Path $url -Leaf)" -DestinationPath "$Path" -Force

    $url = "https://raw.githubusercontent.com/aaronparker/build-azure/master/tools/rds/BisfConfig.zip"
    Invoke-WebRequest -Uri $url -OutFile "$Path\$(Split-Path $url -Leaf)" -UseBasicParsing
    Expand-Archive -Path "$Path\$(Split-Path $url -Leaf)" -DestinationPath "$Path" -Force

    Write-Host "=============== Installing BIS-F"
    #Start-Process -FilePath "$Path\$(Split-Path $url -Leaf)" -ArgumentList "/SILENT" -Wait
    Remove-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Base Image Script Framework (BIS-F).lnk" -Force -ErrorAction SilentlyContinue
    New-Item -Path "${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    Copy-Item -Path "$Path\BISFSharedConfig.json" -Destination "${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)\BISFSharedConfig.json"

    Write-Host "=============== Running BIS-F"
    & "$Path\BIS-F-master\Framework\PrepBISF_Start.ps1"
    & "${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)\Framework\PrepBISF_Start.ps1"
}
#endregion

#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Start logging
Start-Transcript -Path $Log
If (!(Test-Path $Target)) { New-Item -Path $Target -Type Directory -Force -ErrorAction SilentlyContinue }

# Set TLS to 1.2; Create target folder
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
If (!(Test-Path $Target)) { New-Item -Path $Target -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" }

# Seal image tasks
Set-Repository
Install-RequiredModules
Invoke-WindowsDefender
Invoke-CitrixOptimizer -Path "$Target\CitrixOptimizer"

# Stop Logging
Stop-Transcript
#endregion
