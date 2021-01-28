<# 
    .SYNOPSIS
        Customise a Windows image for use as an WVD/XenApp VM in Azure.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Log = "$env:SystemRoot\Logs\PackerImagePrep.log",

    [Parameter(Mandatory = $False)]
    [System.String] $Target = "$env:SystemDrive\Apps"
)

#region Functions
Function Set-Customise ($Path) {
    If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

    # Customisation scripts
    $url = "https://github.com/aaronparker/image-customise/archive/main.zip"
    $OutFile = Join-Path -Path $Path -ChildPath $(Split-Path $url -Leaf)
    Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing
    try {
        Expand-Archive -Path $OutFile -DestinationPath $Path -Force
        Remove-Item -Path $OutFile
    }
    catch { }
    
    # Run scripts
    Push-Location (Join-Path -Path $Path -ChildPath "image-customise-main")
    . .\Invoke-Scripts.ps1 -Verbose
    Pop-Location
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

# Run tasks
Set-Customise -Path "$Target\Customise"

# Stop Logging
Stop-Transcript -ErrorAction SilentlyContinue
Write-Host "Complete: Rds-Customise.ps1."
#endregion
