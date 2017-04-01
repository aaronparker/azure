$Username = ''
$Password = ''
$SecurePassword = convertto-securestring -String $Password -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $Username, $SecurePassword

$RmLogin = Login-AzureRmAccount -Credential $cred
$Subscription = Select-AzureRmSubscription -SubscriptionName $RmLogin.Context.Subscription.SubscriptionName -TenantId $RmLogin.Context.Subscription.TenantId
$Subscription