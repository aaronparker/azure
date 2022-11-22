[CmdletBinding()]
param(
    [Parameter(Mandatory = $True)]
    [System.String] $ResourceGroupName
)

# Test if logged in and get the subscription
If ($Null -eq (Get-AzSubscription)) {
    Write-Host "Connecting to Azure subscription." -ForegroundColor Cyan
    try {
        Connect-AzAccount
        $subscriptions = Get-AzSubscription
    }
    catch {
        Throw "Failed to connect to Azure subscription."
        Break
    }
}
Else {
    $subscriptions = Get-AzSubscription
}

ForEach ($subscription in $subscriptions) {

    # Set current Subscription
    Select-AzSubscription $subscription.SubscriptionID

    # List all Resources within the Subscription
    try {
        $Resources = Get-AzResource -ResourceGroupName $ResourceGroupName
    }
    catch {
        Write-Error "Failed to retrieve Resource Group: $ResourceGroupName."
        Break
    }

    # For each Resource apply the Tag of the Resource Group
    Foreach ($resource in $Resources) {

        # Get resources in the group
        $resourceid = $resource.resourceId
        $Tags = (Get-AzResourceGroup -Name $ResourceGroupName).Tags

        If ($Null -eq $resource.Tags) {
            Write-Host "Applying the following Tags to $($resourceid)" $Tags
            Set-AzResource -ResourceId $resourceid -Tag $Tags -Force
        }
        Else {
            $TagsFinal = @{ }
            $TagsFinal = $Tags
            Foreach ($resourcetag in $resource.Tags.GetEnumerator()) {
                If ($Tags.Keys -inotcontains $resourcetag.Key) {
                    Write-Host "Key doesn't exist in RG Tags adding to Hash Table" $resourcetag
                    $TagsFinal.Add($resourcetag.Key, $resourcetag.Value)
                }
            }
            Write-Host "Applying the following Tags to $($resourceid)" $TagsFinal
            Set-AzResource -ResourceId $resourceid -Tag $TagsFinal -Force
        }
    }
}
