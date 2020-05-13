<# 
    .SYNOPSIS
        Install evergreen core applications.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Log = "$env:SystemRoot\Logs\AzureArmCustomDeploy.log",

    [Parameter(Mandatory = $False)]
    [System.String] $Target = "$env:SystemDrive\Apps"
)

#region Functions
Function Set-Repository {
    # Trust the PSGallery for modules
    If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
        Write-Verbose "Trusting the repository: PSGallery"
        Install-PackageProvider -Name "NuGet" -MinimumVersion 2.8.5.208 -Force
        Set-PSRepository -Name "PSGallery" -InstallationPolicy "Trusted"
    }
}

Function Invoke-Process {
    <#PSScriptInfo 
    .VERSION 1.4 
    .GUID b787dc5d-8d11-45e9-aeef-5cf3a1f690de 
    .AUTHOR Adam Bertram 
    .COMPANYNAME Adam the Automator, LLC 
    .TAGS Processes 
    #>

    <# 
    .DESCRIPTION 
    Invoke-Process is a simple wrapper function that aims to "PowerShellyify" launching typical external processes. There 
    are lots of ways to invoke processes in PowerShell with Invoke-Process, Invoke-Expression, & and others but none account 
    well for the various streams and exit codes that an external process returns. Also, it's hard to write good tests 
    when launching external proceses. 
 
    This function ensures any errors are sent to the error stream, standard output is sent via the Output stream and any 
    time the process returns an exit code other than 0, treat it as an error. 
    #> 
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $FilePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String] $ArgumentList
    )

    $ErrorActionPreference = 'Stop'

    try {
        $stdOutTempFile = "$env:TEMP\$((New-Guid).Guid)"
        $stdErrTempFile = "$env:TEMP\$((New-Guid).Guid)"

        $startProcessParams = @{
            FilePath               = $FilePath
            ArgumentList           = $ArgumentList
            RedirectStandardError  = $stdErrTempFile
            RedirectStandardOutput = $stdOutTempFile
            Wait                   = $true
            PassThru               = $true
            NoNewWindow            = $true
        }
        if ($PSCmdlet.ShouldProcess("Process [$($FilePath)]", "Run with args: [$($ArgumentList)]")) {
            $cmd = Start-Process @startProcessParams
            $cmdOutput = Get-Content -Path $stdOutTempFile -Raw
            $cmdError = Get-Content -Path $stdErrTempFile -Raw
            if ($cmd.ExitCode -ne 0) {
                if ($cmdError) {
                    throw $cmdError.Trim()
                }
                if ($cmdOutput) {
                    throw $cmdOutput.Trim()
                }
            }
            else {
                if ([System.String]::IsNullOrEmpty($cmdOutput) -eq $false) {
                    Write-Output -InputObject $cmdOutput
                }
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        Remove-Item -Path $stdOutTempFile, $stdErrTempFile -Force -ErrorAction Ignore
    }
}

Function Install-RequiredModules {
    Write-Host "=========== Installing required modules"
    # Install the Evergreen module; https://github.com/aaronparker/Evergreen
    Install-Module -Name Evergreen -AllowClobber

    # Install the VcRedist module; https://docs.stealthpuppy.com/vcredist/
    Install-Module -Name VcRedist -AllowClobber
}

Function Install-VcRedistributables ($Path) {
    Write-Host "=========== Microsoft Visual C++ Redistributables"
    If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null }
    $VcList = Get-VcList -Release 2010, 2012, 2013, 2019

    Write-Host "================ Downloading Microsoft Visual C++ Redistributables"
    Save-VcRedist -Path $Path -VcList $VcList -ForceWebRequest > $Null
    Write-Host "================ Installing Microsoft Visual C++ Redistributables"
    Install-VcRedist -VcList $VcList -Path $Path
    Write-Host "=========== Done"
}

Function Install-FSLogix ($Path) {
    Write-Host "=========== Microsoft FSLogix agent"
    $FSLogix = Get-MicrosoftFSLogixApps

    If ($FSLogix) {
        Write-Host "=========== Microsoft FSLogix: $($FSLogix.Version)"
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null }

        # Download
        $OutFile = $(Split-Path -Path $FSLogix.URI -Leaf)
        Write-Host "=========== Downloading to: $Path\$OutFile"
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
        Write-Host "=========== Done"
    }
    Else {
        Write-Host "================ Failed to retreive Microsoft FSLogix Apps"
    }
}

