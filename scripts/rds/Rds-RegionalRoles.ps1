<# 
    .SYNOPSIS
        Enable/disable Windows roles and features and set language/regional settings.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Log = "$env:SystemRoot\Logs\AzureArmCustomDeploy.log",

    [Parameter(Mandatory = $False)]
    [System.String] $Target = "$env:SystemDrive\Apps"
)

#region Functions
Function Set-RegionalSettings ($Path, $Locale) {
    If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" }

    # Select the locale
    Switch ($Locale) {
        "en-US" {
            # United States
            $GeoId = 244
            $Timezone = "Pacific Standard Time"
            $LanguageId = "0409:00000409"
        }
        "en-GB" {
            # Great Britain
            $GeoId = 242
            $Timezone = "GMT Standard Time"
            $LanguageId = "0809:00000809"
        }
        "en-AU" {
            # Australia
            $GeoId = 12
            $Timezone = "AUS Eastern Standard Time"
            $LanguageId = "0c09:00000409"
        }
        Default {
            # Australia
            $GeoId = 12
            $Timezone = "AUS Eastern Standard Time"
            $LanguageId = "0c09:00000409"
        }
    }

    #region Variables
    $languageXml = @"
<gs:GlobalizationServices 
    xmlns:gs="urn:longhornGlobalizationUnattend">
    <!--User List-->
    <gs:UserList>
        <gs:User UserID="Current" CopySettingsToDefaultUserAcct="true" CopySettingsToSystemAcct="true"/>
    </gs:UserList>
    <!-- user locale -->
    <gs:UserLocale>
        <gs:Locale Name="$Locale" SetAsCurrent="true"/>
    </gs:UserLocale>
    <!-- system locale -->
    <gs:SystemLocale Name="$Locale"/>
    <!-- GeoID -->
    <gs:LocationPreferences>
        <gs:GeoID Value="$GeoId"/>
    </gs:LocationPreferences>
    <gs:MUILanguagePreferences>
        <gs:MUILanguage Value="$Locale"/>
        <gs:MUIFallback Value="en-US"/>
    </gs:MUILanguagePreferences>
    <!-- input preferences -->
    <gs:InputPreferences>
        <gs:InputLanguageID Action="add" ID="$LanguageId" Default="true"/>
    </gs:InputPreferences>
</gs:GlobalizationServices>
"@
    #endregion

    # Set regional settings
    Import-Module -Name "International"
    Set-WinSystemLocale -SystemLocale $Locale
    Set-WinUserLanguageList -LanguageList $Locale -Force
    Set-WinHomeLocation -GeoId $GeoId
    Set-TimeZone -Id $Timezone -Verbose
    
    try {
        $OutFile = Join-Path -Path $Path -ChildPath "language.xml"
        Out-File -FilePath $OutFile -InputObject $languageXml -Encoding ascii
    }
    catch {
        Throw "Failed to create language file."
        Break
    }

    try {
        & $env:SystemRoot\System32\control.exe "intl.cpl,,/f:$OutFile"
    }
    catch {
        Throw "Failed to set regional settings."
    }
}

Function Install-LanguageCapability ($Locale) {
    Switch ($Locale) {
        "en-US" {
            # United States
            $Language = "en-US"
        }
        "en-GB" {
            # Great Britain
            $Language = "en-GB"
        }
        "en-AU" {
            # Australia
            $Language = "en-AU", "en-GB"
        }
        Default {
            # Australia
            $Language = "en-AU", "en-GB"
        }
    }

    # Install Windows capability packages using Windows Update
    ForEach ($lang in $Language) {
        Write-Verbose -Message "$($MyInvocation.MyCommand): Adding packages for [$lang]."
        $Capabilities = Get-WindowsCapability -Online | Where-Object { $_.Name -like "Language*$lang*" }
        ForEach ($Capability in $Capabilities) {
            try {
                Add-WindowsCapability -Online -Name $Capability.Name -LogLevel 2
            }
            catch {
                Throw "Failed to add capability: $($Capability.Name)."
            }
        }
    }
}

Function Set-Roles {
    Switch -Regex ((Get-WmiObject Win32_OperatingSystem).Caption) {
        "Microsoft Windows Server*" {
            # Add / Remove roles (requires reboot at end of deployment)
            Disable-WindowsOptionalFeature -Online -FeatureName "Printing-XPSServices-Features", "WindowsMediaPlayer" -NoRestart -WarningAction SilentlyContinue
            Uninstall-WindowsFeature -Name BitLocker, EnhancedStorage, PowerShell-ISE
            Add-WindowsFeature -Name RDS-RD-Server, Server-Media-Foundation, 'Search-Service', NET-Framework-Core

            # Enable services
            If ((Get-WindowsFeature -Name "RDS-RD-Server").InstallState -eq "Installed") {
                ForEach ($service in "Audiosrv", "WSearch") {
                    try {
                        Set-Service $service -StartupType "Automatic"
                    }
                    catch {
                        Throw "Failed to set service properties [$service]."
                    }
                }
            } 
            Break
        }
        "Microsoft Windows 10 Enterprise for Virtual Desktops" {
            Break
        }
        "Microsoft Windows 10 Enterprise" {
            Break
        }
        "Microsoft Windows 10*" {
            Break
        }
        Default {
        }
    }
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
If (Test-Path -Path env:Locale) {
    $Locale = $env:Locale
}
Else {
    Write-Output "====== Can't find passed parameter, setting Locale to en-AU."
    $Locale = "en-AU"
}
Set-RegionalSettings -Path $Target -Locale $Locale
Install-LanguageCapability -Locale $Locale
Set-Roles

# Stop Logging
Stop-Transcript -ErrorAction SilentlyContinue
Write-Host "Complete: $($MyInvocation.MyCommand)."
