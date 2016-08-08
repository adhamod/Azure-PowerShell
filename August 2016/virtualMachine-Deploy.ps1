<#

.NAME
	virtualMachine-Deploy
	
.DESCRIPTION 
    Creates an ARM template to deploy VMs in an existing VNet and in an existing storage account.

.PARAMETER subscriptionName
	Name of the subscription in which to deploy the ARM template.

.PARAMETER deploymentName
    Name of the ARM template deployment. This name is only useful for debugging purposes, and can be set to anything.

.PARAMETER location
    The location in which to deploy these VMs.

.PAMAMETER vnetResourceGroupName
    The resource group name in which the Virtual Network is located.

.PAMAMETER virtualNetworkName
    The name of the virtual network in which to deploy the VMs.

.PARAMETER subnetName
    The name of the subnet in which to deploy VMs.

.PARAMETER availabilitySetName
    The name of the availability set in which to deploy VMs.

    If an availability set by the selected name does not already exist,
    one will be created.

    If left blank or $null, VMs will NOT be placed in an availability set.

    Note that VMs may only be placed in an availability set at the time of provisioning.

.PARAMETER storageAccountName
    Name of the storage account in which to place the OS disks and data disks of the VMs
    to be provisioned.

    The name of the storage account must be globally unique.

    This script currently assumes that the storage account is in the same resource group
    as the VMs to be provisioned.

.PARAMETER numberDataDisks
    The number of data disks to be provisioned and assigned to each VM. May be set to 0.

    This script currently only provisions standard data disks.

.PARAMETER sizeDataDisksGiB
    The size of the data disks to be provisioned, in gibibyte (GiB)

    May be ignored if no data disks are to be provisioned.

.PARAMETER vmResourceGroupName
    The name of the resource group in which to deploy VMs and their respective NICs.

.PARAMETER virtualMachineBaseName
    Base name of the VMs to be deployed, before indexing.

    Example: if $virtualMachineBaseName = 'testVMName' and the number
    of VMs to be deployed is 3, the names of the VMs to be deployed will be:
    - testVMName01
    - testVMName02
    - testVMName03

    $virtualMachineBaseName must be 13 characters or less to accomodate indexing
    and the maximum VM name of 15 characters, as set by Azure.
    
.PARAMETER numberVmsToDeploy
    The number of identical VMs to deploy.

.PARAMETER publicIPAddress
    If $true, add a public IP address to the NIC of the VM to deploy.
    The public IP address will be dynamically allocated.

.PARAMETER createFromCustomImage
    If $true, the VM will be provisioned from a user-uploaded custom image.
    The VHD holding this custom image will be specified by $osDiskUrl

.PARAMETER osDiskUrl
    The URL of the VHD holding he user-uploaded custom image from which to provision VMs.
    This parameter is only required if $createFromCustomImage = $true.
    The storage account in which this VHD is located must be the same as the storage account
    in which the VM OS disks will be created.

.PARAMETER osName
    Name of the operating system to install on the VM.
    For Windows Server 2012 R2, set value to 'W2K12R2'

.PARAMETER vmSize
    Size of the VM to deploy. E.g. "Standard_A1"
    Use the cmdlet Get-AzureRmVMSize to get the list of VM sizes.

.PARAMETER username
    Name of the user for the local administrator account of the VM.

.PARAMETER password
    Password of the local administrator account of the VM.
    If left blank or $null, a random password will be generated and outputted to the console.

.PARAMETER vmTags
    Tags to be applied to the NICs and VMs to be deployed.

.NOTES
    AUTHOR: Carlos Patiño
    LASTEDIT: August 8, 2016
#>

