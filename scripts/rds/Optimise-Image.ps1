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

Function Invoke-WindowsDefender {
    # Run Windows Defender quick scan
    Write-Host "=============== Running Windows Defender"
    Start-Process -FilePath "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -ArgumentList "-SignatureUpdate -MMPC" -Wait
    Start-Process -FilePath "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -ArgumentList "-Scan -ScanType 1" -Wait
    # Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\RemovalTools\MRT" -Name "GUID" -Value ""
}

Function Invoke-CitrixOptimizer ($Path) {
    Write-Host "========== Citrix Optimizer"
    If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType Directory -Force -ErrorAction SilentlyContinue > $Null }

    Write-Host "=============== Downloading Citrix Optimizer"
    $url = "https://raw.githubusercontent.com/aaronparker/build-azure/master/tools/rds/CitrixOptimizer.zip"
    Invoke-WebRequest -Uri $url -OutFile "$Path\$(Split-Path $url -Leaf)" -UseBasicParsing
    Expand-Archive -Path "$Path\$(Split-Path $url -Leaf)" -DestinationPath $Path -Force

    # Download templates
    Write-Host "=============== Downloading Citrix Optimizer template"
    If (!(Test-Path $Path)) { New-Item -Path "$Path\Templates" -ItemType Directory -Force -ErrorAction SilentlyContinue > $Null }
    Switch -Regex ((Get-WmiObject Win32_OperatingSystem).Caption) {
        "Microsoft Windows Server*" {
            $url = "https://raw.githubusercontent.com/aaronparker/build-azure/master/tools/rds/WindowsServer2019-Defender-Azure.xml"
        }
        "Microsoft Windows 10 Enterprise for Virtual Desktops" {
            $url = "https://raw.githubusercontent.com/aaronparker/build-azure/master/tools/rds/Windows101909-Defender-Azure.xml"
        }
        "Microsoft Windows 10*" {
            $url = "https://raw.githubusercontent.com/aaronparker/build-azure/master/tools/rds/Windows101909-Defender-Azure.xml"
        }
    }
    Invoke-WebRequest -Uri $url -OutFile "$Path\Templates\$(Split-Path $url -Leaf)" -UseBasicParsing

    Write-Host "=============== Running Citrix Optimizer"
    & "$Path\CtxOptimizerEngine.ps1" -Source "$Path\Templates\$(Split-Path $url -Leaf)" -Mode execute -OutputHtml "$Path\CitrixOptimizer.html"
}

Function Invoke-Bisf ($Path) {
    Write-Host "========== Base Image Script Framework"
    If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType Directory -Force -ErrorAction SilentlyContinue > $Null }

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
    New-Item -Path "${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)" -ItemType Directory -Force -ErrorAction SilentlyContinue > $Null
    Copy-Item -Path "$Path\BISFSharedConfig.json" -Destination "${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)\BISFSharedConfig.json"

    Write-Host "=============== Running BIS-F"
    & "$Path\BIS-F-master\Framework\PrepBISF_Start.ps1"
    & "${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)\Framework\PrepBISF_Start.ps1"
}

