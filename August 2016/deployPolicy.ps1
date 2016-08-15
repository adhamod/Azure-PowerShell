$ErrorActionPreference = 'Stop'

$path = "C:\Users\carpat\OneDrive - Microsoft\Azure-PowerShell\August 2016\denyPublicIPPolicy.json"
$description = "Policy to deny the creation of further public IP address resources"

$subscription = Get-AzureRmSubscription
$scope = "/subscriptions/$($subscription.SubscriptionId)"

$policy = New-AzureRmPolicyDefinition -Name "denyPublicIPAddress" `
                                      -Description $description `
                                      -Policy $path

Start-Sleep -Seconds 15

New-AzureRmPolicyAssignment -Name "subscriptionAssignment1" `
                            -Scope $scope `
                            -PolicyDefinition $policy