Function Install-MicrosoftEdge ($Path) {
    Write-Host "=========== Microsoft Edge"
    $Edge = Get-MicrosoftEdge | Where-Object { $_.Architecture -eq "x64" -and $_.Channel -eq "Stable" }
    $Edge = $Edge | Sort-Object -Property Version -Descending | Select-Object -First 1

    If ($Edge) {
        Write-Host "================ Downloading Microsoft Edge"
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null }

        # Download
        $url = $Edge.URI
        $OutFile = Join-Path -Path $Path -ChildPath $(Split-Path -Path $url -Leaf)
        Write-Host "=========== Downloading to: $OutFile"
        try {
            Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
        }
        catch {
            Throw "Failed to download Microsoft Edge."
        }

        # Install
        Write-Host "================ Installing Microsoft Edge"
        try {
            Invoke-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/package $OutFile /quiet /norestart DONOTCREATEDESKTOPSHORTCUT=true" -Verbose
        }
        catch {
            Throw "Failed to install Microsoft Edge."
        }

        # Post install configuration
        Remove-Item -Path "$env:Public\Desktop\Microsoft Edge*.lnk" -Force -ErrorAction SilentlyContinue
        $url = "https://raw.githubusercontent.com/aaronparker/build-azure/master/tools/rds/master_preferences"
        Invoke-WebRequest -Uri $url -OutFile "${Env:ProgramFiles(x86)}\Microsoft\Edge\Application\$(Split-Path -Path $url -Leaf)" -UseBasicParsing
        $services = "edgeupdate", "edgeupdatem", "MicrosoftEdgeElevationService"
        ForEach ($service in $services) { Get-Service -Name $service | Set-Service -StartupType "Disabled" }
        ForEach ($task in (Get-ScheduledTask -TaskName *Edge*)) { Unregister-ScheduledTask -TaskName $Task -Confirm:$False -ErrorAction SilentlyContinue }
        Remove-Variable -Name url
        Write-Host "=========== Done"
    }
    Else {
        Write-Host "================ Failed to retreive Microsoft Edge"
    }
}

Function Install-MicrosoftOffice ($Path) {
    # Get Office version
    Write-Host "=========== Microsoft Office"
    $Office = Get-MicrosoftOffice | Where-Object { $_.Channel -eq "Monthly" }
    $url = $Office.URI
    
    If ($Office) {
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null }

        $xml = "https://raw.githubusercontent.com/aaronparker/build-azure/master/tools/rds/Office365ProPlusRDS.xml"
        Write-Host "=========== Downloading to: $Path\$(Split-Path -Path $xml -Leaf)"
        Invoke-WebRequest -Uri $xml -OutFile "$Path\$(Split-Path -Path $xml -Leaf)" -UseBasicParsing
        
        # Download setup.exe
        $OutFile = Join-Path -Path $Path -ChildPath $(Split-Path -Path $url -Leaf)
        Write-Host "=========== Downloading to: $OutFile"
        try {
            Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
        }
        catch {
            Throw "Failed to download Microsoft Office setup."
        }

        # Download Office package, Setup fails to exit, so wait 9-10 mins for Office install to complete
        Push-Location -Path $Path
        Write-Host "================ Installing Microsoft Office"
        Invoke-Process -FilePath $OutFile -ArgumentList "/configure $Path\$(Split-Path -Path $xml -Leaf)" -Verbose
        Pop-Location
        Remove-Variable -Name url
        Write-Host "=========== Done"
    }
    Else {
        Write-Host "================ Failed to retreive Microsoft Office"
    }
}

Function Install-MicrosoftTeams ($Path) {
    Write-Host "=========== Microsoft Teams"
    Write-Host "================ Downloading Microsoft Teams"
    $Teams = Get-MicrosoftTeams | Where-Object { $_.Architecture -eq "x64" }
    
    If ($Teams) {
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null }

        # Download
        $url = $Teams.URI
        $OutFile = Join-Path -Path $Path -ChildPath $(Split-Path -Path $url -Leaf)
        Write-Host "=========== Downloading to: $OutFile"
        try {
            Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
        }
        catch {
            Throw "Failed to download Microsoft Teams."
        }

        # Install
        Write-Host "================ Installing Microsoft Teams"
        try {
            reg add "HKLM\SOFTWARE\Microsoft\Teams" /v "IsWVDEnvironment" /t REG_DWORD /d 1
            $ArgumentList = '/package $OutFile /quiet /qn ALLUSER=1 ALLUSERS=1 OPTIONS="noAutoStart=true"'
            Invoke-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList $ArgumentList -Verbose
            Remove-Variable -Name url
        }
        catch {
            Throw "Failed to install Microsoft Teams."
        }
        Write-Host "=========== Done"
    }
    Else {
        Write-Host "================ Failed to retreive Microsoft Teams"
    }
}

