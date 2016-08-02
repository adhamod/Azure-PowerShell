<#

.NAME
	virtualNetwork-Deploy
	
.DESCRIPTION 
    Leverages the ARM Template file titled "virtualNetwork-Template.json" to deploy a Virtual Network in Azure.

    This script also points the Virtual Network to a primary (and optionally a secondary) DNS server.
    Additionally, this script creates any number of user-specified subnets. 
    Optionally, this script also creates a Virtual Network Gateway for ExpressRoute.

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

.PARAMETER subnets
    A hashtable containing the names of the subnets to be created, and their respective address spaces, in CIDR form (e.g. 10.0.0.0/24).
    This parameter is intended to EXCLUDE any subnet to be used for a VNet Gateway.
        The Name of the subnet is subject to the following requirements:
            - Up to 80 characters long. 
            - It must begin with a word character
            - It must end with a word character or with '_'.
            - May contain word characters or '.', '-', '_'.

.PARAMETER createVnetGateway
    Boolean parameter. If true, a Virtual Network Gateway for ExpressRoute will be created using user-specified parameters.

.PARAMETER vnetGatewaySubnetSpace
    The IP address space for the subnet to be used for a Virtual Network Gateway, in CIDR notation (e.g. 192.168.200.0/26).
    This address space block MUST allow for at least 32 IP addresses (i.e. the subnet mask must be /27 or larger [/26, /25, etc.]).
    See: https://azure.microsoft.com/en-us/documentation/articles/expressroute-howto-add-gateway-resource-manager/

    Leave this variable $null if no subnet is to be created for a VNet Gateway

.NOTES
    AUTHOR: Carlos Patiño
    LASTEDIT: August 2, 2016
#>

