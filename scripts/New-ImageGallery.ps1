
$resourceGroup = Get-AzResourceGroup -Name "rg-Images-AustraliaEast"
$params = @{
    GalleryName       = "sig$($Tags.Function)"
    ResourceGroupName = $resourceGroup.ResourceGroupName
    Location          = $resourceGroup.Location
    Tag               = $Tags
    Description       = "Shared Image Gallery for Windows 10 and Windows 10 multi-session Windows Virtual Desktop images"
}
$gallery = New-AzGallery @params


$gallery = New-AzGallery `
    -GalleryName "sig$($Tags.Function)" `
    -ResourceGroupName $resourceGroup.ResourceGroupName `
    -Location $resourceGroup.Location `
    -Description "Shared Image Gallery for Windows 10 and Windows 10 multi-session Windows Virtual Desktop images" `
    -Tag $Tags

$imageDefinition = New-AzGalleryImageDefinition `
    -GalleryName $gallery.Name `
    -ResourceGroupName $gallery.ResourceGroupName `
    -Location $gallery.Location `
    -Name 'MicrosoftWindowsDesktop-Windows-10-20h2-ent-wvd' `
    -OsState generalized `
    -OsType Windows `
    -Publisher 'MicrosoftWindowsDesktop' `
    -Offer 'Windows-10' `
    -Sku '20h2-ent-wvd'

