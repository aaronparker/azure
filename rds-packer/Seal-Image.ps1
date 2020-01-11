<# 
    .SYSOPSIS
        Seal an RDSH image.
#>
[CmdletBinding()]
Param (
    [Parameter()] $Log = "$env:SystemRoot\Logs\AzureArmCustomSeal.log",
    [Parameter()] $Target = "$env:SystemDrive\Apps"
)

# Start logging; Set $VerbosePreference so full details are sent to the log
$VerbosePreference = "Continue"
Start-Transcript -Path $Log
If (!(Test-Path $Target)) { New-Item -Path $Target -Type Directory -Force -ErrorAction SilentlyContinue }

# Run Windows Defender quick scan; Running via BISF doesn't exit
Start-Process -FilePath "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -ArgumentList "-SignatureUpdate -MMPC" -Wait
Start-Process -FilePath "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -ArgumentList "-Scan -ScanType 1" -Wait
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\RemovalTools\MRT" -Name "GUID" -Value ""

#region Citrix Optimizer
    $Dest = "$Target\CitrixOptimizer"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue }
    $url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/scripts/rds/CitrixOptimizer.zip"
    Start-BitsTransfer -Source $url -Destination "$Dest\$(Split-Path $url -Leaf)"
    Expand-Archive -Path "$Dest\$(Split-Path $url -Leaf)"  -DestinationPath "$Dest" -Force
    & "$Dest\CtxOptimizerEngine.ps1" `
        -Source "$Dest\Templates\WindowsServer2016-WindowsDefender-Azure.xml" `
        -Mode execute -OutputHtml "$Dest\CitrixOptimizer.html"
#endregion

#region BIS-F
    $Dest = "$Target\BISF"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue }
    $url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/scripts/rds/bisf-6.1.0.zip"
    Start-BitsTransfer -Source $url -Destination "$Dest\$(Split-Path $url -Leaf)"
    Expand-Archive -Path "$Dest\$(Split-Path $url -Leaf)"  -DestinationPath "$Dest" -Force
    Start-Process -FilePath "$Dest\setup-BIS-F-6.1.0_build01.100.exe" -ArgumentList "/SILENT" -Wait
    Remove-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Base Image Script Framework (BIS-F).lnk" -Force
    Copy-Item -Path "$Dest\*.xml" -Destination "${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)"
    & "${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)\Framework\PrepBISF_Start.ps1"
#endregion


# Clean up
$Path = "$env:SystemDrive\Logs"
Push-Location "$env:SystemDrive\"
If (Test-Path $Path) { Remove-Item -Path $Path -Recurse -ErrorAction SilentlyContinue -Force }
If (Test-Path $Target) { Remove-Item -Path $Target -Recurse -ErrorAction SilentlyContinue -Force }
Get-ScheduledTask "Seal Image" | Unregister-ScheduledTask -Confirm:$False


# Stop Logging
Stop-Transcript
