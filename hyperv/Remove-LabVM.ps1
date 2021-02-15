<# 
    .SYNOPSIS
        Creates a new VM on the local Hyper-V host
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $True)]
    [System.String] $VMName
)

# Error action preference
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Retrieve the target VM
try {
    $VM = Get-VM -Name $VMName
}
catch {
    Throw $_
    Break
}

If ($Null -ne $VM) {
    If ($VM.State -ne [Microsoft.HyperV.PowerShell.VMState]::Off) {
        Stop-VM -VM $VM -TurnOff -Force
    }
    If ((Get-VMSnapshot -VM $VM | Measure-Object).Count -gt 0) {
        Remove-VMSnapshot -VM $VM

        # wait until Hyper-V has processed all checkpoints
        $all = {
            param($arr, $predicate)
            ($arr | Where-Object { -not (& $predicate) } | Measure-Object).Count -eq 0
        }
        while ($true) {
            try {
                if (& $all (Get-VHD -VMId $VM.Id) { [string]::IsNullOrWhiteSpace($_.ParentPath) }) {
                    break;
                }
            }
            catch { }
            Start-Sleep -Milliseconds 250
        }
    }

    # Delete hard drives
    Get-VHD -VMId $VM.Id | ForEach-Object Path | Remove-Item
    
    # finally delete the vm
    Remove-VM -VM $VM -Force
}