param (
    
    #######################################
    # Azure and ARM template parameters
    #######################################
    [string] $subscriptionName = "Visual Studio Enterprise with MSDN",
    [string] $deploymentName = "testdeployment5",

    [ValidateSet("Central US", "East US", "East US 2", "West US", "North Central US", "South Central US", "West Central US", "West US 2")]
    [string] $location = "East US 2",


    #######################################
    # Virtual Network parameters
    #######################################
    [string] $vnetResourceGroupName = "powershellLearning",
    [string] $virtualNetworkName = "testVNet1",
    [string] $subnetName = 'SubnetFront',


    #######################################
    # Availability Set parameters
    #######################################
    [Parameter(Mandatory=$false)]
    [string] $availabilitySetName = 'testAvailabilitySet1',
    

    #######################################
    # Disk and storage parameters
    #######################################

    [string] $storageAccountName,
    [int] $numberDataDisks = 0,
    [int] $sizeDataDisksGiB = 100,


    #######################################
    # VM parameters
    #######################################

    [string] $vmResourceGroupName,
    [string] $virtualMachineBaseName = 'vmTestName',
    [int] $numberVmsToDeploy = 2,

    [bool] $createFromCustomImage = $false,

    [Parameter(Mandatory=$false)]
    [string] $osDiskUrl,

    [bool] $publicIPAddress = $false,

    [ValidateSet("W2K12R2", "Centos71")]
    [string] $osName = "W2K12R2",

    [string] $vmSize = "Standard_A1",

    [string] $username = 'AzrRootAdminUser',
    
    [Parameter(Mandatory=$false)]
    [string] $password = $null,

    [hashtable] $vmTags = @{"Department" = "TestDepartment";"Owner" = "TestOwner"}
    
)

###################################################
# region: Initializations
###################################################

# Define the properties of the possible Operating Systems with which to deploy VM.
$osList = @(
#    @{Name = 'Centos66'; Publisher = 'OpenLogic'; Offer = 'CentOS'; Sku = '6.6' },
    @{Name = 'Centos71'; Publisher = 'OpenLogic'; Offer = 'CentOS'; Sku = '7.1'; OSFlavor = 'Linux' },
#    @{Name = 'RHEL72'; Publisher = 'RedHat'; Offer = 'RHEL'; Sku = '7.2'; OSFlavor = 'Linux' },
    @{Name = 'W2K12R2'; Publisher = 'MicrosoftWindowsServer'; Offer = 'WindowsServer'; Sku = '2012-R2-Datacenter'; OSFlavor = 'Windows' }
)

# Define the maximum number of disks in a standard storage account
# Reference: https://azure.microsoft.com/en-us/documentation/articles/storage-scalability-targets/
$maxDisksStorageAccountStandard = 40

# Define the storage account container in which to place all VM disks
$storageContainerName = 'vhds'

# Define the maximum allowable size of an Azure data disk, in GiB
$maxDiskSizeGiB = 1023

# Get the date in which this deployment is being executed, and add it as a Tag
$creation = Get-Date -Format MM-dd-yyyy
$creationDate = $creation.ToString()
$vmTags.Add("CreationDate", $creationDate)

# Define the length of the password to randomly generate if a password for the VM is not selected
$passwordLength = 15

# Define a variable to hold the number 1. All indexes for resource names should start with number 1 (instead of 0)
$offset = 1

# Define the location in which to store the ARM template generated for this Azure resource deployment
$jsonFilePath = Join-Path $PSScriptRoot 'armTemplate.json'

# Define the location in which to store the report generated for this Azure resource deployment
$csvfilepath = Join-Path $PSScriptRoot 'AzureVMReport.csv'

# Define function to randomly generate password
function Generate-Password{
    param($passwordlength)
    $rand = New-Object System.Random
    $NewPassword = ""
    1..$passwordlength | ForEach { $NewPassword = $NewPassword + [char]$rand.next(48,122) }
    return $NewPassword
}
#endregion





###################################################
# region: PowerShell and Azure Dependency Checks
###################################################
cls
$ErrorActionPreference = 'Stop'

Write-Host "Checking Dependencies..."

# Check for the directory in which this script is running.
# Certain files (the ARM template in JSON, and an output CSV file) will be saved in this directory.
if ($PSScriptRoot -eq $null) {
    Write-Host "Please save this script before executing it."
    Exit -2
}

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

# Check that selected Azure subscription exists.
$selectedSubscription = $subscriptionList | Where-Object {$_.SubscriptionName -eq $subscriptionName}
if ($selectedSubscription -eq $null) {
    
    Write-Host "Unable to find subscription name $subscriptionName." -BackgroundColor Black -ForegroundColor Red
    Exit -2

} else {

    Select-AzureRmSubscription -SubscriptionName $subscriptionName | Out-Null
}

# Check that selected VM Resource Group exists in selected subscription.
$vmResourceGroup = Get-AzureRmResourceGroup | Where-Object {$_.ResourceGroupName -eq $vmResourceGroupName}
if ($vmResourceGroup -eq $null) {
    
    Write-Host "Unable to find resouce group $vmResourceGroup in subscription $subscriptionName." -BackgroundColor Black -ForegroundColor Red
    Exit -2

}

