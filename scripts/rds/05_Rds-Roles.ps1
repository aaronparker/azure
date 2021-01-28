<# 
    .SYNOPSIS
        Enable/disable Windows roles and features and set language/regional settings.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Log = "$env:SystemRoot\Logs\PackerImagePrep.log",

    [Parameter(Mandatory = $False)]
    [System.String] $Target = "$env:SystemDrive\Apps"
)

#region Functions
Function Set-Roles {
    Switch -Regex ((Get-WmiObject Win32_OperatingSystem).Caption) {
        "Microsoft Windows Server*" {
            # Add / Remove roles and features (requires reboot at end of deployment)
            $params = @{
                FeatureName   = "Printing-XPSServices-Features", "WindowsMediaPlayer"
                Online        = $true
                NoRestart     = $true
                WarningAction = "Continue"
                ErrorAction   = "Continue"
            }
            Disable-WindowsOptionalFeature @params

            $params = @{
                Name                   = "BitLocker", "EnhancedStorage", "PowerShell-ISE"
                IncludeManagementTools = $true
                WarningAction          = "Continue"
                ErrorAction            = "Continue"
            }
            Uninstall-WindowsFeature @params

            $params = @{
                Name          = "RDS-RD-Server", "Server-Media-Foundation", "Search-Service", "NET-Framework-Core"
                WarningAction = "Continue"
                ErrorAction   = "Continue"
            }
            Install-WindowsFeature @params

            # Enable services
            If ((Get-WindowsFeature -Name "RDS-RD-Server").InstallState -eq "Installed") {
                ForEach ($service in "Audiosrv", "WSearch") {
                    try {
                        $params = @{
                            Name          = $service
                            StartupType   = "Automatic"
                            WarningAction = "Continue"
                            ErrorAction   = "Continue"
                        }
                        Set-Service @params
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
Set-Roles

# Stop Logging
Stop-Transcript -ErrorAction SilentlyContinue
Write-Host "Complete: Rds-Roles.ps1."
