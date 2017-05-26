# $Username = ''
# $Password = ''
# $SecurePassword = convertto-securestring -String $Password -AsPlainText -Force
# $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $Username, $SecurePassword
# $RmLogin = Login-AzureRmAccount -Credential $cred

$RmLogin = Login-AzureRmAccount
# $Subscription = Select-AzureRmSubscription -Default -SubscriptionName $RmLogin.Context.Subscription.SubscriptionName -TenantId $RmLogin.Context.Subscription.TenantId
$Subscription = Set-AzureRmContext -SubscriptionName $RmLogin.Context.Subscription.Name -TenantId $RmLogin.Context.Subscription.TenantId
