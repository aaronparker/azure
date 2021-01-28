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
Function Install-AdobeReaderDC ($Path) {
    # Enforce settings with GPO: https://www.adobe.com/devnet-docs/acrobatetk/tools/AdminGuide/gpo.html
    # Download Reader installer and updater
    Write-Host "================ Adobe Acrobat Reader DC"
    Write-Host "================ Downloading Reader"
    $Reader = Get-AdobeAcrobatReaderDC | Where-Object { $_.Language -eq "English" -or $_.Language -eq "Neutral" }

    If ($Reader) {
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" > $Null }

        $Installer = ($Reader | Where-Object { $_.Type -eq "Installer" | Sort-Object -Property "Version" -Descending })[-1]
        $Updater = ($Reader | Where-Object { $_.Type -eq "Updater" | Sort-Object -Property "Version" -Descending })[-1]
        
        # Download Adobe Reader
        ForEach ($File in $Installer) {
            $OutFile = Join-Path -Path $Path -ChildPath (Split-Path -Path $File.Uri -Leaf)
            Write-Host "================ Downloading to: $OutFile."
            try {
                Invoke-WebRequest -Uri $File.Uri -OutFile $OutFile -UseBasicParsing
                If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
            }
            catch {
                Throw "Failed to download Adobe Reader installer."
                Break
            }
        }
    
        # Download the updater if the updater version is greater than the installer
        If ($Updater.Version -gt $Installer.Version) {
            ForEach ($File in $Updater) {
                $OutFile = Join-Path -Path $Path -ChildPath (Split-Path -Path $File.Uri -Leaf)
                Write-Host "================ Downloading to: $OutFile."
                try {
                    Invoke-WebRequest -Uri $File.Uri -OutFile $OutFile -UseBasicParsing
                    If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
                }
                catch {
                    Throw "Failed to download Adobe Reader update patch."
                    Break
                }
            }
        }
        Else {
            Write-Host "================ Installer already up to date, skipping patch file."
        }

        # Get resource strings
        $res = Export-EvergreenFunctionStrings -AppName "AdobeAcrobatReaderDC"

        # Install Adobe Reader
        Write-Host "================ Installing Reader"
        try {
            $Installers = Get-ChildItem -Path $Path -Filter "*.exe"
            ForEach ($exe in $Installers) {
                Invoke-Process -FilePath $exe.FullName -ArgumentList $res.Install.Virtual.Arguments -Verbose
            }
        }
        catch {
            "Throw failed to install Adobe Reader."
        }

        # Run post install actions
        Write-Host "================ Post install configuration Reader"
        ForEach ($command in $res.Install.Virtual.PostInstall) {
            Invoke-Command -ScriptBlock ($executioncontext.invokecommand.NewScriptBlock($command))
        }

        # Update Adobe Reader
        Write-Host "================ Update Reader"
        try {
            $Updates = Get-ChildItem -Path $Path -Filter "*.msp"
            ForEach ($msp in $Updates) {
                Write-Host "================ Installing update: $($msp.FullName)."
                Invoke-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/update $($msp.FullName) /quiet /qn" -Verbose
            }
        }
        catch {
            "Throw failed to update Adobe Reader."
        }
        Write-Host "================ Done"
    }
    Else {
        Write-Host "================ Failed to retreive Adobe Reader"
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
Install-AdobeReaderDC -Path "$Target\AdobeReader"

# Stop Logging
Stop-Transcript -ErrorAction SilentlyContinue
Write-Host "================ Complete: $($MyInvocation.MyCommand)."
#endregion
