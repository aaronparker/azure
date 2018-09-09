$filename = "VDAServerSetup_7.18.exe"
$url = "http:\\MYURL.COM\"
$UnattendedArgs  = "/quiet /optimize /components vda /controllers 'mycontroller.domain.com' /enable_remote_assistance /enable_hdx_ports /enable_real_time_transport /virtualmachine /noreboot /noresume /logpath 'C:\Windows\Temp\VDA' /masterimage"
$filepath = "$($env:SystemRoot)\temp\"

if(test-path ("$filepath\$filename"))
{
    Write-host "File already exists.  Resuming install"
    $exit = (Start-Process ("C:\ProgramData\Citrix\XenDesktopSetup\XenDesktopVdaSetup.exe") -Wait -Verbose -Passthru).ExitCode
}
else
{
  Write-Host "Downloading $filename"
  Invoke-WebRequest -Uri ($url + $filename) -OutFile "$filepath\$filename" -Verbose -UseBasicParsing
  write-host "Installing VDA..."
  $exit = (Start-Process ("$filepath\$filename") $UnattendedArgs -Wait -Verbose -Passthru).ExitCode
}

if ($exit -eq 0)
{
    write-host "VDA INSTALL COMPLETED!"
}
elseif ($exit -eq 3)
{
    write-host "REBOOT NEEDED!"
}
elseif ($exit -eq 1)
{
    #dump log
    get-content "C:\Windows\Temp\VDA\Citrix\XenDesktop Installer\XenDesktop Installation.log"
    throw "Install FAILED! Check Log"
}