# Check that selected Virtual Network Resource Group exists in selected subscription.
$vnetResourceGroup = Get-AzureRmResourceGroup | Where-Object {$_.ResourceGroupName -eq $vnetResourceGroupName}
if ($vnetResourceGroup -eq $null) {
    
    Write-Host "Unable to find resouce group $vnetResourceGroup in subscription $subscriptionName." -BackgroundColor Black -ForegroundColor Red
    Exit -2

}

# Validate that the VNet already exists
$existingVnet = Get-AzureRmVirtualNetwork -ResourceGroupName $vnetResourceGroupName -Name $virtualNetworkName -ErrorAction SilentlyContinue
if ($existingVnet -eq $null) {

    Write-Host "A Virtual Network with the name $virtualNetworkName was not found in resource group $vnetResourceGroupName." -BackgroundColor Black -ForegroundColor Red
    Exit -2
}

# Validate that the subnet already exists
$existingSubnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $existingVnet -ErrorAction SilentlyContinue
if ($existingSubnet -eq $null) {

    Write-Host "A subnet with the name $subnetName was not found in the Virtual Network $virtualNetworkName." -BackgroundColor Black -ForegroundColor Red
    Exit -2
}

# Validate that the storage account already exists
$existingStorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $vmResourceGroupName | Where-Object {$_.StorageAccountName -eq $storageAccountName}
if ($existingStorageAccount -eq $null) {

    Write-Host "A storage account with the name $storageAccountName was not found in the resource group $vmResourceGroupName." -BackgroundColor Black -ForegroundColor Red
    Exit -2
}

# Validate that the storage account is of type 'Standard'
# TODO: Expand code to accomodate for Premium storage accounts
if ($existingStorageAccount.Sku.Tier -ne 'Standard') {

    Write-Host "The storage account with name $storageAccountName is of type $($existingStorageAccount.Sku.Name). This script only supports VM deployments to data disks of Standard tier." -BackgroundColor Black -ForegroundColor Red
    Exit -2
}

# If an availability set is required, AND the availability set already exists, verify that the size of the selected VM can be deployed in the existing availability set
if ($availabilitySetName) {
    $existingAvailabilitySet = Get-AzureRmAvailabilitySet -ResourceGroupName $vmResourceGroupName -AvailabilitySetName $availabilitySetName -ErrorAction SilentlyContinue
    if ($existingAvailabilitySet) {

        # Gets available sizes for virtual machines that you can deploy in the availability set
        $validVmSizes = Get-AzureRmVMSize -ResourceGroupName $vmResourceGroupName -AvailabilitySetName $availabilitySetName

        # Raise an error if the selected VM size is not in the list of allowable VM sizes for this existing availability set
        if ( !($validVmSizes | Where-Object {$_.Name -eq $vmSize} ) ) {
            
            Write-Host "The selected VM size $vmSize cannot be deployed in existing availability set $availabilitySetName." -BackgroundColor Black -ForegroundColor Red
            Exit -2
        }

    }
}

# Check that the length of the VM name is 13 characters of less.
# The maximum absolute length of the VM name is 15 characters - allow the last 2 characters for the VM index (e.g. 'baseVMName01', 'baseVMName02')
if ($virtualMachineBaseName.Length -gt 13) {

    Write-Host "Ensure that the base name of the VM is 13 characters or less." -BackgroundColor Black -ForegroundColor Red
    Write-Host "Since the maximum length of a VM name is 15 characters, this requirements allow for two characters for the indexing of the VM name (e.g. 'baseVMName01', 'baseVMName15')." -BackgroundColor Black -ForegroundColor Red
    Exit -2

}

# Validate that desired data disk size does not exceed limit and that number of requested data disks does not exceed VM size limit
if ($numberDataDisks -gt 0) {
    if ($sizeDataDisksGiB -gt $maxDiskSizeGiB) {

        Write-Host "The selected size for the data disks is $sizeDataDisksGiB. The maximum size of a data disk in Azure is $maxDiskSizeGiB." -BackgroundColor Black -ForegroundColor Red
        Exit -2

    }

    $MaxDataDiskCount = (Get-AzureRmVMSize -Location $location | Where-Object {$_.Name -eq $vmSize}).MaxDataDiskCount
    if ( !($MaxDataDiskCount) ) {

        Write-Host "The selected size for the VM $vmSize is not valid in location $location." -BackgroundColor Black -ForegroundColor Red
        Exit -2
    }

    if ( $numberDataDisks -gt $MaxDataDiskCount ) {
        
        Write-Host "Requested number of data disks: $numberDataDisks. The selected size for the VM $vmSize only supports up to $MaxDataDiskCount data disks." -BackgroundColor Black -ForegroundColor Red
        Exit -2
    }
}


