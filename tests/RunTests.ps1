<#
    .SYNOPSIS
        AppVeyor tests script.
#>
#Requires -RunAsAdministrator
#Requires -PSEdition Desktop
[CmdletBinding()]
Param ()

# Setup test environment
Write-Host -ForegroundColor Cyan "`n`tChecking required module versions."
$Modules = @("Pester", "LatestUpdate", "VcRedist")
ForEach ($Module in $Modules) {
    If ([Version]((Find-Module -Name $Module).Version) -gt [Version]((Get-Module -Name $Module | Select-Object -Last 1).Version)) {
        Write-Host -ForegroundColor Cyan "`tInstalling latest $Module module."
        Install-Module -Name $Module -SkipPublisherCheck -Force
    }
    Import-Module -Name $Module -Force
}

# Invoke Pester tests
$res = Invoke-Pester -Path (Resolve-Path -Path $PWD) -OutputFormat NUnitXml -OutputFile (Join-Path -Path (Resolve-Path -Path $PWD) -ChildPath "TestsResults.xml") -PassThru
If ($res.FailedCount -gt 0) { Throw "$($res.FailedCount) tests failed." }