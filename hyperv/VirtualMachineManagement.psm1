using namespace System.Management.Automation
<#
    .SYNOPSIS
    Wrappers for managing virtual machines on Hyper-V.

    Set a path to ISO files used to installing an OS into a VM in the system environment variable 'ISO_PATH'.

    Set the variable and value via the following command, then restart the PowerShell session before running New-LabVM:

    [System.Environment]::SetEnvironmentVariable("ISO_PATH", "E:\ISOs", "Machine")

    .NOTES
    Author: Aaron Parker
    Twitter: @stealthpuppy
#>

function Write-Msg {
    [CmdletBinding()]
    param(
        [System.String[]] $Msg
    )
    process {
        foreach ($String in $Msg) {
            $Message = [HostInformationMessage]@{
                Message         = "[$(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')]"
                ForegroundColor = "Black"
                BackgroundColor = "DarkCyan"
                NoNewline       = $true
            }
            $params = @{
                MessageData       = $Message
                InformationAction = "Continue"
                Tags              = "Microsoft365"
            }
            Write-Information @params
            $params = @{
                MessageData       = " $String"
                InformationAction = "Continue"
                Tags              = "Microsoft365"
            }
            Write-Information @params
        }
    }
}

#region New-LabVM - create a Gen2 VM with Secure Boot, vTPM etc. enabled
function New-LabVM {
    <#
        .SYNOPSIS
            Creates a new VM on the local Hyper-V host
    #>
    [CmdletBinding(SupportsShouldProcess = $false, ConfirmImpact = "Low")]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "NewVM")]
        [Parameter(Mandatory = $true, ParameterSetName = "TemplateVM")]
        [ValidateNotNullOrEmpty()]
        [System.String[]] $Name,

        [Parameter(Mandatory = $false, ParameterSetName = "NewVM")]
        [ValidateScript({ if (Test-Path -Path $_ -PathType "Leaf") { $true } else { throw "Path not found: '$_'" } })]
        [ValidateNotNullOrEmpty()]
        [System.String] $IsoFile = "E:\ISOs\Microsoft\Windows 11\en-us_windows_11_business_editions_version_22h2_updated_sep_2022_x64_dvd_840da535.iso",

        [Parameter(Mandatory = $true, ParameterSetName = "TemplateVM")]
        [ValidateScript({ if (Test-Path -Path $_ -PathType "Leaf") { $true } else { throw "Path not found: '$_'" } })]
        [ValidateNotNullOrEmpty()]
        [System.String] $TemplateDisk,

        [Parameter(Mandatory = $true, ParameterSetName = "NewVM")]
        [Parameter(Mandatory = $true, ParameterSetName = "TemplateVM")]
        [System.Management.Automation.SwitchParameter] $Connect
    )

    process {
        foreach ($VMName in $Name) {

            # Check whether the VM already exists
            $VM = Get-VM -Name $VMName -ErrorAction "SilentlyContinue"
            if ($null -eq $VM) {

                #region Get host properties
                $VMSwitch = Get-VMSwitch | Where-Object { $_.SwitchType -eq "External" } | Select-Object -First 1
                if ($null -eq $VMSwitch) {
                    $VMSwitch = Get-VMSwitch | Select-Object -First 1
                }
                if ($null -eq $VMSwitch) { Write-Error -Message "Unable to determine external network."; break }
                Write-Msg -Msg "Using switch '$($VMSwitch.Name)'"
                $VMHost = Get-VMHost
                #endregion

                #region VHDX path
                if (!(Test-Path -Path $VMHost.VirtualHardDiskPath)) {
                    Write-Error -Message "Cannot find virtual hard disk path: $($VMHost.VirtualHardDiskPath)."
                    break
                }
                $NewVHDPath = Join-Path -Path $VMHost.VirtualHardDiskPath  -ChildPath "$VMName.VHDX"
                Write-Msg -Msg "New VHD path is: '$NewVHDPath'"
                #endregion

                if ($PSBoundParameters.ContainsKey("TemplateDisk")) {
                    Write-Msg -Msg "Copy '$TemplateDisk' to '$NewVHDPath'"
                    $params = @{
                        Path        = $TemplateDisk
                        Destination = $NewVHDPath
                        ErrorAction = "Stop"
                    }
                    Copy-Item @params
                    Write-Msg -Msg "Copy template disk complete."
                }

                #region Create the new VM
                if (Test-Path -Path $NewVHDPath) {
                    Write-Msg -Msg "Attaching existing virtual hard disk: $NewVHDPath."
                    $params = @{
                        Name               = $VMName
                        MemoryStartupBytes = 4GB
                        Generation         = 2
                        VHDPath            = $NewVHDPath
                        SwitchName         = $VMSwitch.Name
                    }
                }
                else {
                    Write-Msg -Msg "Create VM with virtual hard disk: $NewVHDPath."
                    $params = @{
                        Name               = $VMName
                        MemoryStartupBytes = 4GB
                        Generation         = 2
                        NewVHDPath         = $NewVHDPath
                        NewVHDSizeBytes    = 127GB
                        SwitchName         = $VMSwitch.Name
                    }
                }
                Write-Msg -Msg "Create VM: $VMName."
                $NewVM = New-VM @params
                #endregion

                if ($null -ne $NewVM) {
                    #region Update VM settings
                    $params = @{
                        VM                          = $NewVM
                        AutomaticStartAction        = "Nothing"
                        AutomaticStopAction         = "ShutDown"
                        CheckpointType              = "Standard"
                        AutomaticCheckpointsEnabled = $false
                        DynamicMemory               = $true
                        #MemoryMaximumBytes   = ""
                        #MemoryMinimumBytes   = ""
                        #MemoryStartupBytes   = ""
                        Notes                       = "Created by New-LabVM. $IsoFile"
                        PassThru                    = $true
                        ProcessorCount              = 2
                        #SmartPagingFilePath  = ""
                        #SnapshotFileLocation = ""
                    }
                    Write-Msg -Msg "Configure start / stop actions, checkpoint settings."
                    $NewVM = Set-VM @params
                    #endregion

                    #region Add MDT boot ISO; set DVD as boot device
                    if ($PSBoundParameters.ContainsKey("IsoFile")) {
                        if (Test-Path -Path $IsoFile) {
                            $params = @{
                                VM       = $NewVM
                                Path     = $IsoFile
                                PassThru = $true
                            }
                            Write-Msg -Msg "Attach ISO: $IsoFile."
                            $DvdDrive = Add-VMDvdDrive @params
                            if ($null -ne $DvdDrive ) {
                                $params = @{
                                    VM              = $NewVM
                                    FirstBootDevice = $DvdDrive
                                }
                                Write-Msg -Msg "Set DVD as first boot device."
                                Set-VMFirmware @params
                            }
                        }
                        else {
                            Write-Warning -Message "Failed to find ISO: $IsoFile. Cannot add DVD drive to VM."
                        }
                    }
                    #endregion

                    #region Enable vTPM
                    $HgsGuardian = Get-HgsGuardian -Name UntrustedGuardian
                    if ($HgsGuardian) {
                        Write-Msg -Msg "Create key protector."
                        $KeyProtector = New-HgsKeyProtector -Owner $HgsGuardian -AllowUntrustedRoot
                        Set-VMKeyProtector -VM $NewVM -KeyProtector $KeyProtector.RawData
                        Write-Msg -Msg "Enable TPM."
                        Enable-VMTPM -VM $NewVM
                    }
                    else {
                        try {
                            Write-Msg -Msg "Enable TPM."
                            Set-VMKeyProtector -VM $NewVM -NewLocalKeyProtector
                            Enable-VMTPM -VM $NewVM
                        }
                        catch {
                            Write-Warning -Message "Unable to add virtual TPM. Create one VM with a vTPM manually and try again."
                        }
                    }
                    #endregion

                    Write-Output -InputObject (Get-VM -Name $VMName)
                }
            }
            else {
                Write-Msg -Msg "Virtual machine already exists: $VMName. Skipping."
            }

            # Open a connection to the new VM
            if ($PSBoundParameters.Keys.Contains("Connect")) {
                vmconnect localhost $NewVM.Name
            }
        }
    }
}
#endregion