# Validate that the total number of Standard data disks to be deployed does not exceed the maximum number of disks recommended per storage account

# Get the context for the storage account
$pw = Get-AzureRmStorageAccountKey -ResourceGroupName $vmResourceGroupName -Name $storageAccountName
$context = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $pw.Value[0] -Protocol Https

# Get number of VHDs in deployment container
$currentNumberOfStandardDisks = (Get-AzureStorageBlob -Container $storageContainerName -Context $context -ErrorAction SilentlyContinue | Where-Object {$_.Name.EndsWith('vhd')}).Count

# Calculate number of disks to be deployed
if ($numberDataDisks -gt 0) {
    $numStandardDisksToDeploy = (1 + $numberDataDisks) * $numberVmsToDeploy # OS disks plus data disks
} else {
    $numStandardDisksToDeploy = $numberVmsToDeploy # Only the OS disks
}

if ( ($currentNumberOfStandardDisks + $numStandardDisksToDeploy) -gt $maxDisksStorageAccountStandard ) {
    
    Write-Host "You are trying to deploy $numStandardDisksToDeploy disks into a Standard storage account already holding $currentNumberOfStandardDisks." -BackgroundColor Black -ForegroundColor Red
    Write-Host "This would exceed the total number of standard disks that should be deployed in a single storage account ( $maxDisksStorageAccountStandard ). " -BackgroundColor Black -ForegroundColor Red
    Write-Host "Reference: https://azure.microsoft.com/en-us/documentation/articles/storage-scalability-targets/" -BackgroundColor Black -ForegroundColor Red
    Exit -2

}

# Cleanup activities to remove sensitive variables from the current PowerShell session
Remove-Variable -Name pw
Remove-Variable -Name context


# Validate that user selected an allowable OS type
$image = $osList | Where-Object {$_.Name -eq $osName}
if ($image -eq $null) {

    Write-Host "The selected Operating System type $osName is not valid." -BackgroundColor Black -ForegroundColor Red
    Exit -2
}

# If VM is being deployed from a user-uploaded custom image, validate that the VHD containing the generalized image is
# in the same storage account as the storage account in which the VMs disks will be deployed
if ($createFromCustomImage) {

    if( !($osDiskUrl) ) {
        Write-Host "If you are selecting to create a VM from a user-uploaded custom image, please specify the URL for the VHD containing the custom image." -BackgroundColor Black -ForegroundColor Red
        Write-Host "Note that the image VHD must be in the same storage account as the storage account in which the VM disks will be deployed." -BackgroundColor Black -ForegroundColor Red
        Exit -2
    }
    ## TODO
}
#end region






###################################################
# region: Build ARM template
###################################################

Write-Host "Generating ARM template in JSON for VM deployment..."

