<#
    .SYNOPSIS
        Downloads Hashicorp Packer plugins
#>

# Setup environment
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Global variables
$target = "$env:AppData\packer.d\plugins"

# Windows Update plugin
$url = "https://github.com/rgl/packer-provisioner-windows-update/releases/download/v0.10.1/packer-provisioner-windows-update_0.10.1_windows_amd64.zip"
# $url = "https://github.com/rgl/packer-provisioner-windows-update/releases/download/v0.9.0/packer-provisioner-windows-update-windows.zip"
$zip = "$env:Temp\packer-provisioner-windows-update-windows.zip"
$exe = "packer-provisioner-windows-update.exe"
If (Test-Path -Path (Join-Path -Path $target -ChildPath $exe)) {
    Write-Host "Windows Update Packer plugin exists." -ForegroundColor Cyan
}
Else {
    Write-Host "Downloading Windows Update Packer plugin." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -ErrorAction "SilentlyContinue"
    }
    catch {
        Write-Error -Message $_.Exception.Message
        Break
    }
    finally {
        Expand-Archive -Path $zip -DestinationPath $target
        Remove-Item -Path $zip
    }
}
