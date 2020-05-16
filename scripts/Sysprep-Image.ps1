<# 
    .SYNOPSIS
        Sysprep image.
#>
[CmdletBinding()]
Param ()

# Sysprep
Write-Output "====== Run Sysprep"
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State"
& $env:SystemRoot\System32\Sysprep\Sysprep.exe /oobe /generalize /quiet /quit
While ($True) {
    $imageState = Get-ItemProperty $RegPath | Select-Object ImageState
    If ($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') {
        Write-Output $imageState.ImageState
        Start-Sleep -s 10 
    }
    Else {
        Break
    }
}
$imageState = Get-ItemProperty $RegPath | Select-Object ImageState
Write-Output $imageState.ImageState
