function Get-AzureBlobItem {
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
            Get-AzureBlobItems -Uri "https://stpyimgbuildaue.blob.core.windows.net/apps/?comp=list"

            Description:
            Returns the list of files from the supplied URL, with Name, URL, Size and Last Modified properties for each item.
    #>
    [CmdletBinding(SupportsShouldProcess = $False)]
    [OutputType([System.Management.Automation.PSObject])]
    param (
        [Parameter(ValueFromPipeline = $True, Mandatory = $True, HelpMessage = "Azure blob storage URL with List Containers request URI '?comp=list'.")]
        [ValidatePattern("^(http|https)://.*\?comp=list?")]
        [ValidateNotNullOrEmpty()]
        [System.String[]] $Uri
    )

    begin {
        # Suppress progress display for faster queries; Set TLS1.2 for Windows PowerShell
        $ProgressPreference = "SilentlyContinue"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }

    process {
        foreach ($item in $Uri) {
            # Get response from Azure blog storage; Convert contents into usable XML, removing extraneous leading characters
            try {
                $params = @{
                    Uri             = $item
                    UseBasicParsing = $True
                    ContentType     = "application/xml"
                    ErrorAction     = "Stop"
                }
                $list = Invoke-WebRequest @params
            }
            catch [System.Exception] {
                throw $_.Exception.Message
            }
            if ($null -ne $list) {
                try {
                    [System.Xml.XmlDocument] $xml = $list.Content.Substring($list.Content.IndexOf("<?xml", 0))
                }
                catch {
                    throw $_
                }

                # Build an object with file properties to return on the pipeline
                foreach ($node in (Select-Xml -XPath "//Blobs/Blob" -Xml $xml).Node) {
                    $PSObject = [PSCustomObject] @{
                        Name         = ($node | Select-Object -ExpandProperty "Name")
                        Url          = ($node | Select-Object -ExpandProperty "Url")
                        Size         = ($node | Select-Object -ExpandProperty "Size")
                        LastModified = ($node | Select-Object -ExpandProperty "LastModified")
                    }
                    Write-Output -InputObject $PSObject
                }
            }
        }
    }

    end { }
}
