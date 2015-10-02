<#
This script uses an ARM Template to deploy the following resources:
    + 5 Storage Accounts: 
      - 1 for each SQL Server VM
      - 1 for each Domain Controller (DC) server VM
      - 1 for the witness VM 
    + 1 VNet with:
      - 1 Subnet for SQL Server and Witness VMs
      - 1 Subnet for the ILB and the DC Server VMs
    + 2 Availability Sets
      - 1 for the SQL Server VM
      - 1 for the DC server VM
    + 1 Internal Load Balancer (ILB) for the SQL Server nodes with:
      - a Listener configured
    + 5 public IP addresses: 1 for each VM
    + 5 NICs: 1 for each VM
    + 5 VMs:
      - 2 SQL Server running on Windows Server
      - 1 witness VM running on Windows Server
      - 2 DC servers running on Windows `

    Prerequisites:
    - The Azure account has already been connected to PowerShell. If not, run Add-AzureAccount.
    - The following resources already exist in the target Azure subscription:
        - A resource group

    Notes:
    - All 5 VMs share the same Username and Password
    - The script will prompt the user to input the password
    - The SQL nodes are by default running on a Standard_D2 VM size.
    - The Witness and DC Server VMs are by default running on a Basic_A2 VM size.
    - To change the default VM sizes, edit the ARM template.
    - No further steps have been taken in configuring SQL Server AlwaysOn

Author: Carlos Patiño, carpat@microsoft.com
#>

Switch-AzureMode AzureResourceManager

##################################
# START OF REQUIRED USER INPUT
##################################

# Location of the ARM template to deploy into Azure
$templatePath = "C:\Users\carpat\OneDrive - Microsoft\Azure-PowerShell\sqlServerAlwaysOn_Template_withDC.json"

# Username for SQL and Witness VMs
$vmAdminUsername = "charliebrown"

### Networking

#Existing Resource Group Name for the Vnet to place SQL nodes and witness VM
$existingRGName = "sqlAlwaysOnTest2"

#Virtual Network name in which to deploy all resources
$vnetName = "testVNet"

# IP address prefix of the VNet in CIDR notation.
$addressPrefix = "10.0.0.0/16"

# Subnet name for SQL Server and Witness subnet
$sqlSubnetName = "sqlSubnet"

# IP address prefix for the SQL subnet in CIDR notation
$sqlSubnetPrefix = "10.0.1.0/24"

# Subnet name for the domain controller and ILB
$miscSubnetName = "miscSubnet"

# IP address prefix for the Miscellaneous subnet in CIDR notation
$miscSubnetPrefix = "10.0.2.0/24"

### SQL Server VMs

# VM prefix name for both SQL nodes
$sqlVmName = "testNode"

# VM static private IP address for SQL Node 1
# Must be inside SQL subnet
$sqlVm1IPAddress = "10.0.1.4"

# VM static private IP address for SQL Node 2
# Must be inside SQL subnet
$sqlVm2IPAddress = "10.0.1.5"

# Unique public DNS name prefix for SQL Server VMs
$sqlPublicDNSName = "carlossqltest"

# Internal Load Balancer name for both SQL nodes
$sqlILBName = "testILB"

# Internal Load Balancer private IP Address for both SQL nodes
# This address must be inside the Miscellaneous Subnet
$sqlILBIPAddress = "10.0.2.4"

# Availability Set Name for both SQL nodes
$sqlAvailabilitySetName = "sqlAvailabilitySet"

#The image offer of the SQL Server for each SQL node.
$sqlImageOffer = "SQL2012SP2-WS2012R2"

#The SKU of th SQL Server image for each SQL node.
$sqlImageSKU = "Enterprise"

# Storage Account prefix name for both SQL nodes (no upper case letters allowed)
$sqlSAName = "carlossqlstor"

### Witness VM

#Name for witness VM
$witVmName = "testWitness"

#VM static private IP address for the Witness VM
#Must be inside SQL subnet
$witVmIPAddress = "10.0.1.6"

# Unique public DNS name for Witness VM
$witPublicDNSName = "carloswittest"

#Storage Account name for witness VM
$witSAName = "carloswitstor"

### DC server

# Name prefix for DC server VMs
$dcVmName = "testDC"

# VM static private IP address for DC Server 1
# Must be inside Miscellaneous subnet
$dcVm1IPAddress = "10.0.2.7"

# VM static private IP address for DC Server 2
# Must be inside Miscellaneous subnet
$dcVm2IPAddress = "10.0.2.8"

# Unique public DNS name prefix for DC Server VMs
$dcPublicDNSName = "carlospatdctest"

# Availability Set Name for both SQL nodes
$dcAvailabilitySetName = "dcAvailabilitySet"

# Storage Account prefix name for both SQL nodes (no upper case letters allowed)
$dcSAName = "carlosdcstor"


##################################
# END OF REQUIRED USER INPUT
##################################

$deploymentName = "testDeployment1"

# Deploy the ARM Template with user-specified settings
New-AzureResourceGroupDeployment `
    -Name $deploymentName `
    -ResourceGroupName $existingRGName `
    -vmAdminUserName $vmAdminUsername `
    -TemplateFile $templatePath `
    -sqlVmName $sqlVmName `
    -sqlVm1IPAddress $sqlVm1IPAddress `
    -sqlVm2IPAddress $sqlVm2IPAddress `
    -sqlPublicDNSName $sqlPublicDNSName `
    -sqlILBName $sqlILBName `
    -sqlILBIPAddress $sqlILBIPAddress `
    -sqlAvailabilitySetName $sqlAvailabilitySetName `
    -sqlImageOffer $sqlImageOffer `
    -sqlImageSKU $sqlImageSKU `
    -sqlSAName $sqlSAName `
    -witVmName $witVmName `
    -witVmIPAddress $witVmIPAddress `
    -witPublicDNSName $witPublicDNSName `
    -witSAName $witSAName `
    -dcVmName $dcVmName `
    -dcVm1IPAddress $dcVM1IPAddress `
    -dcVm2IPAddress $dcVM2IPAddress `
    -dcPublicDNSName $dcPublicDNSName `
    -dcAvailabilitySetName $dcAvailabilitySetName `
    -dcSAName $dcSAName `
    -existingRGName $existingRGName `
    -vnetName $vnetName `
    -addressPrefix $addressPrefix `
    -sqlSubnetName $sqlSubnetName `
    -sqlSubnetPrefix $sqlSubnetPrefix `
    -miscSubnetName $miscSubnetName `
    -miscSubnetPrefix $miscSubnetPrefix