Function Install-MicrosoftOneDrive ($Path) {
    Write-Host "=========== Microsoft OneDrive"    
    Write-Host "================ Downloading Microsoft OneDrive"
    $OneDrive = Get-MicrosoftOneDrive | Where-Object { $_.Ring -eq "Enterprise" }

    If ($OneDrive) {
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null }

        # Download
        $url = $OneDrive.URI
        $OutFile = Join-Path -Path $Path -ChildPath $(Split-Path -Path $url -Leaf)
        Write-Host "=========== Downloading to: $OutFile"
        try {
            Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing
            If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
        }
        catch {
            Throw "Failed to download Microsoft OneDrive."
        }
    
        # Install
        Write-Host "================ Installing Microsoft OneDrive"
        try {
            Invoke-Process -FilePath $OutFile -ArgumentList "/ALLUSERS=1" -Verbose
        }
        catch {
            Throw "Failed to install Microsoft OneDrive."
        }
        Remove-Variable -Name url
        Write-Host "=========== Done"
    }
    Else {
        Write-Host "================ Failed to retreive Microsoft OneDrive"
    }
}

Function Install-AdobeReaderDC ($Path) {
    # Enforce settings with GPO: https://www.adobe.com/devnet-docs/acrobatetk/tools/AdminGuide/gpo.html
    # Download Reader installer and updater
    Write-Host "=========== Adobe Acrobat Reader DC"
    Write-Host "================ Downloading Reader"
    $Reader = Get-AdobeAcrobatReaderDC | Where-Object { $_.Platform -eq "Windows" -and ($_.Language -eq "English" -or $_.Language -eq "Neutral") }

    If ($Reader) {
        If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null }
        
        # Download Adobe Reader
        ForEach ($File in $Reader) {
            $url = $File.Uri
            $OutFile = Join-Path -Path $Path -ChildPath (Split-Path -Path $url -Leaf)
            Write-Host "=========== Downloading to: $OutFile."
            try {
                (New-Object System.Net.WebClient).DownloadFile($url, $OutFile)
                If (Test-Path -Path $OutFile) { Write-Host "================ Downloaded: $OutFile." }
            }
            catch {
                Throw "Failed to download Adobe Reader."
            }
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
        Write-Host "=========== Done"
    }
    Else {
        Write-Host "================ Failed to retreive Adobe Reader"
    }
}

Function Install-ConnectionExperienceIndicator ($Path) {

    Write-Host "=========== Connection Experience Indicator"
    Write-Host "================ Downloading Connection Experience Indicator"

    # Parameters
    $Url = "https://bit.ly/2RrQTd3"
    $OutFile = Join-Path -Path $Path -ChildPath "ConnectionExperienceIndicator.zip"
    If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null }

    # Download the file
    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
    }
    catch {
        Throw "Failed to download Connection Experience Indicator."
        Break
    }

    # Extract the zip file
    Expand-Archive -Path $OutFile -DestinationPath $Path
    Write-Host "=========== Done"
}
#endregion Functions


#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Start logging
Start-Transcript -Path $Log -Append -UseMinimalHeader -ErrorAction SilentlyContinue
If (!(Test-Path $Target)) { New-Item -Path $Target -Type Directory -Force -ErrorAction SilentlyContinue }

# Set TLS to 1.2; Create target folder
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
If (!(Test-Path $Target)) { New-Item -Path $Target -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" }

# Run tasks/install apps
Set-Repository
Install-RequiredModules
Install-VcRedistributables -Path "$Target\VcRedist"
Install-FSLogix -Path "$Target\FSLogix"
Install-MicrosoftEdge -Path "$Target\Edge"
Install-MicrosoftOffice -Path "$Target\Office"
Install-MicrosoftTeams -Path "$Target\Teams"
Install-MicrosoftOneDrive -Path "$Target\OneDrive"
Install-AdobeReaderDC -Path "$Target\AdobeReader"
Install-ConnectionExperienceIndicator -Path "$Target\ConnectionExperienceIndicator"

# Stop Logging
Stop-Transcript -ErrorAction SilentlyContinue
Write-Host "=========== Complete: $($MyInvocation.MyCommand)."
#endregion