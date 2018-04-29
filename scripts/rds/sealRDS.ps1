<# 
    .SYSOPSIS
        Customise a Windows Server image for use as an RDS/XenApp VM in Azure.
        Installs Office 365 ProPlus, Adobe Reader DC, Visual C++ Redistributables. Installs applications from a network path specified in AppShare.
        Sets regional settings, installs Windows Updates, configures the default profile.
        Runs Windows Defender quick scan, Citrix Optimizer, BIS-F
#>
[CmdletBinding()]
Param (
    [Parameter()]
    [String] $Log = "$env:SystemRoot\Logs\AzureArmCustomSeal.log",

    [Parameter()]
    [String] $Target = "$env:SystemDrive\Apps",

    [Parameter()]
    [String] $User,

    [Parameter()]
    [String] $Pass,

    [Parameter()]
    [String] $AppShare
)

# Start logging; Set $VerbosePreference so full details are sent to the log
$VerbosePreference = "Continue"
Start-Transcript -Path $Log
New-Item -Path $Target -ItemType Directory

# Run Windows Defender quick scan; Running via BISF doesn't exit
Start-Process -FilePath "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -ArgumentList "-SignatureUpdate -MMPC" -Wait
Start-Process -FilePath "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -ArgumentList "-Scan -ScanType 1" -Wait
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\RemovalTools\MRT" -Name "GUID" -Value ""

# Citrix Optimizer
$Dest = "$Target\CitrixOptimizer"
If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory }
$url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/scripts/rds/CitrixOptimizer.zip"
Start-BitsTransfer -Source $url -Destination "$Dest\$(Split-Path $url -Leaf)"
Expand-Archive -Path "$Dest\$(Split-Path $url -Leaf)"  -DestinationPath "$Dest"
& "$Dest\CtxOptimizerEngine.ps1" `
    -Source "$Dest\Templates\WindowsServer2016-WindowsDefender-Azure.xml" `
    -Mode execute -OutputHtml "$Dest\CitrixOptimizer.html"

# BIS-F
$Dest = "$Target\BISF"
If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory }
$url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/scripts/rds/bisf-6.1.0.zip"
Start-BitsTransfer -Source $url -Destination "$Dest\$(Split-Path $url -Leaf)"
Expand-Archive -Path "$Dest\$(Split-Path $url -Leaf)"  -DestinationPath "$Dest"
Start-Process -FilePath "$Dest\setup-BIS-F-6.1.0_build01.100.exe" -ArgumentList "/SILENT"
Remove-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Base Image Script Framework (BIS-F).lnk" -Force
Copy-Item -Path "$Dest\*.xml" -Destination "${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)"
& "${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)\Framework\PrepBISF_Start.ps1"
#endregion


# Clean up
$Path = "$env:SystemDrive\Logs"
If (Test-Path $Path) { Remove-Item -Path $Path -Recurse }
If (Test-Path $Target) { Remove-Item -Path $Target -Recurse }


# Stop Logging
Stop-Transcript

# Replace clear text passwords in the log file
(Get-Content $Log).replace($Pass, "") | Set-Content $Log
