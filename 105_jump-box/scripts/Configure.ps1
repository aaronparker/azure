Start-Transcript -Path "$env:SystemRoot\Temp\azureDeploy.log"

<# Disable autoWorkplaceJoin
This setting is important to block the master image from registering with Azure AD.
This needs to be coupled with the GPO to enable autoWorkplaceJoin after the VMs are provisioned to whatever worker OU exists.
#>
Set-ItemProperty -Path HKLM:\Software\Policies\Microsoft\Windows\WorkplaceJoin -Name autoWorkplaceJoin -Value 0

Stop-Transript
