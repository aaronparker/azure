<# 
    .SYNOPSIS
        Install evergreen core applications.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Log = "$env:SystemRoot\Logs\PackerImagePrep.log",

    [Parameter(Mandatory = $False)]
    [System.String] $Target = "$env:SystemDrive\Apps"
)

#region Functions
Function Install-VcRedistributables ($Path) {
    Write-Host "================ Microsoft Visual C++ Redistributables"
    If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }
    $VcList = Get-VcList -Release 2010, 2012, 2013, 2019

    Write-Host "================ Downloading Microsoft Visual C++ Redistributables"
    Save-VcRedist -Path $Path -VcList $VcList > $Null
    Write-Host "================ Installing Microsoft Visual C++ Redistributables"
    Install-VcRedist -VcList $VcList -Path $Path -Silent
    Write-Host "================ Done"
}
#endregion Functions


#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Start logging
Start-Transcript -Path $Log -Append -ErrorAction SilentlyContinue

# Set TLS to 1.2; Create target folder
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
New-Item -Path $Target -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null

# Run tasks/install apps
Install-VcRedistributables -Path "$Target\VcRedist"

# Stop Logging
Stop-Transcript -ErrorAction SilentlyContinue
Write-Host "================ Complete: $($MyInvocation.MyCommand)."
#endregion
