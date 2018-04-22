<#
  .SYNOPSIS  
    Office ProPlus Click-To-Run Deployment Script example
#>
[CmdletBinding()]
Param()

Process {
    $scriptPath = "."
    if ($PSScriptRoot) {
        $scriptPath = $PSScriptRoot
    }
    else {
        $scriptPath = (Get-Item -Path ".\").FullName
    }

    #Importing all required functions
    . $scriptPath\Generate-ODTConfigurationXML.ps1
    . $scriptPath\Edit-OfficeConfigurationFile.ps1
    . $scriptPath\Install-OfficeClickToRun.ps1

    $targetFilePath = "$env:temp\configuration.xml"
    $SourcePath = $scriptPath
    if ((Validate-UpdateSource -UpdateSource $SourcePath -ShowMissingFiles $false) -eq $false) {
        $SourcePath = $NULL    
    }

    # Generate the ODT configuration file
    Generate-ODTConfigurationXml -Languages AllInUseLanguages -TargetFilePath $targetFilePath | `
        Set-ODTAdd -Version $NULL -Channel SemiAnnual -SourcePath $SourcePath | Out-Null

    Set-ODTProductToAdd -ProductId "O365ProPlusRetail" -TargetFilePath $targetFilePath -ExcludeApps ("Lync", "Groove") | Out-Null

    Install-OfficeClickToRun -TargetFilePath $targetFilePath
}
