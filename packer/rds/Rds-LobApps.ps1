<# 
    .SYNOPSIS
        Install line-of-business applications.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Log = "$env:SystemRoot\Logs\AzureArmCustomDeploy.log",

    [Parameter(Mandatory = $False)]
    [System.String] $Target = "$env:SystemDrive\Apps",

    [Parameter(Mandatory = $False)]
    [System.String] $BlobStorage = "https://insentrawvdaue.blob.core.windows.net/apps/"
)

#region Functions
Function Set-Repository {
    # Trust the PSGallery for installing modules
    If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
        Write-Verbose "Trusting the repository: PSGallery"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
}

Function Get-AzureBlobItem {
    <#
        .SYNOPSIS
            Returns an array of items and properties from an Azure blog storage URL.

        .DESCRIPTION
            Queries an Azure blog storage URL and returns an array with properties of files in a Container.
            Requires Public access level of anonymous read access to the blob storage container.
            Works with PowerShell Core.
            
        .NOTES
            Author: Aaron Parker
            Twitter: @stealthpuppy

        .PARAMETER Url
            The Azure blob storage container URL. The container must be enabled for anonymous read access.
            The URL must include the List Container request URI. See https://docs.microsoft.com/en-us/rest/api/storageservices/list-containers2 for more information.
        
        .EXAMPLE
            Get-AzureBlobItems -Uri "https://aaronparker.blob.core.windows.net/folder/?comp=list"

            Description:
            Returns the list of files from the supplied URL, with Name, URL, Size and Last Modifed properties for each item.
    #>
    [CmdletBinding(SupportsShouldProcess = $False)]
    [OutputType([System.Management.Automation.PSObject])]
    Param (
        [Parameter(ValueFromPipeline = $True, Mandatory = $True, HelpMessage = "Azure blob storage URL with List Containers request URI '?comp=list'.")]
        [ValidatePattern("^(http|https)://")]
        [System.String] $Uri
    )

    # Get response from Azure blog storage; Convert contents into usable XML, removing extraneous leading characters
    try {
        $iwrParams = @{
            Uri             = $Uri
            UseBasicParsing = $True
            ContentType     = "application/xml"
            ErrorAction     = "Stop"
        }
        $list = Invoke-WebRequest @iwrParams
    }
    catch [System.Net.WebException] {
        Write-Warning -Message ([string]::Format("Error : {0}", $_.Exception.Message))
    }
    catch [System.Exception] {
        Write-Warning -Message "$($MyInvocation.MyCommand): failed to download: $Uri."
        Throw $_.Exception.Message
    }
    If ($Null -ne $list) {
        [System.Xml.XmlDocument] $xml = $list.Content.Substring($list.Content.IndexOf("<?xml", 0))

        # Build an object with file properties to return on the pipeline
        $fileList = New-Object -TypeName System.Collections.ArrayList
        ForEach ($node in (Select-Xml -XPath "//Blobs/Blob" -Xml $xml).Node) {
            $PSObject = [PSCustomObject] @{
                Name         = ($node | Select-Object -ExpandProperty Name)
                Url          = ($node | Select-Object -ExpandProperty Url)
                Size         = ($node | Select-Object -ExpandProperty Size)
                LastModified = ($node | Select-Object -ExpandProperty LastModified)
            }
            $fileList.Add($PSObject) | Out-Null
        }
        If ($Null -ne $fileList) {
            Write-Output -InputObject $fileList
        }
    }
}

Function Install-LobApps ($Path, $BlobStorage) {
    # Get the list of items from blob storage
    try {
        $Items = Get-AzureBlobItems -Uri "$BlobStorage?comp=list"
    }
    catch {
        Write-Host "=========== Failed to retrieve items from: $BlobStorage?comp=list."
    }

    ForEach ($item in $Items) {
        $AppPath = Join-Path -Path $Path -ChildPath $item.Name
        If (!(Test-Path $AppPath)) { New-Item -Path $AppPath -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" }

        Write-Host "=========== Downloading item: $($item.Name)."
        $OutFile = Join-Path -Path $Path -ChildPath (Split-Path -Path $item.Url -Leaf)
        try {
            Invoke-WebRequest -Uri $item.Uri -OutFile $OutFile -UseBasicParsing
        }
        catch {
            Write-Host "=========== Failed to download: $($item.Uri)."
            Break
        }
        Expand-Archive -Path $OutFile -DestinationPath $AppPath -Force

        Write-Host "=========== Installing item: $($item.Name)."
        Push-Location $AppPath
        . .\Install.ps1
        Pop-Location
    }
}
#endregion

#region Script logic
# Set $VerbosePreference so full details are sent to the log; Make Invoke-WebRequest faster
$VerbosePreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Start logging
Start-Transcript -Path $Log
If (!(Test-Path $Target)) { New-Item -Path $Target -Type Directory -Force -ErrorAction SilentlyContinue }

# Set TLS to 1.2; Create target folder
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
If (!(Test-Path $Target)) { New-Item -Path $Target -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" }

# Run tasks
Install-LobApps -Path $Target

# Stop Logging
Stop-Transcript
Write-Host "Complete: $($MyInvocation.MyCommand)."
#endregion
