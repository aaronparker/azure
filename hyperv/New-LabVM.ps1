<# 
    .SYNOPSIS
        Creates a new VM on the local Hyper-V host
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $True)]
    [System.String[]] $Name
)

Begin {}
Process {
    ForEach ($VMName in $Name) {

        # Check whether the VM already exists
        $VM = Get-VM -Name $VMName -ErrorAction "SilentlyContinue"
        If ($Null -eq $VM) {
            #region Get host properties
            $VMSwitch = Get-VMSwitch | Where-Object { $_.SwitchType -eq "External" } | Select-Object -First 1
            If ($Null -eq $VMSwitch) { Write-Error -Message "Unable to determine external network."; Break }
            $VMHost = Get-VMHost
            #endregion

            #region VHDX path
            If (!(Test-Path -Path $VMHost.VirtualHardDiskPath)) { Write-Error -Message "Cannot find virtual hard disk path: $($VMHost.VirtualHardDiskPath)."; Break }
            $NewVHDPath = Join-Path -Path $VMHost.VirtualHardDiskPath  -ChildPath "$VMName.VHDX"
            #endregion

            #region Create the new VM
            If (Test-Path -Path $NewVHDPath) {
                Write-Information -MessageData "Attaching existing virtual hard disk: $NewVHDPath." -InformationAction Continue
                $params = @{
                    Name               = $VMName
                    MemoryStartupBytes = 4GB
                    Generation         = 2
                    VHDPath            = $NewVHDPath
                    SwitchName         = $VMSwitch.Name
                }
            }
            Else {
                $params = @{
                    Name               = $VMName
                    MemoryStartupBytes = 4GB
                    Generation         = 2
                    NewVHDPath         = $NewVHDPath
                    NewVHDSizeBytes    = 127GB
                    SwitchName         = $VMSwitch.Name
                }
            }
            $NewVM = New-VM @params
            #endregion

            If ($Null -ne $NewVM) {
                #region Update VM settings
                $params = @{
                    VM                   = $NewVM
                    AutomaticStartAction = "Nothing"
                    AutomaticStopAction  = "ShutDown"
                    CheckpointType       = "Standard"
                    DynamicMemory        = $True
                    #MemoryMaximumBytes   = ""
                    #MemoryMinimumBytes   = ""
                    #MemoryStartupBytes   = ""
                    Notes                = "Created by New-LabVM.ps1"
                    Passthru             = $True
                    ProcessorCount       = 2
                    #SmartPagingFilePath  = ""
                    #SnapshotFileLocation = ""
                }
                $NewVM = Set-VM @params
                #endregion

                #region Add MDT boot ISO; set DVD as boot device
                $params = @{
                    VM       = $NewVM
                    Path     = "D:\ISOs\InsentraAutomata-LiteTouchPE_x64.iso"
                    Passthru = $True
                }
                $DvdDrive = Add-VMDvdDrive @params
                If ($Null -ne $DvdDrive ) {
                    $params = @{
                        VM              = $NewVM
                        FirstBootDevice = $DvdDrive
                    }
                    Set-VMFirmware @params
                }
                #endregion

                #region Enable TPM
                $HgsGuardian = Get-HgsGuardian -Name UntrustedGuardian
                $KeyProtector = New-HgsKeyProtector -Owner $HgsGuardian -AllowUntrustedRoot
                Set-VMKeyProtector -VM $NewVM -KeyProtector $KeyProtector.RawData
                Enable-VMTPM -VM $NewVM
                #endregion

                Write-Output -InputObject (Get-VM -Name $VMName)
            }
        }
        Else {
            Write-Information -MessageData "Virtual machine already exists: $VMName. Skipping." -InformationAction Continue
        }
    }
}
End {}
