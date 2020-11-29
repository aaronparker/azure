<# 
    .SYNOPSIS
        Set language/regional settings.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Log = "$env:SystemRoot\Logs\PackerImagePrep.log",

    [Parameter(Mandatory = $False)]
    [System.String] $Target = "$env:SystemDrive\Apps"
)

#region Functions
Function Set-RegionSettings ($Path, $Locale) {
    If (!(Test-Path $Path)) { New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" }

    # Select the locale
    Switch ($Locale) {
        "en-US" {
            # United States
            $GeoId = 244
            $Timezone = "Pacific Standard Time"
            $LanguageId = "0409:00000409"
            $Language = "en-US"
        }
        "en-GB" {
            # Great Britain
            $GeoId = 242
            $Timezone = "GMT Standard Time"
            $LanguageId = "0809:00000809"
            $Language = "en-GB"
        }
        "en-AU" {
            # Australia
            $GeoId = 12
            $Timezone = "AUS Eastern Standard Time"
            $LanguageId = "0c09:00000409"
            $Language = "en-AU"
        }
        Default {
            # Australia
            $GeoId = 12
            $Timezone = "AUS Eastern Standard Time"
            $LanguageId = "0c09:00000409"
            $Language = "en-AU"
        }
    }

    #region Variables
    $languageXML = Join-Path -Path "$env:SystemRoot\Setup\Scripts" -ChildPath "language.xml"
    $languageXmlContent = @"
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

    $languagePS1 = Join-Path -Path "$env:SystemRoot\Setup\Scripts" -ChildPath "Set-Region.ps1"
    $languagePS1Content = @"
Import-Module -Name "International"
Set-WinSystemLocale -SystemLocale $Locale
Set-WinUserLanguageList -LanguageList $Locale -Force
Set-WinHomeLocation -GeoId $GeoId
Set-TimeZone -Id $Timezone -Verbose
& $env:SystemRoot\System32\control.exe "intl.cpl,,/f:$languageXML"
"@

    $setupCompleteCMD = Join-Path -Path "$env:SystemRoot\Setup\Scripts" -ChildPath "SetupComplete.cmd"
    $setupCompleteContent = @"
$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $languagePS1
"@
    #endregion

    #region Set regional settings
    try {
        Import-Module -Name "International"
        Set-WinSystemLocale -SystemLocale $Locale
        Set-WinHomeLocation -GeoId $GeoId
        Set-TimeZone -Id $Timezone -Verbose

        $LanguageList = Get-WinUserLanguageList
        $LanguageList.Add($Language)
        Set-WinUserLanguageList $LanguageList -Force
    }
    catch {
        Throw "Failed to set locale to: $Locale."
    }

    # Run language.xml
    try {
        $OutFile = Join-Path -Path $Path -ChildPath "language.xml"
        Out-File -FilePath $OutFile -InputObject $languageXmlContent -Encoding "utf8"
    }
    catch {
        Write-Host "Failed to create language file: $OutFile."
        Write-Error -Message $_.Exception.Message
    }

    # Set-Region.ps1
    try {
        & $env:SystemRoot\System32\control.exe "intl.cpl,,/f:$OutFile"
    }
    catch {
        Throw "Failed to set regional settings."
    }
    #endregion

    #region Set SetupComplete.cmd
    try {
        Out-File -FilePath $languageXML -InputObject $languageXmlContent -Encoding "utf8"
    }
    catch {
        Write-Host "Failed to create language file: $languageXML."
        Write-Error -Message $_.Exception.Message
    }

    try {
        Out-File -FilePath $languagePS1 -InputObject $languagePS1Content -Encoding "utf8"
    }
    catch {
        Write-Host "Failed to create set-language script: $languagePS1."
        Write-Error -Message $_.Exception.Message
    }

    ##Disable Language Pack Cleanup##
    Disable-ScheduledTask -TaskPath "\Microsoft\Windows\AppxDeploymentClient\" -TaskName "Pre-staged app cleanup"

    # SetupComplete.CMD
    <#
    try {
        & takeown /f $setupCompleteCMD /a
        Out-File -FilePath $setupCompleteCMD -InputObject $setupCompleteContent -Append
    }
    catch {
        Write-Host "Failed to update set-language script: $setupCompleteCMD."
        Write-Error -Message $_.Exception.Message
    }#>
    #endregion
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
Set-RegionSettings -Path $Target -Locale $Locale
#Install-LanguageCapability -Locale $Locale


# Stop Logging
Stop-Transcript -ErrorAction SilentlyContinue
Write-Host "Complete: Rds-RegionLanguage.ps1."
