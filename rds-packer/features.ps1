#disable domain firewall
write-host "Disable Domain Firewall"
Set-NetFirewallProfile -Name "Domain" -Enabled False -Verbose

Write-Host "Starting Installation of Windows Roles and Features"
$features = @(
    "RDS-RD-Server",
    "NET-Framework-45-Core",
    #optional
    "Remote-Assistance",
    "Telnet-Client",
    "RSAT-DNS-Server",
    "RSAT-DHCP",
    "RSAT-AD-Tools"
)

foreach ($feature in $features)
{
    write-host "Installing $feature"
    Install-WindowsFeature $feature -Verbose
}
