#Requires -Module Az
# Dot source Export-Variables.ps1 first

# Get the target resource group
$ResourceGroup = Get-AzResourceGroup -Name $ResourceGroups.Core.Name

#region Storage account
# Standard storage
$params = @{
    Name              = ("$($ShortOrgName)$($ShortName)$($ShortLocation)").ToLower()
    ResourceGroupName = $ResourceGroup.ResourceGroupName
    Location          = $ResourceGroup.Location
    Kind              = "StorageV2"
    SkuName           = "Standard_LRS"
    AccessTier        = "Hot"
    Tag               = $Tags
}
$storageAccount = New-AzStorageAccount @params

# Premium storage
$params = @{
    Name              = ("$($ShortOrgName)fslogix$($ShortLocation)").ToLower()
    ResourceGroupName = $ResourceGroup.ResourceGroupName
    Location          = $ResourceGroup.Location
    Kind              = "FileStorage"
    SkuName           = "Premium_LRS"
    MinimumTlsVersion = "TLS1_2"
    Tag               = $Tags
}
$storageAccount = New-AzStorageAccount @params
#endregion

# Configure the file shares
ForEach ($item in $FileShares.GetEnumerator()) {
    $params = @{
        Name    = $item.Value.ToLower()
        Context = $storageAccount.Context
    }
    $share = New-AzStorageShare @params
}

# Configure blob storage
ForEach ($item in $BlobContainers.GetEnumerator()) {
    $params = @{
        Name       = $item.Value.ToLower()
        Permission = "Container"
        Context    = $storageAccount.Context
    }
    $share = New-AzStorageContainer @params
}

#region Storage account firewall
ForEach ($item in $Subnets.GetEnumerator()) {

    $params = @{
        Name              = $VirtualNetworkName
        ResourceGroupName = $ResourceGroups.Infrastructure
    }
    $VirtualNetwork = Get-AzVirtualNetwork @params

    $params = @{
        Name            = $item.Value
        AddressPrefix   = $SubnetAddress[$item.Key]
        ServiceEndpoint = "Microsoft.Storage"
    }
    $VirtualNetwork | Set-AzVirtualNetworkSubnetConfig @params | Set-AzVirtualNetwork

    $subnet = $VirtualNetwork | Get-AzVirtualNetworkSubnetConfig -Name $item.Value

    $params = @{
        Name                     = ("$($ShortOrgName)fslogix$($ShortLocation)").ToLower()
        ResourceGroupName        = $ResourceGroups.Infrastructure
        VirtualNetworkResourceId = $subnet.Id
    }
    Add-AzStorageAccountNetworkRule @params
}

# Set default actions to Deny
$params = @{
    Name              = ("$($ShortOrgName)fslogix$($ShortLocation)").ToLower()
    ResourceGroupName = $ResourceGroups.Infrastructure
    DefaultAction     = "Deny"
}
Update-AzStorageAccountNetworkRuleSet @params

$params = @{
    AccountName       = ("$($ShortOrgName)fslogix$($ShortLocation)").ToLower()
    ResourceGroupName = $ResourceGroups.Infrastructure
}
(Get-AzStorageAccountNetworkRuleSet @params).VirtualNetworkRules
#endregion


#region Join to domain
# Register the target storage account with your active directory environment under the target OU (for example: specify the OU with Name as "UserAccounts" or DistinguishedName as "OU=UserAccounts,DC=CONTOSO,DC=COM").
# You can use to this PowerShell cmdlet: Get-ADOrganizationalUnit to find the Name and DistinguishedName of your target OU. If you are using the OU Name, specify it with -OrganizationalUnitName as shown below. If you are using the OU DistinguishedName, you can set it with -OrganizationalUnitDistinguishedName. You can choose to provide one of the two names to specify the target OU.
# You can choose to create the identity that represents the storage account as either a Service Logon Account or Computer Account (default parameter value), depends on the AD permission you have and preference.
# Run Get-Help Join-AzStorageAccountForAuth for more details on this cmdlet.
# If you don't provide the OU name as an input parameter, the AD identity that represents the storage account is created under the root directory.

