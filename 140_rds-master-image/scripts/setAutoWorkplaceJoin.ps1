<# This disabled autoWorkplaceJoin
This setting is important to block the golden image from registering with Azure AD
when the Active Directory domain is integrated with Azure AD.
This needs to be coupled with the GPO to enable autoWorkplaceJoin after the VMs are provisioned
to whatever worker OU exists.
#>
start-sleep -Seconds 10
Set-ItemProperty -Path HKLM:\Software\Policies\Microsoft\Windows\WorkplaceJoin -Name autoWorkplaceJoin -Value 0
Start-Sleep -Seconds 2