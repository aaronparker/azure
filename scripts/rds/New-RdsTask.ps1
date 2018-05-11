<#
    .SYNOPSIS
        Creates a scheduled task to enable folder redirection at user login.
#>
[CmdletBinding()]
Param (
    [Parameter()] $Log = "$env:SystemRoot\Logs\AzureArmCustomDeployTask.log",
    [Parameter()] $Target = "$env:SystemDrive\Apps\Scripts",
    [Parameter()] $Url = "https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/scripts/rds/sealRDS.ps1",
    [Parameter()] $Script = (Split-Path $Url -Leaf),
    [Parameter()] $TaskName = "Seal Image",
    [Parameter()] $Group = "NT AUTHORITY\SYSTEM",
    [Parameter()] $Execute = "powershell.exe",
    [Parameter()] $Arguments = "-File $Target\$Script",
    [Parameter()] $VerbosePreference = "Continue"
)

# Start logging
Start-Transcript -Path $Log

# If local path for script doesn't exist, create it
If (!(Test-Path $Target)) { New-Item -Path $Target -Type Directory -Force }

# Download the script from the source repository; output the VBscript
If (Test-Path "$Target\$Script") { Remove-Item -Path "$Target\$Script" -Force }
Start-BitsTransfer -Source $Url -Destination "$Target\$Script" -Priority Foreground -TransferPolicy Always -ErrorAction SilentlyContinue -ErrorVariable $TransferError

# Get an existing local task if it exists
If ($Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue ) { 

    Write-Verbose "Seal image task exists."
    # If the task Action differs from what we have above, update the values and save the task
    If (!( ($Task.Actions[0].Execute -eq $Execute) -and ($Task.Actions[0].Arguments -eq $Arguments) )) {
        Write-Verbose "Updating scheduled task."
        $Task.Actions[0].Execute = $Execute
        $Task.Actions[0].Arguments = $Arguments
        $Task | Set-ScheduledTask
    }
    Else {
        Write-Verbose "Existing task action is OK, no change required."
    }
}
Else {
    Write-Verbose "Creating seal image scheduled task."
    # Build a new task object
    $action = New-ScheduledTaskAction -Execute $Execute -Argument $Arguments
    # $trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay (New-TimeSpan -Minutes 5)
    $trigger = New-JobTrigger -AtStartup -RandomDelay (New-TimeSpan -Minutes 5)
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -Hidden -DontStopIfGoingOnBatteries -Compatibility Win8
    $principal = New-ScheduledTaskPrincipal -GroupId $Group -RunLevel "Highest"
    $newTask = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal

    # No task object exists, so register the new task
    Register-ScheduledTask -InputObject $newTask -TaskName $TaskName
}

Stop-Transcript