$params = @{
    ResourceGroupName                   = $ResourceGroups.Infrastructure
    StorageAccountName                  = ("$($ShortOrgName)fslogix$($ShortLocation)").ToLower()
    DomainAccountType                   = "ComputerAccount"
    OrganizationalUnitDistinguishedName = "OU=Services,OU=stealthpuppy,DC=home,DC=stealthpuppy,DC=com"
}
Join-AzStorageAccountForAuth @params

#You can run the Debug-AzStorageAccountAuth cmdlet to conduct a set of basic checks on your AD configuration with the logged on AD user. This cmdlet is supported on AzFilesHybrid v0.1.2+ version. For more details on the checks performed in this cmdlet, see Azure Files Windows troubleshooting guide.
Debug-AzStorageAccountAuth -StorageAccountName $StorageAccountName -ResourceGroupName $ResourceGroups.Infrastructure -Verbose
#endregion


#region Share permissions
#Get the name of the custom role
#Use one of the built-in roles: Storage File Data SMB Share Reader, Storage File Data SMB Share Contributor, Storage File Data SMB Share Elevated Contributor
"Storage File Data SMB Share Elevated Contributor"
"Storage File Data SMB Share Reader"
"Storage File Data SMB Share Contributor"

#Constrain the scope to the target file share
$FileShareContributorRole = Get-AzRoleDefinition "Storage File Data SMB Share Elevated Contributor"
$Upn = "poweruser@home.stealthpuppy.com"
ForEach ($item in $FileShares.GetEnumerator()) {
    $params = @{
        SignInName         = $Upn
        RoleDefinitionName = $FileShareContributorRole.Name
        Scope              = "$($storageAccount.Id)/fileServices/default/fileshares/$($item.Value)"
    }
    New-AzRoleAssignment  @params
}

$FileShareContributorRole = Get-AzRoleDefinition "Storage File Data SMB Share Contributor"
$AzGroup = Get-AzADGroup -SearchString "FSLogix-ProfileContainer"
ForEach ($item in $FileShares.GetEnumerator()) {
    $params = @{
        ObjectId           = $AzGroup.Id
        RoleDefinitionName = $FileShareContributorRole.Name
        Scope              = "$($storageAccount.Id)/fileServices/default/fileshares/$($item.Value)"
    }
    New-AzRoleAssignment  @params
}
#endregion

#region
<#
SET Folder="\\stpyfslogixause.file.core.windows.net\fslogixcontainers\Profile"
SET Folder="\\stpyfslogixause.file.core.windows.net\fslogixcontainers\Office"

md %Folder%
icacls %Folder% /inheritance:d
icacls %Folder% /remove Users
icacls %Folder% /remove "Authenticated Users"
icacls %Folder% /grant Users:(S,RD,AD,X,RA)
icacls %Folder% /grant home\PowerUser:F
#>
#endregion


#region DNS forwarders
# Create a rule set, which defines the forwarding rules
$ruleSet = New-AzDnsForwardingRuleSet -AzureEndpoints StorageAccountEndpoint

# Deploy and configure DNS forwarders
$params = @{
    DnsForwardingRuleSet            = $ruleSet
    VirtualNetworkResourceGroupName = "<virtual-network-resource-group>"
    VirtualNetworkName              = "<virtual-network-name>"
    VirtualNetworkSubnetName        = "<subnet-name>"
}
New-AzDnsForwarder @params
#endregion

# Join storage account to AD
$params = @{
    ResourceGroupName                   = "rg-WindowsVirtualDesktopInfrastructure-AustraliaEast"
    StorageAccountName                  = "stpyfslogixaue"
    DomainAccountType                   = "ComputerAccount"
    Domain                              = "home.stealthpuppy.com"
    OrganizationalUnitDistinguishedName = "OU=Services,OU=stealthpuppy,DC=home,DC=stealthpuppy,DC=com"
    OverwriteExistingADObject           = $True
}
Join-AzStorageAccountForAuth @params