Function Invoke-MicrosoftOptimizations {
<#
- NOTE:           Original script details here:
- TITLE:          Microsoft Windows 1909  VDI/WVD Optimization Script
- AUTHORED BY:    Robert M. Smith and Tim Muessig (Microsoft Premier Services)
- AUTHORED DATE:  11/19/2019
- LAST UPDATED:   04/10/2020
- PURPOSE:        To automatically apply setting referenced in white paper:
                  "Optimizing Windows 10, Build 1909, for a Virtual Desktop Infrastructure (VDI) role"
                  URL: TBD

- REFERENCES:
https://social.technet.microsoft.com/wiki/contents/articles/7703.powershell-running-executables.aspx
https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/remove-item?view=powershell-6
https://blogs.technet.microsoft.com/secguide/2016/01/21/lgpo-exe-local-group-policy-object-utility-v1-0/
https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/set-service?view=powershell-6
https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/remove-item?view=powershell-6
https://msdn.microsoft.com/en-us/library/cc422938.aspx
#>

#Set-Location $PSScriptRoot

#region Disable Scheduled Tasks
# This section is for disabling scheduled tasks.  If you find a task that should not be disabled
# comment or delete from the "SchTaskList.txt" file.
$SchTasksList = @("BgTaskRegistrationMaintenanceTask", "Consolidator", "Diagnostics", "FamilySafetyMonitor",
"FamilySafetyRefreshTask", "MapsToastTask", "*Compatibility*", "Microsoft-Windows-DiskDiagnosticDataCollector",
"*MNO*", "NotificationTask", "PerformRemediation", "ProactiveScan", "ProcessMemoryDiagnosticEvents", "Proxy",
"QueueReporting", "RecommendedTroubleshootingScanner", "ReconcileLanguageResources", "RegIdleBackup",
"RunFullMemoryDiagnostic", "Scheduled", "ScheduledDefrag", "SilentCleanup", "SpeechModelDownloadTask",
"Sqm-Tasks", "SR", "StartupAppTask", "SyspartRepair", "UpdateLibrary", "WindowsActionDialog", "WinSAT",
"XblGameSaveTask")
If ($SchTasksList.count -gt 0) {
    $EnabledScheduledTasks = Get-ScheduledTask | Where-Object { $_.State -ne "Disabled" }
    Foreach ($Item in $SchTasksList) {
        $Task = (($Item -split ":")[0]).Trim()
        $EnabledScheduledTasks | Where-Object { $_.TaskName -like "*$Task*" } | Disable-ScheduledTask
    }
}
#endregion

#region Disable Windows Traces
$DisableAutologgers = @(
"HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\AppModel\",
"HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\CloudExperienceHostOOBE\",
"HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DiagLog\",
"HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\ReadyBoot\",
"HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WDIContextLog\",
"HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WiFiDriverIHVSession\",
"HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WiFiSession\",
"HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WinPhoneCritical\")
If ($DisableAutologgers.count -gt 0) {
    Foreach ($Item in $DisableAutologgers) {
        Write-Host "Processing $Item"
        New-ItemProperty -Path "$Item" -Name "Start" -PropertyType "DWORD" -Value "0" -Force
    }
}
#endregion

#region Disable Services
#################### BEGIN: DISABLE SERVICES section ###########################
$ServicesToDisable = @("autotimesvc", "BcastDVRUserService", "CDPSvc", "CDPUserSvc", "CscService",
"defragsvc", "DiagSvc", "DiagTrack", "DPS", "DsmSvc", "DusmSvc", "icssvc", "lfsvc", "MapsBroker",
"MessagingService", "OneSyncSvc", "PimIndexMaintenanceSvc", "Power", "SEMgrSvc", "SmsRouter",
"SysMain", "TabletInputService", "UsoSvc", "VSS", "WdiSystemHost", "WerSvc", "XblAuthManager",
"XblGameSave", "XboxGipSvc", "XboxNetApiSvc")
If ($ServicesToDisable.count -gt 0) {
    Foreach ($Item in $ServicesToDisable) {
        Write-Host "Processing $Item"
        Stop-Service $Item -Force -ErrorAction SilentlyContinue
        Set-Service $Item -StartupType Disabled 
        #New-ItemProperty -Path "$Item" -Name "Start" -PropertyType "DWORD" -Value "4" -Force
    }
}
#endregion

#region Network Optimization
# LanManWorkstation optimizations
New-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanmanWorkstation\Parameters\" -Name "DisableBandwidthThrottling" -PropertyType "DWORD" -Value "1" -Force
New-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanmanWorkstation\Parameters\" -Name "FileInfoCacheEntriesMax" -PropertyType "DWORD" -Value "1024" -Force
New-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanmanWorkstation\Parameters\" -Name "DirectoryCacheEntriesMax" -PropertyType "DWORD" -Value "1024" -Force
New-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanmanWorkstation\Parameters\" -Name "FileNotFoundCacheEntriesMax" -PropertyType "DWORD" -Value "1024" -Force
New-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanmanWorkstation\Parameters\" -Name "DormantFileLimit" -PropertyType "DWORD" -Value "256" -Force

# NIC Advanced Properties performance settings for network biased environments
# Set-NetAdapterAdvancedProperty -DisplayName "Send Buffer Size" -DisplayValue 4MB

<# Note that the above setting is for a Microsoft Hyper-V VM.  You can adjust these values in your environment...
by querying in PowerShell using Get-NetAdapterAdvancedProperty, and then adjusting values using the...
Set-NetAdapterAdvancedProperty command.
#>
#endregion

#region Disk Cleanup
# Disk Cleanup Wizard automation (Cleanmgr.exe /SAGESET:11)
# If you prefer to skip a particular disk cleanup category, edit the "Win10_1909_DiskCleanRegSettings.txt"
$DiskCleanupSettings = @(
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Active Setup Temp Folders\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\BranchCache\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\D3D Shader Cache\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Diagnostic Data Viewer database files\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Downloaded Program Files\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Old ChkDsk Files\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Previous Installations\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Recycle Bin\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\RetailDemo Offline Content\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Service Pack Cleanup\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Setup Log Files\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\System error memory dump files\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\System error minidump files\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Files\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Setup Files\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Thumbnail Cache\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Update Cleanup\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Upgrade Discarded Files\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\User file versions\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Defender\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Error Reporting Files\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows ESD installation files\",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Upgrade Log Files\")
If ($DiskCleanupSettings.count -gt 0) {
    Foreach ($Item in $DiskCleanupSettings) {
        Write-Host "Processing $Item"
        New-ItemProperty -Path "$Item" -Name "StateFlags0011" -PropertyType "DWORD" -Value "2" -Force
    }
}
Write-Host "=============== Running Disk Cleanup"
Start-Process C:\Windows\System32\Cleanmgr.exe -ArgumentList "SAGERUN:11" -Wait
#endregion

#region
# ADDITIONAL DISK CLEANUP
# Delete not in-use files in locations C:\Windows\Temp and %temp%
# Also sweep and delete *.tmp, *.etl, *.evtx (not in use==not needed)

$FilesToRemove = Get-ChildItem -Path "$env:SystemDrive\" -Include *.tmp, *.etl, *.evtx -Recurse -Force -ErrorAction SilentlyContinue
$FilesToRemove | Remove-Item -ErrorAction SilentlyContinue

# Delete not in-use anything in the C:\Windows\Temp folder
Remove-Item -Path $env:windir\Temp\* -Recurse -Force -ErrorAction SilentlyContinue

# Delete not in-use anything in your %temp% folder
Remove-Item -Path $env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue
#endregion
}
#endregion

#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Start logging
Start-Transcript -Path $Log -Append -ErrorAction SilentlyContinue

# Set TLS to 1.2; Create target folder
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
New-Item -Path $Target -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

# Seal image tasks
Set-Repository
Invoke-WindowsDefender
# Invoke-CitrixOptimizer -Path "$Target\CitrixOptimizer"
Invoke-MicrosoftOptimizations

# Stop Logging
Stop-Transcript -ErrorAction SilentlyContinue
#endregion
