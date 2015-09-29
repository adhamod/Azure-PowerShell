<#
This script uses an ARM Template to deploy the following resources:
    + 3 Storage Accounts: 
      - 1 for each SQL Server node running on a Windows Server VM
      - 1 for the witness VM running on Windows Server
    + 1 Availability Set for the SQL Nodes
    + 1 Internal Load Balancer for the SQL nodes
    + 3 NICs: 1 for each SQL nodes and 1 for the witness VM
    + 3 VMs: 1 for each SQL node and 1 for the witness

    Prerequisites:
    - The following resources already exist in the target Azure subscription:
        - A resource group
        - A Virtual Network (VNet)
        - A subnet in which to place the three VMs and the 
            Internal Load Balancer (ILB)

    Notes:
    - All 3 VMs share the same Username and Password
    - The script will prompt the user to input the password
    - The SQL nodes are by default running on a Standard_D4 VM size.
    - The Witness is by default running on a Basic_A2 VM size.
    - To change the default VM sizes, edit the ARM template.
    - No further steps have been taken in configuring SQL Server AlwaysOn
#>

Switch-AzureMode AzureResourceManager

##################################
# START OF REQUIRED USER INPUT
##################################

# Location of the ARM template to deploy into Azure
$templatePath = "C:\Users\carpat\OneDrive - Microsoft\Azure-PowerShell\sqlServerAlwaysOn_Template_Test.json"

# Username for SQL and Witness VMs
$vmAdminUsername = "charliebrown"

### SQL Server VMs

# VM prefix name for both SQL nodes
$sqlVmName = "testNode"

# VM static private IP address for SQL Node 1
$sqlVm1IPAddress = "10.255.255.4"

# VM static private IP address for SQL Node 2
$sqlVm2IPAddress = "10.255.255.5"

# VM prefix name for both SQL nodes' NICs
$sqlVmNicName = "testSQLNic"

# Internal Load Balancer name for both SQL nodes
$sqlILBName = "testILB"

# Internal Load Balancer private IP Address for both SQL nodes
$sqlILBIPAddress = "10.255.255.6"

# Availability Set Name for both SQL nodes
$sqlAvailabilitySetName = "testAvailabilitySet"

#The image offer of the SQL Server for each SQL node.
$sqlImageOffer = "SQL2012SP2-WS2012R2"

#The SKU of th SQL Server image for each SQL node.
$sqlImageSKU = "Enterprise"

# Storage Account prefix name for both SQL nodes (no upper case letters allowed)
$sqlSAName = "testsqlstor12345"

#Type of storage account for the SQL Server VM disks
$sqlSAType = "Standard_GRS"

### Witness VM

#Name for witness VM
$witVmName = "testWitness"

#VM static private IP address for the Witness VM
$witVmIPAddress = "10.255.255.7"

#NIC name for witness VM
$witVmNicName = "testWitnessNic"

#Storage Account name for witness VM
$witSAName = "testwitstor12345"

#Type of storage account for the Witness VM disk
$witSAType = "Standard_GRS"

### Networks

#Existing Resource Group Name for the Vnet to place SQL nodes and witness VM
$existingRGName = "sqlAlwaysOnRG"

#Existing Subnet Name for SQL nodes and Witness VM
$subnetName = "testSubnetName"

#Existing VNet Name for the subnet of SQL nodes and witness VM
$vnetName = "sqlServerTestVnet"


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
    -sqlVmNicName $sqlVmNicName `
    -sqlILBName $sqlILBName `
    -sqlILBIPAddress $sqlILBIPAddress `
    -sqlAvailabilitySetName $sqlAvailabilitySetName `
    -sqlImageOffer $sqlImageOffer `
    -sqlImageSKU $sqlImageSKU `
    -sqlSAName $sqlSAName `
    -sqlSAType $sqlSAType `
    -witVmName $witVmName `
    -witVmIPAddress $witVmIPAddress `
    -witVmNicName $witVmNicName `
    -witSAName $witSAName `
    -witSAType $witSAType `
    -existingRGName $existingRGName `
    -subnetName $subnetName `
    -vnetName $vnetName