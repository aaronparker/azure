Write-Host -ForegroundColor "Cyan" "Start OSDCloud"
Start-Sleep -Seconds 5

# Change Display Resolution for Virtual Machine
if ((Get-MyComputerModel) -match 'Virtual') {
    Write-Host -ForegroundColor "Cyan" "Set display resolution to 1440x900"
    Set-DisRes -Width "1440" -Height "900"
}

# Update the module
Write-Host -ForegroundColor "Cyan" "Update module"
Install-Module -Name "OSD"

Write-Host -ForegroundColor "Cyan" "Import module"
Import-Module -Name "OSD" -Force


# Start OSDCloud ZTI
Write-Host -ForegroundColor "Cyan" "Start OSDCloud deployment"
$params = @{
    OSLanguage = "en-US"
    OSName     = "Windows 10 21H2 x64"
    OSEdition  = "Pro"
    OSLicense  = "Retail"
    ZTI        = $True
}
Start-OSDCloud @params

# Restart from WinPE
Write-Host -ForegroundColor "Cyan" "Restart in 20 seconds."
for ($i = 1; $i -le 20; $i++ ) {
    Write-Progress -Activity "Waiting to reboot" -Status "Seconds: $i" -PercentComplete $($i / 20 * 100)
    Start-Sleep -Seconds 1
}
wpeutil reboot
