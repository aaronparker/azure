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
Function Install-FSLogix ($Path) {
    Write-Host "================ Microsoft FSLogix agent"
    $FSLogix = Get-MicrosoftFSLogixApps

    If ($FSLogix) {
        Write-Host "================ Microsoft FSLogix: $($FSLogix.Version)"
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

        # Download
        $OutFile = $(Split-Path -Path $FSLogix.URI -Leaf)
        Write-Host "================ Downloading to: $Path\$OutFile"
        try {
            Invoke-WebRequest -Uri $FSLogix.URI -OutFile "$Path\$OutFile" -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
        }
        catch {
            Throw "Failed to download FSLogix Apps"
        }

        # Unpack and install
        Expand-Archive -Path "$Path\$OutFile" -DestinationPath $Path -Force
        Write-Host "================ Installing FSLogix agent"
        try {
            Invoke-Process -FilePath "$Path\x64\Release\FSLogixAppsSetup.exe" -ArgumentList "/install /quiet /norestart" -Verbose
        }
        catch {
            Throw "Failed to install the FSlogix Apps agent."
        }
        try {
            Invoke-Process -FilePath "$Path\x64\Release\FSLogixAppsRuleEditorSetup.exe" -ArgumentList "/install /quiet /norestart" -Verbose
        }
        catch {
            Throw "Failed to install the FSlogix Apps Rules Editor."
        }
        Write-Host "================ Done"
    }
    Else {
        Write-Host "================ Failed to retreive Microsoft FSLogix Apps"
    }
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
Install-FSLogix -Path "$Target\FSLogix"

# Stop Logging
Stop-Transcript -ErrorAction SilentlyContinue
Write-Host "================ Complete: $($MyInvocation.MyCommand)."
#endregion