# ARM template build for basic NICs and VMs
$armTemplate = @{
    '$schema' = "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#"
    contentVersion = "1.0.0.0"
    parameters = @{
        adminPassword = @{
            type = "securestring"
            metadata = @{
                description = "Admin password for VM"
            }
        }
        numberOfInstances = @{
            type = "int"
            defaultValue = 1
            metadata = @{
                description = "Number of VMs to deploy"
            }
        }
    }
    variables = @{
        vnetID = "[resourceId('" + $vnetResourceGroupName + "', 'Microsoft.Network/virtualNetworks','" + $virtualNetworkName + "')]"
        OSstorageID = "[resourceId('" + $vmResourceGroupName + "', 'Microsoft.Storage/storageAccounts','" + $storageAccountName + "')]"
        subnet1Ref = "[concat(variables('vnetID'),'/subnets/" + $subnetName + "')]"
    }
    resources = @(
        @{
            apiVersion = "2015-06-15"
            type = "Microsoft.Network/networkInterfaces"
            name = "[concat('" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), 'nic1')]"
            location = $location
            tags = $vmTags
            copy = @{
                name = "nicLoop"
                count = "[parameters('numberOfInstances')]"
            }
            properties = @{
                ipConfigurations = @(
                    @{
                        name = "ipcon"
                        properties = @{
                            privateIPAllocationMethod = "Dynamic"
                            subnet = @{
                                id = "[variables('subnet1Ref')]"
                            }
                        }
                    }
                )
            }
        },
        @{
            apiVersion = "2015-06-15"
            type = "Microsoft.Compute/virtualMachines"
            name = "[concat('" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'))]"
            location = $location
            tags = $vmTags
            copy = @{
                name = "virtualMachineLoop"
                count = "[parameters('numberOfInstances')]"
            }
            dependsOn = @(
                "[concat('Microsoft.Network/networkInterfaces/', '" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), 'nic1')]"
            )
            properties = @{
                hardwareProfile = @{
                   vmSize = $vmSize
                }
                osProfile = @{
                    computername = "[concat('" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'))]"
                    adminUsername = $username
                    adminPassword = "[parameters('adminPassword')]"
                }
                storageProfile = @{
                    imageReference = @{
                        publisher = $image.Publisher
                        offer = $image.Offer
                        sku = $image.Sku
                        version = "latest"
                    }
                    osDisk = @{
                        name = "[concat('" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), 'osdisk')]"
                        caching = "ReadWrite"
                        createOption = "FromImage"
                        vhd = @{
                            uri = "[concat('http://" + $storageAccountName + ".blob.core.windows.net/vhds/','" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), 'osdisk.vhd')]"
                        }
                    }
                }
                networkProfile = @{
                    networkInterfaces = @(
                        @{
                            id = "[resourceId('Microsoft.Network/networkInterfaces',concat('" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), 'nic1'))]"
                        }
                    )
                }
            }
        }
    )
}

# Ensure that the index to navigate JSON document is accurate
if ($armTemplate.resources[0].type -eq "Microsoft.Compute/virtualMachines"){
    $vmindex = 0
    $nicindex = 1
}
else{
    $vmindex = 1
    $nicindex = 0
}

# Modify storage profile of the VM depending on whether VM is created from a standard gallery image or from a user-uploaded custom image
if ($createFromCustomImage = $true) {

    $armTemplate['resources'][$vmindex]['properties']['storageProfile'] = @{
                            osDisk = @{
                                name = "[concat('" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), 'osdisk')]"
                                osType = $image.OSFlavor
                                caching = "ReadWrite"
                                createOption = "FromImage"
                                image =  @{
                                  uri = $osDiskUrl
                                }
                                vhd = @{
                                  uri = "[concat('http://" + $storageAccountName + ".blob.core.windows.net/vhds/','" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), 'osdisk.vhd')]"
                                }
                            }
    }
                 
} else {

    # Storage Profile if creating VM from gallery (i.e. standard) image
    $armTemplate['resources'][$vmindex]['properties']['storageProfile'] = @{
                    imageReference = @{
                        publisher = $image.Publisher
                        offer = $image.Offer
                        sku = $image.Sku
                        version = "latest"
                    }
                    osDisk = @{
                        name = "[concat('" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), 'osdisk')]"
                        caching = "ReadWrite"
                        createOption = "FromImage"
                        vhd = @{
                            uri = "[concat('http://" + $storageAccountName + ".blob.core.windows.net/vhds/','" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), 'osdisk.vhd')]"
                        }
                    }
    }

}




# Adding public IP address
if ($publicIPAddress -eq $true) {
    Write-Host "Adding public IP address..."

    # Add public IP as a dependency of the NIC
    if ($armTemplate['resources'][$nicindex]['dependsOn'] -eq $null){
        Write-Host "enter first"
        $armTemplate['resources'][$nicindex]['dependsOn'] = @()
    }
    $armTemplate['resources'][$nicindex]['dependsOn'] += "[concat('Microsoft.Network/publicIPAddresses/','" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), 'ip1')]"

    # Associate the public IP address with its respective NIC
    $armTemplate['resources'][$nicindex]['properties']['ipConfigurations'][0]['properties']['publicIPAddress'] = @{
        id = "[resourceId('Microsoft.Network/publicIPAddresses',concat('" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'),'ip1'))]"
    }

    # Add public IP address resource to ARM template
    $armTemplate['resources'] += @{
        apiVersion = "2015-06-15"
        name = "[concat('" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), 'ip1')]"
        type = "Microsoft.Network/publicIPAddresses"
        location = $location
        tags = $vmTags
        properties = @{
            publicIPAllocationMethod = "Dynamic"
        }
        copy = @{
                name = "publicIPLoop"
                count = "[parameters('numberOfInstances')]"
        }
    }
}

