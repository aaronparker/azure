# Create Hyper-V VMs

`VirtualMachineManagement.psm1` includes functions to create local VMs on Hyper-V, configured with a vTPM and Secure Boot etc., required for testing scenarios.Import the functions via the following command which could be added to your [PowerShell profile](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles):

```powershell
Import-Module -Name .\VirtualMachineManagement.psm1
```

`New-LabVM` - creates a new lab VM. Provide a VM name with `-Name`, and a ISO file with `-IsoFile` to create the VM and attach the target ISO to it. The new VM will be created with these properties:

| Property | Value |
|:--|:--|
| Generation | v2 |
| vCPUs | 2 |
| Startup RAM | 4 GB |
| Dynamic RAM | Yes |
| Virtual disk | 127 GB |
| Dynamic disk | Yes |
| vTPM | Yes |
| Secure Boot | Yes |
| Network | Default external network |
| CheckpointType | Standard |
| Automatic Checkpoints | Disabled |
| Automatic Start Action | Do nothing |
| Automatic Stop Action | Do nothing |

Set a path to ISO files used to installing an OS into a VM in the system environment variable 'ISO_PATH'. This will enable automatic tab completion of ISO files in a specified path for the `-IsoFile` parameter.

Set the variable and value via the following command in an elevated PowerShell session, then restart the Terminal/PowerShell session before running New-LabVM:

```powershell
[System.Environment]::SetEnvironmentVariable("ISO_PATH", "E:\ISOs", "Machine")
```

`Remove-LabVM` - deletes a target VM. Provide a VM name with `-VMName` - this will completely delete the target VM including the virtual disk.

## Install Windows 10

Use the [OSDCloud](https://osdcloud.osdeploy.com/) module to install Windows 10 on the target VM and enable Windows Autopilot.

Example commands used to create the OSDCloud ISO:

```powershell
$params = @{
    Name           = "OSD"
    Language       = "en-GB"
    SetAllIntl     = "en-GB"
    SetInputLocale = "en-AU"
}
New-OSDCloudTemplate @params
New-OSDCloudWorkspace -WorkspacePath "E:\OSDCloud"
$params = @{
    CloudDriver      = 'Surface', 'USB', 'WiFi'
    StartOSDCloudGUI = $true
    Brand            = "stealthpuppy"
}
Edit-OSDCloudWinPE @params
New-OSDCloudISO
```

### Export Autopilot Profiles

Export Windows Autopilot profiles from Microsoft Intune with the following commands:

```powershell
Install-Module AzureAD -Force
Install-Module WindowsAutopilotIntune -Force
Install-Module Microsoft.Graph.Intune -Force

Connect-MSGraph

$Path = "C:\Temp"
Foreach ($AutopilotProfile in (Get-AutopilotProfile)) {
    $OutFile = $([System.IO.Path]::Combine($Path, $AutopilotProfile.displayName, "_AutopilotConfigurationFile.json"))
    $AutopilotProfile | ConvertTo-AutopilotConfigurationJSON | Out-File -FilePath $OutFile -Encoding "ASCII"
}
```