param (
    
    #######################################
    # Azure and ARM template parameters
    #######################################
    [string] $subscriptionName = "Visual Studio Enterprise with MSDN",
    [string] $resourceGroupName = "powershellLearning",
    

    [ValidateSet("Central US", "East US", "East US 2", "West US", "North Central US", "South Central US", "West Central US", "West US 2")]
    [string]$location = "East US 2",
    
    [string] $deploymentName = "testdeployment3",
    [string]$templateFilePath,

    #######################################
    # Virtual Network parameters
    #######################################
    [string] $virtualNetworkName = "testVNet1",
    [string] $vnetAddressSpaces = "10.2.0.0/16",
    [string] $primaryDnsServer = "192.0.0.0",

    [Parameter(Mandatory=$false)]
    [string] $secondaryDnsServer = "192.0.0.1",

    [hashtable] $subnets = @{"SubnetFront" = "10.2.0.0/24"; "SubnetMiddle" = "10.2.1.0/24"; "SubnetBack" = "10.2.2.0/24"},
    [hashtable] $virtualNetworkTags = @{"test1" = "tag1";"test2" = "tag2"},

    #######################################
    # Virtual Network Gateway parameters
    #######################################

    [bool] $createVnetGateway = $true,
    [string] $vnetGatewaySubnetSpace = "10.2.3.0/27",
    [string] $GatewayName ,
    [string] $GatewayIPName,
    [string] $GatewayIPConfigName,

    [ValidateSet("Basic", "Standard", "HighPerformance")]
    [string] $gatewaySku

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

# Validate that none of the subnets to be created which were specified with a custom name contain the reserved name 'GatewaySubnet'
# Iterate through each subnet to be created
foreach ($subnetRow in $subnets.GetEnumerator()) {
    
    if ($subnetRow.Name -eq "GatewaySubnet") {

        Write-Host "Do not specify the name and address space of the Gateway Subet in the `$subnets parameter." -BackgroundColor Black -ForegroundColor Red
        Write-Host "Instead, please simply specify the IP address space of the desired Gateway Subnet in the parameter `$vnetGatewaySubnetSpace." -BackgroundColor Black -ForegroundColor Red

        Exit -2
    }

}

# Validate that the VNet to be created does not exist yet
$existingVnet = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroupName -Name $virtualNetworkName -ErrorAction SilentlyContinue
if ($existingVnet) {

    Write-Host "A Virtual Network with the name $virtualNetworkName already exists in resource group $resourceGroupName." -BackgroundColor Black -ForegroundColor Red

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
                                       -virtualNetworkName $virtualNetworkName `
                                       -vNetAddressSpaces $vnetAddressSpaces `
                                       -primaryDnsServer $primaryDnsServer `
                                       -virtualNetworkTags $virtualNetworkTags `
                                       | Out-Null
                                       

    Write-Host "ARM Template deployment $deploymentName finished successfully."

}
catch {
    
    $ErrorMessage = $_.Exception.Message
    

    Write-Host "ARM Template deployment $deploymentName failed with the following error message:" -BackgroundColor Black -ForegroundColor Red
    throw "$ErrorMessage"

}
#end region




###################################################
# region: Create subnets and add secondary DNS server
###################################################
# The creation of subnets is significantly more flexible
# (in particular with regards to the number of subnets to be created)
# if performed with PowerShell rather than with ARM templates

Write-Host "Creating subnets in Virtual Network $virtualNetworkName..."

# Get the object of the VNet that was just created
$vNet = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroupName -Name $virtualNetworkName 

# Iterate through each subnet to be created
foreach ($subnetRow in $subnets.GetEnumerator()) {
    
    # Add the subnet to the VNet object
    Add-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vNet `
                                          -Name $subnetRow.Name `
                                          -AddressPrefix $subnetRow.Value `
                                          | Out-Null

}


# If the user has defined a secondary DNS server, add it to VNet config
if ($secondaryDnsServer) {

    Write-Host "Adding secondary DNS server..."
    $vnet.DhcpOptions.DnsServers.Add($secondaryDnsServer);
}

# Save the changes on Azure
Set-AzureRmVirtualNetwork -VirtualNetwork $vNet | Out-Null
#end region




###################################################
# region: Create Virtual Network (VNet) Gateway for ExpressRoute
###################################################
# Following documentation: https://azure.microsoft.com/en-us/documentation/articles/expressroute-howto-add-gateway-resource-manager/

# If the user has selected for a VNet Gateway to be created
if ($createVnetGateway) {

    Write-Host "Creating Virtual Network Gateway, type 'ExpressRoute', and Sku $gatewaySku..."
    Write-Host "This operation may take up to 20 minutes."

    # Get the object of the VNet again
    $vNet = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroupName -Name $virtualNetworkName

    
    # Add a new subnet for the Gateway
    # Note the following restrictions:
    # - The name of the Gateway subnet must be 'GatewaySubnet'
    # - The subnet address space must be /27 or larger (/26, /25, etc.).
    Add-AzureRmVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet -AddressPrefix $vnetGatewaySubnetSpace | Out-Null

    # Save subnet changes to Azure
    Set-AzureRmVirtualNetwork -VirtualNetwork $vnet | Out-Null

    # Get gateway subnet
    $gatewaySubnet = Get-AzureRmVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet

    # Request a public IP address for the gateway
    # The IP address must be dynamically allocated
    $pip = New-AzureRmPublicIpAddress -Name $GatewayIPName -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Dynamic

    # Create the gateway configuration, which specifies public IP and subnet to use
    $GatewayIPConfig = New-AzureRmVirtualNetworkGatewayIpConfig -Name $GatewayIPConfigName -Subnet $gatewaySubnet -PublicIpAddress $pip

    # Create the gateway
    New-AzureRmVirtualNetworkGateway -Name $GatewayName `
                                     -ResourceGroupName $resourceGroupName `
                                     -Location $location `
                                     -IpConfigurations $GatewayIPConfig `
                                     -GatewayType ExpressRoute `
                                     -GatewaySku $gatewaySku
 }
#end region





Write-Host "Virtual Network deployment has completed successfully."
