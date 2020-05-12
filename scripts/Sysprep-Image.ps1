#Write-Output \"====== Prep for Sysprep\"
#Set-Service -Name RdAgent -StartupType Disabled; Stop-Service -Name RdAgent -ErrorAction SilentlyContinue"
#Set-Service -Name WindowsAzureTelemetryService -StartupType Disabled; Stop-Service -Name WindowsAzureTelemetryService -ErrorAction SilentlyContinue"
#Set-Service -Name WindowsAzureGuestAgent -StartupType Disabled; Stop-Service -Name WindowsAzureGuestAgent -ErrorAction SilentlyContinue"
#Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\SysPrepExternal\Generalize' -Name '*'"

Write-Output "====== Run Sysprep"
& $env:SystemRoot\System32\Sysprep\Sysprep.exe /oobe /generalize /quiet /quit

While ($True) {
    $imageState = Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State | Select-Object ImageState
    If ($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') {
        Write-Output $imageState.ImageState
        Start-Sleep -s 10 
    }
    Else {
        Break
    }
}