# After any possible changes to the indexes after possibly adding IP addresses, recalculate for VM index
if ($armTemplate.resources[0].type -eq "Microsoft.Compute/virtualMachines"){
    $vmindex = 0
}
elseif ($armTemplate.resources[1].type -eq "Microsoft.Compute/virtualMachines"){
    $vmindex = 1
}
else {
    $vmindex = 2
}


# Adding availability set
if ($availabilitySetName -ne $null){
    Write-Host "Adding Availability Set."
    $armTemplate['resources'] += @{ 
        apiVersion = "2015-06-15"
        name = $availabilitySetName
        type = "Microsoft.Compute/availabilitySets"
        location = $location
        tags = $vmTags
        properties = @{ 
            platformUpdateDomainCount = 5
            platformFaultDomainCount = 3
       }
    }

    $armTemplate['resources'][$vmindex]['dependsOn'] += "[concat('Microsoft.Compute/availabilitySets/', '" + $availabilitySetName + "')]"
    $armTemplate['resources'][$vmindex]['properties']['availabilitySet'] = @{  
        id = "[resourceId('Microsoft.Compute/availabilitySets', '" + $availabilitySetName + "')]" 
    }
}

# Adding data disks. Currently these disks are created from scratch (i.e. not from an image)
for ($i = 1; $i -le $numberDataDisks; $i++){
    Write-Host "Adding Data Disk $i"

    # JSON Schema expects the paramater that specifies the size of the data disk to be a string rather than an integer
    $sizeDataDisksGiB = $sizeDataDisksGiB.ToString()
    
    if ($armTemplate['resources'][$vmindex]['properties']['storageprofile']['dataDisks'] -eq $null){
        $armTemplate['resources'][$vmindex]['properties']['storageprofile']['dataDisks'] = @()
    }

    $armTemplate['resources'][$vmindex]['properties']['storageprofile']['dataDisks'] += @{
        name = "[concat('" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), 'datadisk$i')]"
        diskSizeGB = $sizeDataDisksGiB
        lun = $i - 1
        vhd = @{
            uri = "[concat('http://" + $storageAccountName + ".blob.core.windows.net/vhds/','" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), 'datadisk$i.vhd')]"
        }
        createOption = "Empty"
    }
}

# Set output
$armTemplate['outputs'] = @{}
foreach ($i in $offset..$numberVmsToDeploy){
    $outputvmname = $virtualMachineBaseName + $i.ToString("00")
    $outputnicname = $virtualMachineBaseName + $i.ToString("00") + 'nic1'
    $armTemplate['outputs'][$outputvmname] = @{
        type = "object"
        value = "[reference('Microsoft.Compute/virtualMachines/" + $outputvmname + "' , '2015-06-15')]"
    }
    $armTemplate['outputs'][$outputnicname] = @{
        type = "object"
        value = "[reference('Microsoft.Network/networkInterfaces/" + $outputnicname + "', '2015-06-15')]"
    }
}
#end region



###################################################
# region: Deploy ARM Template
###################################################

# Generate password for VM if one wasn't already inputted
if ( !($password) ) {
    $password = Generate-Password -passwordlength $passwordLength
    Write-Host "Password for VM local administrator: $password"
}

Write-Host "Deploying ARM Template..."

# Convert ARM template into JSON format
$json = ConvertTo-Json -InputObject $armTemplate -Depth 99
$json = [regex]::replace($json,'\\u[a-fA-F0-9]{4}',{[char]::ConvertFromUtf32(($args[0].Value -replace '\\u','0x'))})

# Save JSON file
Out-File -FilePath $jsonFilePath -Force -InputObject $json


try{
    New-AzureRmResourceGroupDeployment -ResourceGroupName $vmResourceGroupName `
                                       -Name $deploymentName `
                                       -Mode Incremental `
                                       -TemplateFile $jsonFilePath `
                                       -numberOfInstances $numberVmsToDeploy `
                                       -adminPassword ( ConvertTo-SecureString -String $password -AsPlainText -Force ) `
                                       | Out-Null
                                       

    Write-Host "ARM Template deployment $deploymentName finished successfully."

}
catch {
    
    $ErrorMessage = $_.Exception.Message
    

    Write-Host "ARM Template deployment $deploymentName failed with the following error message:" -BackgroundColor Black -ForegroundColor Red
    throw "$ErrorMessage"

}
#end region