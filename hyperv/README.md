# Create Hyper-V VMs

Scripts to create local VMs on Hyper-V, configured with a vTPM and Secure Boot etc., required for testing scenarios.

`New-LabVM.ps1` - creates a new lab VM. Provide a VM name with `-Name`, and a ISO file with `-IsoFile` to create the VM and attach the target ISO to it. The new VM will be created with these properties:

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

`Remove-LabVM.ps1` - deletes a target VM. Provide a VM name with `-VMName` - this will completely delete the target VM including the virtual disk.

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