#region Remove-LabVM - remove a VM along with all snapshots and virtual hard disks
function Remove-LabVM {
    <#
    .SYNOPSIS
        Creates a new VM on the local Hyper-V host
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String] $VMName
    )

    begin {
        # Error action preference
        $ErrorActionPreference = "Stop"
        $VerbosePreference = "Continue"
    }

    process {
        # Retrieve the target VM
        try {
            Write-Msg -Msg "Retrieve VM: $VMName."
            $VM = Get-VM -Name $VMName
        }
        catch {
            throw $_
        }

        if ($null -ne $VM) {
            if ($VM.State -ne [Microsoft.HyperV.PowerShell.VMState]::Off) {
                if ($PSCmdlet.ShouldProcess("Stop-VM will shut down the virtual machine `"$($VM.Name)`".", $($VM.Name), "Stop-VM")) {
                    Write-Msg -Msg "Stopping VM: $VMName."
                    Stop-VM -VM $VM -TurnOff -Force
                }
            }
            if ((Get-VMSnapshot -VM $VM | Measure-Object).Count -gt 0) {
                Get-VMSnapshot -VM $VM | ForEach-Object { Write-Msg -Msg "Found snapshot: `"$($_.Name)`"." -InformationAction "Continue" }

                if ($PSCmdlet.ShouldProcess("Remove-VMSnapshot will remove all snapshots.", $($VM.Name), "Remove-VMSnapshot")) {
                    Write-Msg -Msg "Remove all snapshots."
                    Remove-VMSnapshot -VM $VM

                    # wait until Hyper-V has processed all checkpoints
                    $all = {
                        param($arr, $predicate)
            ($arr | Where-Object { -not (& $predicate) } | Measure-Object).Count -eq 0
                    }
                    while ($true) {
                        try {
                            if (& $all (Get-VHD -VMId $VM.Id) { [System.String]::IsNullOrWhiteSpace($_.ParentPath) }) {
                                break
                            }
                        }
                        catch { }
                        Start-Sleep -Milliseconds 250
                    }
                }
            }

            # Delete hard drives
            Get-VHD -VMId $VM.Id | ForEach-Object {
                if ($PSCmdlet.ShouldProcess("Remove-Item will remove virtual hard disk: `"$($_.Path)`".", $($_.Path), "Remove-Item")) {
                    Write-Msg -Msg "Remove virtual hard disk: $($_.Path)."
                    $_.Path | Remove-Item
                }
            }

            # finally delete the vm
            if ($PSCmdlet.ShouldProcess("Remove-VM will remove virtual machine `"$($VM.Name)`".", $($VM.Name), "Remove-VM")) {
                Write-Msg -Msg "Remove VM: $VMName."
                Remove-VM -VM $VM -Force
            }
        }
    }
}
#endregion

#region Populate dynamic parameter set - tab completion for ISO files
if (Test-Path -Path "env:ISO_PATH") {
    try {
        $ScriptBlock = { Get-ChildItem -Path $env:ISO_PATH -Filter "*.iso" -Recurse | `
                Select-Object -ExpandProperty "FullName" | `
                ForEach-Object { "`"$_`"" } }
        Register-ArgumentCompleter -CommandName "New-LabVM" -ParameterName "IsoFile" -ScriptBlock $ScriptBlock
    }
    catch {
        throw $_
    }
}
else {
    Write-Msg -Msg "'ISO_PATH' environment variable not defined. Tab completion for ISO files will not be enabled." -InformationAction "Continue"
}

if (Test-Path -Path "env:TEMPLATE_PATH") {
    try {
        $ScriptBlock = { Get-ChildItem -Path $env:TEMPLATE_PATH -Filter "*.vhdx" -Recurse | Select-Object -ExpandProperty "FullName" | ForEach-Object { "`"$_`"" } }
        Register-ArgumentCompleter -CommandName "New-LabVM" -ParameterName "TemplateDisk" -ScriptBlock $ScriptBlock
    }
    catch {
        throw $_
    }
}
else {
    Write-Msg -Msg "'TEMPLATE_PATH' environment variable not defined. Tab completion for VHDX files will not be enabled." -InformationAction "Continue"
}

# Populate dynamic parameter set - tab completion for existing VM names
try {
    $ScriptBlock = { Get-VM | Select-Object -ExpandProperty "Name" }
    Register-ArgumentCompleter -CommandName "Remove-LabVM" -ParameterName "VMName" -ScriptBlock $ScriptBlock
}
catch {
    throw $_
}
#endregion
