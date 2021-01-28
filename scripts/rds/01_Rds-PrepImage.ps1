<# 
    .SYNOPSIS
        Preps a RDS/WVD image for customisation.
#>
[CmdletBinding()]
Param ()

# Ready image
Write-Output "====== Disable Windows Defender real time scan"
Set-MpPreference -DisableRealtimeMonitoring $true

Write-Output "====== Disable Windows Store updates"
reg add HKLM\Software\Policies\Microsoft\Windows\CloudContent /v DisableWindowsConsumerFeatures /d 1 /t REG_DWORD /f
reg add HKLM\Software\Policies\Microsoft\WindowsStore /v AutoDownload /d 2 /t REG_DWORD /f

Write-Host "Complete: Rds-PrepImage.ps1."
