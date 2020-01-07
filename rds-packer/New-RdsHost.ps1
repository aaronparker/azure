<# 
    .SYNOPSIS
        Customise a Windows Server image for use as an RDS/XenApp VM in Azure.
        Installs Office 365 ProPlus, Adobe Reader DC, Visual C++ Redistributables. Installs applications from a network path specified in AppShare.
        Sets regional settings, installs Windows Updates, configures the default profile.
        Runs Windows Defender quick scan, Citrix Optimizer, BIS-F
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $True)]
    [ValidateSet('RegionalSettings', 'Roles', 'CoreApps', 'LobApps', 'Customisations', 'WindowsUpdates', 'SealImage')]
    [string] $Task,

    [Parameter(Mandatory = $False)]
    [string] $Log = "$env:SystemRoot\Logs\AzureArmCustomDeploy.log",

    [Parameter(Mandatory = $False)]
    [string] $Target = "$env:SystemDrive\Apps",
    
    [Parameter(Mandatory = $False)]
    [string] $User,
    
    [Parameter(Mandatory = $False)]
    [string] $Pass,
    
    [Parameter(Mandatory = $False)]
    [string] $AppShare,
    
    [Parameter(Mandatory = $False)]
    [string] $VerbosePreference = "Continue"
)

#region Functions
Function Set-RegionalSettings {
    # Regional settings - set to en-AU / Australia
    Set-WinHomeLocation -GeoId 12
    Set-WinSystemLocale -SystemLocale en-AU
    Set-TimeZone -Id "AUS Eastern Standard Time" -Verbose
    $url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/scripts/common/language.xml"
    Start-BitsTransfer -Source $url -Destination "$Target\$(Split-Path $url -Leaf)"
    & $env:SystemRoot\System32\control.exe "intl.cpl,,/f:`"$Target\language.xml`""
}

Function Set-Roles {
    # Add / Remove roles (requires reboot at end of deployment)
    Disable-WindowsOptionalFeature -Online -FeatureName "Printing-XPSServices-Features", "WindowsMediaPlayer" -NoRestart -WarningAction SilentlyContinue
    Uninstall-WindowsFeature -Name BitLocker, EnhancedStorage, PowerShell-ISE
    Add-WindowsFeature -Name RDS-RD-Server, Server-Media-Foundation, 'Search-Service', NET-Framework-Core

    # Configure services
    Set-Service Audiosrv -StartupType Automatic
    Set-Service WSearch -StartupType Automatic
}

Function Install-Modules {
    # Trust the PSGallery for installing modules
    If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
        Write-Verbose "Trusting the repository: PSGallery"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }

    # Install the VcRedist module
    # https://docs.stealthpuppy.com/vcredist/
    Install-Module -Name VcRedist -AllowClobber

    # Install the Evergreen module
    Install-Module -Name Evergreen -AllowClobber

    # Install International module
    Import-Module -Name International -AllowClobber

    # Windows Update
    Install-Module PSWindowsUpdate -AllowClobber
}

Function Install-CoreApps {
    
    #region VcRedist
    $Dest = "$Target\VcRedist"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue }
    $VcList = Get-VcList | Get-VcRedist -Path $Dest
    Install-VcRedist -VcList $VcList -Path $Dest
    #endregion

    #region FSLogix Apps
    $Dest = "$Target\FSLogix"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue }

    $FSLogix = Get-MicrosoftFSLogixApps
    Start-BitsTransfer -Source $FSLogix.URI -Destination "$Dest\$(Split-Path -Path $FSLogix.URI -Leaf)"
    Expand-Archive -Path "$Dest\$(Split-Path -Path $FSLogix.URI -Leaf)" -DestinationPath $Dest -Force
    
    Start-Process -FilePath "$Dest\x64\Release\$(Split-Path -Path $FSLogix.URI -Leaf)" -ArgumentList "/install /quiet /norestart" -Wait
    #region


    #region Edge
    $Dest = "$Target\Edge"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue }

    $url = "http://dl.delivery.mp.microsoft.com/filestreamingservice/files/89e511fc-33dd-4869-b781-81b4264b3e1e/MicrosoftEdgeBetaEnterpriseX64.msi"
    Start-BitsTransfer -Source $url -Destination "$Dest\$(Split-Path -Path $url -Leaf)"
    Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/package $Dest\$(Split-Path -Path $url -Leaf) /quiet /norestart" -Wait
    #endregion


    #region Office
    # Install Office 365 ProPlus; manage installed options in configurationRDS.xml
    $Dest = "$Target\Office"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue }

    # Get the Office configuration.xml
    $url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/scripts/rds/Office/configurationRDS.xml"
    Start-BitsTransfer -Source $url -Destination "$Dest\$(Split-Path -Path $url -Leaf)"

    $Office = Get-MicrosoftOffice
    Start-BitsTransfer -Source $Office[0].URI -Destination "$Dest\$(Split-Path -Path $Office[0].URI -Leaf)"
    Start-Process -FilePath "$Dest\$(Split-Path -Path $Office[0].URI -Leaf)" -ArgumentList "/configure $Dest\$(Split-Path -Path $url -Leaf)" -Wait
    #endregion


    #region Reader
    # Install Adobe Reader DC
    # Enforce settings with GPO: https://www.adobe.com/devnet-docs/acrobatetk/tools/AdminGuide/gpo.html
    $Dest = "$Target\Reader"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory -Force -ErrorAction SilentlyContinue }

    # Download Reader installer and updater
    $Reader = Get-AdobeAcrobatReaderDC | Where-Object { $_.Platform -eq "Windows" -and ($_.Language -eq "English" -or $_.Language -eq "Neutral") }
    ForEach ($File in $Reader) {
        Invoke-WebRequest -Uri $File.Uri -OutFile (Join-Path -Path $Dest -ChildPath (Split-Path -Path $File.Uri -Leaf))
    }

    # Get resource strings
    $res = Export-EvergreenFunctionStrings -AppName "AdobeAcrobatReaderDC"

    # Install Adobe Reader
    $exe = Get-ChildItem -Path $Dest -Filter "*.exe"
    Start-Process -FilePath $exe.FullName -ArgumentList $res.Install.Virtual.Arguments -Wait

    # Run post install actions
    ForEach ($command in $res.Install.Virtual.PostInstall) {
        Invoke-Command -ScriptBlock ($executioncontext.invokecommand.NewScriptBlock($command))
    }

    # Update Adobe Reader
    $msp = Get-ChildItem -Path $Dest -Filter "*.msp"
    Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/update $($msp.FullName) /quiet" -Wait
    #endregion
}

Function Install-LobApps {
    #region Applications - Source local share
    # Create credential to authenticate
    If ($AppShare) {
    
        # Create PS drive to apps share (Apps:)
        $password = ($Pass | ConvertTo-SecureString -AsPlainText -Force)
        $cred = New-Object System.Management.Automation.PSCredential ($User, $password)
        $drive = New-PSDrive -Name Apps -PSProvider FileSystem -Root $AppShare -Credential $cred

        If ($drive) {
            $current = $PWD
            Push-Location "Apps:\"

            # Copy each folder locally and install
            ForEach ($folder in (Get-ChildItem -Path ".\" -Directory)) {
                Copy-Item -Path $folder.FullName -Destination "$target\$($folder.Name)" -Recurse -Force
                Push-Location "$target\$($folder.Name)"
                If (Test-Path "$target\$($folder.Name)\install.cmd") {
                    Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList "/c $target\$($folder.Name)\install.cmd" -Wait
                }
            }
            Push-Location $current
            Remove-PSDrive Apps
        }
    }
}

Function Set-Customisations {
    #region Customisations
    # DisableIEEnhancedSecurity 
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Type DWORD -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Type DWORD -Value 0

    # HideServerManagerOnLogin 
    If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Server\ServerManager")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Server\ServerManager" -Force
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Server\ServerManager" -Name "DoNotOpenAtLogon" -Type DWORD -Value 1

    # EnableSmartScreen
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableSmartScreen" -Type DWORD -Value 2
    # Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter" -Name "EnabledV9" -Type DWORD -Value 1

    # DisableAutorun
    If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -Type DWORD -Value 255

    # Default Profile etc.
    $Dest = "$Target\Customise"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory }
    $url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/scripts/rds/Customise.zip"
    Start-BitsTransfer -Source $url -Destination "$Dest\$(Split-Path $url -Leaf)"
    Expand-Archive -Path "$Dest\$(Split-Path $url -Leaf)"  -DestinationPath "$Dest" -Force
    Push-Location $Dest
    Get-ChildItem -Path $Dest -Filter *.ps1 | ForEach-Object { & $_.FullName }
    Pop-Location
}

Function Install-WindowsUpdates {
    Add-WUServiceManager -ServiceID "7971f918-a847-4430-9279-4a52d1efe18d" -Confirm:$False
    Get-WUInstall -MicrosoftUpdate -Confirm:$False -IgnoreReboot -AcceptAll -Install
}

Function Start-SealImage {
    #region Setup seal script
    $Dest = "$Target\Seal"
    If (!(Test-Path $Dest)) { New-Item -Path $Dest -ItemType Directory }
    $url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/scripts/rds/New-RdsTask.ps1"
    Start-BitsTransfer -Source $url -Destination "$Dest\$(Split-Path $url -Leaf)"
    & "$Dest\$(Split-Path $url -Leaf)"
}
#endregion

#region Script logic
# Start logging
Start-Transcript -Path $Log -Append

# If local path for script doesn't exist, create it
If (!(Test-Path $Target)) { New-Item -Path $Target -Type Directory -Force }

# Block the master image from registering with Azure AD; Enable autoWorkplaceJoin after the VMs are provisioned via GPO.
Set-ItemProperty -Path HKLM:\Software\Policies\Microsoft\Windows\WorkplaceJoin -Name autoWorkplaceJoin -Value 0 -Force

# Install required modules
Install-Modules

# Run tasks
Switch ( $Task ) {
    'RegionalSettings' { Set-RegionalSettings }
    'Roles' { Set-Roles }
    'CoreApps' { Install-CoreApps }
    'LobApps' { Install-LobApps }
    'Customisations' { Set-Customisations }
    'WindowsUpdates' { Install-WindowsUpdates }
    'SealImage' { Start-SealImage }
    Default { Write-Warning "No task specified." }
}

# Stop Logging
Stop-Transcript

# Replace clear text passwords in the log file
(Get-Content $Log).replace($Pass, "") | Set-Content $Log
#endregion
