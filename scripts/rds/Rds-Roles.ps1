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
Set-Roles


# Stop Logging
Stop-Transcript -ErrorAction SilentlyContinue
Write-Host "Complete: Rds-Roles.ps1."
