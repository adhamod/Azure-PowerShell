<#

.NAME
	storageAccount-Deploy
	
.DESCRIPTION 
    Leverages the ARM Template file titled "storageAccount-Template.json" to deploy a Storage Account in Azure.

.PARAMETER subscriptionName
	Name of the subscription in which to deploy the ARM template.

.PARAMETER resourceGroupName
    Name of the resource group in which to deploy the ARM template.

.PARAMETER deploymentName
    Name of the ARM template deployment. This name is only useful for debugging purposes, and can be set to anything.

.PARAMETER location
    The location in which to deploy this storage account.

.PARAMETER templateFilePath
    The path of the ARM template file (e.g. "C:\Users\testuser\Desktop\armtemplate.json"

.PARAMETER storageAccountName
	The name of the storage account to be deployed. Must be globally unique.
	
.PARAMETER storageAccountType
	The type of the storage account to be deployed.

.PARAMETER storageAccountTags
    A hashtable specifying the key-value tags to be associated with this Azure resource.

.NOTES
    AUTHOR: Carlos Patiño
    LASTEDIT: August 2, 2016
#>

param (

    [string]
    $subscriptionName = "Visual Studio Enterprise with MSDN",

    [string]
    $resourceGroupName = "powershellLearning",

    [string]
    $deploymentName = "testDeploymentName",

    [string]
    [ValidateSet("Central US", "East US", "East US 2", "West US", "North Central US", "South Central US", "West Central US", "West US 2")]
    $location = "East US",

    [string]
    $templateFilePath = "C:\Users\carpat\OneDrive - Microsoft\Azure-PowerShell\CharlesSchwab\storageAccount-Template.json",

    [string]
    $storageAccountName = "uniquestorcarlos2434",

    [ValidateSet('Premium_LRS','Standard_GRS','Standard_LRS','Standard_RAGRS','Standard_ZRS')]
    [string]
    $storageAccountType = 'Standard_LRS',

    [hashtable]
    $storageAccountTags = @{"tag1" = "tag3";"tag2" = "tag4"}

)





###################################################
# region: PowerShell and Azure Dependency Checks
###################################################
cls
$ErrorActionPreference = 'Stop'

Write-Host "Checking Dependencies..."

# Checking for Windows PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 4) {
    Write-Host "You need to have Windows PowerShell version 4.0 or above installed." -ForegroundColor Red
    Exit -2
}

# Checking for Azure PowerShell module
$modlist = Get-Module -ListAvailable -Name 'Azure'
if (($modlist -eq $null) -or ($modlist.Version.Major -lt 1) -or ($modlist.Version.Minor -lt 5)){
    Write-Host "Please install the Azure Powershell module, version 1.5.0 (released June 2016) or above." -BackgroundColor Black -ForegroundColor Red
    Write-Host "The standalone MSI file for the latest Azure Powershell versions can be found in the following URL:" -BackgroundColor Black -ForegroundColor Red
    Write-Host "https://github.com/Azure/azure-powershell/releases" -BackgroundColor Black -ForegroundColor Red
    Exit -2
}

# Checking whether user is logged in to Azure
Write-Host Validating Azure Accounts...
try{
    $subscriptionList = Get-AzureRmSubscription | Sort SubscriptionName
}
catch {
    Write-Host "Reauthenticating..."
    Login-AzureRmAccount | Out-Null
    $subscriptionList = Get-AzureRmSubscription | Sort SubscriptionName
}
#end region





###################################################
# region: User input validation
###################################################

Write-Host "Checking parameter inputs..."

# Check that template file path is valid
if (!(Test-Path -Path $templateFilePath)) {
    
    Write-Host "The path for the ARM Template file is not valid. Please verify the path." -BackgroundColor Black -ForegroundColor Red
    Exit -2
}


# Check that selected Azure subscription exists.
$selectedSubscription = $subscriptionList | Where-Object {$_.SubscriptionName -eq $subscriptionName}
if ($selectedSubscription -eq $null) {
    
    Write-Host "Unable to find subscription name $subscriptionName." -BackgroundColor Black -ForegroundColor Red
    Exit -2

} else {

    Select-AzureRmSubscription -SubscriptionName $subscriptionName | Out-Null
}

# Check that selected Resource Group exists in selected subscription.
$selectedResourceGroup = Get-AzureRmResourceGroup | Where-Object {$_.ResourceGroupName -eq $resourceGroupName}
if ($selectedResourceGroup -eq $null) {
    
    Write-Host "Unable to find resouce group $resourceGroupName in subscription $subscriptionName." -BackgroundColor Black -ForegroundColor Red
    Exit -2

}

# Check availability of storage account name
# Name of storage account must be globally unique.
$storageNameAvailability = Get-AzureRmStorageAccountNameAvailability -Name $storageAccountName
if ($storageNameAvailability.NameAvailable -eq $false) {
    
    Write-Host "$($storageNameAvailability.Message)" -BackgroundColor Black -ForegroundColor Red
    Exit -2
}
#end region





###################################################
# region: Deploy ARM Template
###################################################

Write-Host "Deploying ARM Template..."

try{
    New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName `
                                       -Name $deploymentName `
                                       -Mode Incremental `
                                       -TemplateFile $templateFilePath `
                                       -location $location `
                                       -storageAccountName $storageAccountName `
                                       -storageAccountType $storageAccountType `
                                       -storageAccountTags $storageAccountTags `
                                       | Out-Null

    Write-Host "ARM Template deployment $deploymentName finished successfully"

}
catch {
    
    $ErrorMessage = $_.Exception.Message
    

    Write-Host "ARM Template deployment $deploymentName failed with the following error message:" -BackgroundColor Black -ForegroundColor Red
    throw "$ErrorMessage"

}
#end region





###################################################
# region: Create default storage container
###################################################

# ARM Templates do not allow storage containers to be defined
# https://feedback.azure.com/forums/281804-azure-resource-manager/suggestions/9306108-let-me-define-preconfigured-blob-containers-table
# Use PowerShell to create a default container (the 'vhds' container) inside the newly-deployed storage account

# Get the context for the storage account
$pw = Get-AzureRmStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName
$context = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $pw.Value[0] -Protocol Https


# If the container 'vhds' does not already exist, create it
$containerName = 'vhds'
$existingContainer = Get-AzureStorageContainer -Name $containerName -Context $context -ErrorAction SilentlyContinue
if ( !($existingContainer) ){
            
    Write-Host "Creating container vhds in storage account $storageAccountName..."

    # Create new container with its public access permission set to 'Off' (i.e. access to container is Private)
    New-AzureStorageContainer -Name $containerName -Permission Off -Context $context | Out-Null
}

# Cleanup activities to remove sensitive variables from the current PowerShell session
Remove-Variable -Name pw
Remove-Variable -Name context
#end region

Write-Host "Storage account deployment successfully completed."