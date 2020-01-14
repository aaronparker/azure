<# 
    .SYNOPSIS
        Setup Chocolatey and Boxstarter for a Packer image build
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [string] $Log = "$env:SystemRoot\Logs\AzureArmCustomDeploy.log",

    [Parameter(Mandatory = $False)]
    [string] $Target = "$env:SystemDrive\Apps",
        
    [Parameter(Mandatory = $False)]
    [string] $VerbosePreference = "Continue"
)

# Defender
Write-Host "Disable Windows Defender real time scan"
Set-MpPreference -DisableRealtimeMonitoring $true

# Local working folder
New-Item -Path $Target -ItemType Directory -Force -ErrorAction SilentlyContinue

# Install Chocolatey and Boxstarter
Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco install Boxstarter -y
If (Test-Path -Path "$env:Public\Desktop\Boxstarter Shell.lnk") { Remove-Item -Path "$env:Public\Desktop\Boxstarter Shell.lnk" -Force }
If (Test-Path -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Boxstarter\Boxstarter Shell.lnk") { Remove-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Boxstarter\Boxstarter Shell.lnk" -Force }

