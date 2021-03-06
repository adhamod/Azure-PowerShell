﻿<#

.NAME
	virtualMachine-Deploy
	
.DESCRIPTION 
    Creates an ARM template to deploy several Virtual Machines (VMs) in an existing VNet and in existing storage account(s).

    This script split the disks of VMs in the same availability set across multiple storage accounts.




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

    If left empty or $null, VMs will NOT be placed in an availability set.

    Note that VMs may ONLY be placed in an availability set at the time of provisioning.

.PARAMETER storageAccountName
    Name of the storage account in which to place the OS disks and data disks of the VMs
    to be provisioned.

    This parameter is ONLY valid IF $availabilitySetName is $null or empty.
    That is, the disks of multiple identical VMs will only be placed in the same
    storage account if the VMs are not going to be part of an availability set.
    In case $availabilitySetName is NOT $null, see description for parameter $storageAccountBaseName

    The name of the storage account must be globally unique.

    This script currently assumes that the storage account is in the same resource group
    as the VMs to be provisioned.

.PARAMETER storageAccountBaseName
    Base name of the storage accounts in which to place OS and data disks of the VMs.

    This parameter is ONLY valid IF $availabilitySetName is set to a value that is NOT $null or empty.
    That is, if VMs will be placed in an availability group, this script will force that VMs'
    disks to be placed in separate storage accounts. The storage account names will be in
    the following format:
    - <storageAccountBaseName><Two Digit Index>

    For example, if $storageAccountBaseName = "teststorageaccount", $numberVmsToDeploy = 3, 
    and $storageAccountStartIndex = 2, the three storage account names to be used will be:
    - teststorageaccount02
    - teststorageaccount03
    - teststorageaccount04

    The name of the storage account(s) must be globally unique.

    This script currently assumes that the storage account(s) are in the same resource group
    as the VMs to be provisioned.

.PARAMETER storageAccountStartIndex
    An integer that describes the first index to use when building the names of storage accounts
    to use for VMs in an availability set. See description for $storageAccountBaseName parameter.
    
.PARAMETER numberDataDisks
    The number of data disks to be provisioned and assigned to each VM. May be set to 0.
    This script currently only provisions standard data disks.

.PARAMETER sizeDataDisksGiB
    The size of the data disks to be provisioned, in gibibyte (GiB)
    May be ignored if no data disks are to be provisioned.



.PARAMETER publicIPAddress
    If $true, add a public IP address to the NIC of the VM to deploy.
    The public IP address will be dynamically allocated.

.PARAMETER staticPrivateIP
    A boolean. If set to $true, the private IP address of the NIC assigned to each VM
    will be set to Static.

    Note that private IP addresses in Azure, even if they are Dynamic, will NOT change
    unless the VM is deallocated.

.PARAMETER useAzureDHCP
    If $staticPrivateIP = $true, and $useAzureDHCPh = $true, the DHCP functionality in Azure will
    dynamically assign private IP addresses, and afterwards the assigned private IP addresses will be
    set to 'Static'.

    If $staticPrivateIP = $true, and $useAzureDHCPh = $false, the DHCP functionality in Azure will not
    be used to assign IP addresses. Instead, the VMs to be deployed will be assigned static IP addresses
    according to the list of IP addresses specified in $listPrivateIPAddresses.

.PARAMETER listPrivateIPAddresses
    If $useAzureDHCP = $false and $staticPrivateIP = $true, $listPrivateIPAddresses is either an array,
    or a path to a CSV file, containing the list of private IP addresses to statically assign to the VMs to
    be deployed.

    If three VMs are to be provisioned (e.g. testVMName01,testVMName02,testVMName03), the IP addresses listed in 
    $listPrivateIPAddresses will be sequentially assigned.




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

.PARAMETER createFromCustomImage
    A boolean. If $true, the VM will be provisioned from a user-uploaded custom image.
    The VHD holding this custom image will be specified by $imageUrl

.PARAMETER imageUrl
    The URL of the VHD holding he user-uploaded custom image from which to provision VMs.
    This parameter is only required if $createFromCustomImage = $true.

    The storage account in which this VHD is located must be the same as the storage account
    in which the VM OS disks will be created. If it is not, this script will begin a copy operation
    to copy the VHD from its original storage account to all target storage accounts.

    E.g. $imageUrl = "https://teststorageaccount.blob.core.windows.net/customimages/vmbaseimage123.vhd"

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
    The supplied password must be between 8-123 characters long and must satisfy at least 3 of password complexity requirements from the following:
        - 1) Contains an uppercase character
        - 2) Contains a lowercase character
        - 3) Contains a numeric digit
        - 4) Contains a special character

.PARAMETER vmTags
    Tags to be applied to the NICs and VMs to be deployed.



.PARAMETER useVmDiagnostics
    A boolean. If $true, the VM extension Microsoft.Azure.Diagnostics.IaaSDiagnostics will be installed
    on the VM using default settings. The same storage account in which the VM is deployed will be used
    as the storage account for the VM extension files.


.PARAMETER useCustomScriptExtension
    A boolean. If $true, the VM extension Microsoft.Compute.CustomScriptExtension (for Windows VMs) or
    the VM extension Microsoft.OSTCExtensions.CustomScriptForLinux (for Linux VMs) will be deployed.

.PARAMETER customScriptExtensionStorageAccountResourceGroup
    The resource group of the storage account in which the scripts to be executed through Custom Script Extension are located.

.PARAMETER customScriptExtensionStorageAccountName
    The name of the storage account in which the scripts to be executed through Custom Script Extension are located.

.PARAMETER customScriptExtensionStorageKey
    The key of the storage account in which the scripts to be executed through Custom Script Extension are located.

    This is an OPTIONAL parameter. If $customScriptExtensionStorageKey is left blank or null, the script will attempt to
    automatically retrieve the storage account key. This operation will only work if 1) the storage account is in the same
    subscription as the subscription in which the VMs are being deployed, and 2) the user running this script has sufficient
    permissions to access the key of the storage account.

.PARAMETER fileUris
    An array of strings, where each string is the URI of a file to be downloaded into the target VMs through Custom Script Extension.

    This parameter does NOT NECESSARILY contain the URIs of the scripts that will be EXECUTED. The files contained in this parameter
    describe only the files that will be DOWNLOADED. The script execution depends on the parameter $commandToExecute.

    Example: $fileUris = @('https://teststorageaccount.blob.core.windows.net/scripts/testScript.ps1',
                           'https://teststorageaccount.blob.core.windows.net/scripts/supportingFile.csv'),

.PARAMETER commandToExecute
    The command to execute through Custom Script Extension.

    Example for a Windows VM: $commandToExecute = 'powershell -ExecutionPolicy Unrestricted -File testScript.ps1 -reboot test'
    In this example, we are executing the script 'testScript.ps1' (which was specified as a file to download in $fileUris).
    We are also passing the value 'test' to the parameter called 'reboot'.
    And we are setting the Execution Policy of the PowerShell session that is going to run the command as 'Unrestricted'

.NOTES
    AUTHOR: Carlos Patiño
    LASTEDIT: August 23, 2016

FUTURE ENHANCEMENTS
- Allow for premium storage disks
- Allow option for Windows VMs to automatically join to a domain
#>

param (
    
    #######################################
    # Azure and ARM template parameters
    #######################################
    [string] $subscriptionName = "Visual Studio Enterprise with MSDN",
    [string] $deploymentName,

    [ValidateSet("Central US", "East US", "East US 2", "West US", "North Central US", "South Central US", "West Central US", "West US 2")]
    [string] $location = "East US 2",


    #######################################
    # Virtual Network parameters
    #######################################
    [string] $vnetResourceGroupName,
    [string] $virtualNetworkName,
    [string] $subnetName,


    #######################################
    # Availability Set, Storage, and Disk parameters
    #######################################
    [string] $availabilitySetName,

    [string] $storageAccountName,

    [string] $storageAccountBaseName,
    [int] $storageAccountStartIndex,

    [int] $numberDataDisks = 0,
    [int] $sizeDataDisksGiB = 100,


    #######################################
    # IP configuration parameters
    #######################################

    [bool] $publicIPAddress = $false,

    [bool] $staticPrivateIP = $false,
    [bool] $useAzureDHCP = $false,
    $listPrivateIPAddresses = "C:\ipaddresses.csv",

    #######################################
    # VM parameters
    #######################################

    [string] $vmResourceGroupName,
    [string] $virtualMachineBaseName,
    [int] $numberVmsToDeploy,

    [bool] $createFromCustomImage = $false,

    [Parameter(Mandatory=$false)]
    [string] $imageUrl,

    [ValidateSet("W2K12R2", "Centos71")]
    [string] $osName = "W2K12R2",

    [string] $vmSize = "Standard_A1",

    [string] $username = 'AzrRootAdminUser',
    [string] $password = $null,

    [hashtable] $vmTags = @{"Department" = "TestDepartment";"Owner" = "TestOwner"},

    #######################################
    # VM diagnostics parameters
    #######################################
    [bool] $useVmDiagnostics = $true,

    #######################################
    # Post-provisioning parameters
    #######################################

    [bool] $useCustomScriptExtension = $false,

    [string] $customScriptExtensionStorageAccountResourceGroup,
    [string] $customScriptExtensionStorageAccountName,

    [Parameter(Mandatory=$false)]
    [string] $customScriptExtensionStorageKey,

    [string[]] $fileUris,

    [string] $commandToExecute
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

# Define the storage account container in which to copy any custom images whose
# original location is not the storage account in which VM disks will be deployed
$imageContainerName = 'customimages'

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
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
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
if (($modlist -eq $null) -or ($modlist.Version.Major -lt 2)){
    Write-Host "Please install the Azure Powershell module, version 2.0.0 (released August 2016) or above." -BackgroundColor Black -ForegroundColor Red
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

# Validate that the storage account already exist(s)
if ( [string]::IsNullOrEmpty($availabilitySetName) ) {

    Write-Host "Attempting to deploy $numberVmsToDeploy VMs that will NOT be part of an availability set."
    Write-Host "Using storage account: $storageAccountName"
    
    # If the VM(s) to be created will NOT be placed in an availability group, all of the VM(s) disk(s) will be placed in the same storage account.
    $existingStorageAccounts = @($null)
    $existingStorageAccounts[0] = Get-AzureRmStorageAccount -ResourceGroupName $vmResourceGroupName | Where-Object {$_.StorageAccountName -eq $storageAccountName}
    if ($existingStorageAccounts[0] -eq $null) {

        Write-Host "A storage account with the name $storageAccountName was not found in the resource group $vmResourceGroupName." -BackgroundColor Black -ForegroundColor Red
        Exit -2
    }
    
} else {

    # If the VM(s) to be created WILL be placed in an availability group, each VMs' disks will be placed in a separate storage account

    Write-Host "Attempting to deploy $numberVmsToDeploy VMs in the availability set $availabilitySetName."
    Write-Host "Using the following storage accounts:"
    $j = $storageAccountStartIndex
    for ($i = 0; $i -lt $numberVmsToDeploy;$i++) {

        # Get the expected storage account name
        $tempStorageAccountName = $storageAccountBaseName + $j.ToString("00")
        $j++

        Write-Host "$tempStorageAccountName"
    }

    # Initialize array to hold all expected storage accounts
    $existingStorageAccounts = @($null)*$numberVmsToDeploy
    
    # Initialize counter for the index of the storage accounts
    $j = $storageAccountStartIndex

    # Loop through each (expected) storage account
    for ($i = 0; $i -lt $numberVmsToDeploy;$i++) {

        # Get the expected storage account name
        $tempStorageAccountName = $storageAccountBaseName + $j.ToString("00")

        # Get the expected storage account and store in array
        $existingStorageAccounts[$i] = Get-AzureRmStorageAccount -ResourceGroupName $vmResourceGroupName | Where-Object {$_.StorageAccountName -eq $tempStorageAccountName}
        
        # Throw an error if the expected storage account does not exist
        if ($existingStorageAccounts[$i] -eq $null) {
            
            Write-Host "A storage account with the name $tempStorageAccountName was not found in the resource group $vmResourceGroupName." -BackgroundColor Black -ForegroundColor Red
            Exit -2
        }

        # Update storage account index counter
        $j++
    }
}

# Validate that the storage account(s) are of type 'Standard'
# TODO: Expand code to accomodate for Premium storage accounts
foreach ($existingStorageAccount in $existingStorageAccounts) {
    if ($existingStorageAccount.Sku.Tier -ne 'Standard') {

        Write-Host "The storage account with name $($existingStorageAccount.StorageAccountName) is of type $($existingStorageAccount.Sku.Name). This script only supports VM deployments to data disks of Standard tier." -BackgroundColor Black -ForegroundColor Red
        Exit -2
    }
}

# If an availability set is required, AND the availability set already exists, verify that the size of the selected VM can be deployed in the existing availability set
if (  !([string]::IsNullOrEmpty($availabilitySetName)) ) {
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
foreach ($existingStorageAccount in $existingStorageAccounts) {
    # Get the context for the storage account
    $pw = Get-AzureRmStorageAccountKey -ResourceGroupName $vmResourceGroupName -Name $existingStorageAccount.StorageAccountName
    $context = New-AzureStorageContext -StorageAccountName $existingStorageAccount.StorageAccountName -StorageAccountKey $pw.Value[0] -Protocol Https

    # Get number of VHDs in deployment container
    $currentNumberOfStandardDisks = (Get-AzureStorageBlob -Container $storageContainerName -Context $context -ErrorAction SilentlyContinue | Where-Object {$_.Name.EndsWith('vhd')}).Count

    # Calculate number of disks to be deployed
    if ([string]::IsNullOrEmpty($availabilitySetName)) {
        
        # Case where the VMs will NOT be placed in an availability set, and therefore all of the VM disks will be placed in the same storage account.
        if ($numberDataDisks -gt 0) {
            $numStandardDisksToDeploy = (1 + $numberDataDisks) * $numberVmsToDeploy # OS disks plus data disks
        } else {
            $numStandardDisksToDeploy = $numberVmsToDeploy # Only the OS disks
        }
    } else {
        
        # Case where the VMs will be placed in an availability set, and therefore each VM will have its disks placed in a separate storage account.
        if ($numberDataDisks -gt 0) {
            $numStandardDisksToDeploy = (1 + $numberDataDisks) # OS disk plus data disks
        } else {
            $numStandardDisksToDeploy = 1 # Only the OS disk
        }
    }

    # Raise warning if disks to be deployed exceed limit
    if ( ($currentNumberOfStandardDisks + $numStandardDisksToDeploy) -gt $maxDisksStorageAccountStandard ) {
    
        Write-Host "You are trying to deploy $numStandardDisksToDeploy disks into the Standard storage account $($existingStorageAccount.StorageAccountName) that is already holding $currentNumberOfStandardDisks disks." -BackgroundColor Black -ForegroundColor Red
        Write-Host "This would exceed the total number of standard disks that should be deployed in a single storage account ( $maxDisksStorageAccountStandard disks). " -BackgroundColor Black -ForegroundColor Red
        Write-Host "Reference: https://azure.microsoft.com/en-us/documentation/articles/storage-scalability-targets/" -BackgroundColor Black -ForegroundColor Red
        Exit -2

    }

    # Cleanup activities to remove sensitive variables from the current PowerShell session
    Remove-Variable -Name pw
    Remove-Variable -Name context
}

# If IP addresses are to be statically assigned, check that the list of IP addresses specified is valid
if (   $staticPrivateIP -and !($useAzureDHCP)   ) {
    
    # If the input parameter is not already an array, assume it is a file path to a CSV containing the list of IP addresses
    if ( !($listPrivateIPAddresses -is [System.Array]) ) {
        
        try{
            # Import list of IP addresses from CSV file
            $ipAddressObjects = Import-Csv -Path $listPrivateIPAddresses

            # Get the header of the CSV column containing the IP addresses
            $csvHeader = (Get-Member -InputObject $ipAddressObjects[0] | Where-Object {$_.MemberType -eq 'NoteProperty'}).Name

            # Modify the $listPrivateIPAddresses array to only contain the IP address as a string
            $listPrivateIPAddresses = @($false) * $ipAddressObjects.Count
            for ($i=0;$i -lt $ipAddressObjects.Count;$i++) {
                    
                $listPrivateIPAddresses[$i] = $ipAddressObjects[$i].$csvHeader
            }

        } catch {

            $ErrorMessage = $_.Exception.Message
            
            Write-Host "The input parameter 'listPrivateIPAddresses' is not of type System.Array." -BackgroundColor Black -ForegroundColor Red
            Write-Host "Assuming it is a string containing a file path to a CSV file, attempting to import CSV file into PowerShell failed with the following error message:" -BackgroundColor Black -ForegroundColor Red
            throw "$ErrorMessage"
        }
    }

    # Precondition: $listPrivateIPAddresses is of type [System.Array]
    $numIPAddresses = ($listPrivateIPAddresses | Measure).Count
    if ( $numIPAddresses -ne $numberVmsToDeploy  ) {
        
        Write-Host "You are attempting to provision $numberVmsToDeploy VMs with statically-assigned private IP addresses." -BackgroundColor Black -ForegroundColor Red
        Write-Host "You have specified $numIPAddresses private IP addresses in the input parameter 'listPrivateIPAddresses', either as an array or as a CSV file." -BackgroundColor Black -ForegroundColor Red
        Write-Host "Ensure that the number of specified private IP addresses matches the number of VMs to deploy." -BackgroundColor Black -ForegroundColor Red
        Exit -2
    }

    Write-Host "Statically assigning the following private IP addresses:"
    $listPrivateIPAddresses

}


# Validate that user selected an allowable OS type
$image = $osList | Where-Object {$_.Name -eq $osName}
if ($image -eq $null) {

    Write-Host "The selected Operating System type $osName is not valid." -BackgroundColor Black -ForegroundColor Red
    Exit -2
}

# If using Custom Script Extension, verify that the storage account is accessible and that the storage account key can be retrieved
if ($useCustomScriptExtension) {

    # If a storage account key was NOT provided, attempt to retrieve the storage key from the account
    if ( [string]::IsNullOrEmpty($customScriptExtensionStorageKey) ) {

        try {
            
            $customScriptExtensionStorageKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $customScriptExtensionStorageAccountResourceGroup `
                                                                             -Name $customScriptExtensionStorageAccountName).Value[0]
        } catch {

            $ErrorMessage = $_.Exception.Message
            
            Write-Host "Failed to get key for storage account in which Custom Script Extension scripts are stored." -BackgroundColor Black -ForegroundColor Red
            Write-Host "If storage account is in a different subscription in which VMs are being deployed, or if RBAC rules limit user's permissions to extract storage key, manually input storage account key as a parameter." -BackgroundColor Black -ForegroundColor Red
            Write-Host "Error message:" -BackgroundColor Black -ForegroundColor Red
            throw "$ErrorMessage"
        }
    } 

    # If a storage account key was provided, check its validity
    else {

        try{
            New-AzureStorageContext -StorageAccountName $customScriptExtensionStorageAccountName `
                                    -StorageAccountKey $customScriptExtensionStorageKey `
                                    | Out-Null
        } catch {
            $ErrorMessage = $_.Exception.Message
            
            Write-Host "Failed to obtain the context of the storage account for Custom Script Extension scripts." -BackgroundColor Black -ForegroundColor Red
            Write-Host "Please verify that the storage account key that was manually included as a parameter is correct." -BackgroundColor Black -ForegroundColor Red
            Write-Host "If no storage account key is specified, this script will attempt to automatically extract the storage account key. The success of this operation would depend on user and subscription permissions." -BackgroundColor Black -ForegroundColor Red
            Write-Host "Error message:" -BackgroundColor Black -ForegroundColor Red
            throw "$ErrorMessage"

        }
    }
}

# If VM is being deployed from a user-uploaded custom image, validate that the VHD containing the generalized image is
# in the same storage account as the storage account in which the VMs disks will be deployed
if ($createFromCustomImage) {

    Write-Host "Ensuring that image VHD is located in the same storage account as the target storage accounts for VM deployment..."

    # Check that user specified a value for the image URL
    if( [string]::IsNullOrEmpty($imageUrl) ) {
        Write-Host "If you are selecting to create a VM from a user-uploaded custom image, please specify the URL for the VHD containing the custom image." -BackgroundColor Black -ForegroundColor Red
        Write-Host "Note that the image VHD must be in the same storage account as the storage account in which the VM disks will be deployed." -BackgroundColor Black -ForegroundColor Red
        Exit -2
    }
    
    # Extract storage account in which VHD is located.
    # Method: extract any string in between "//" and ".blob"
    $imageStorageAccountName = [regex]::Match($imageUrl,"(?<=\/\/)(.*?)(?=\.blob)").Value

    # Extract the name of the VHD in which the image is stored
    # Match everything after the last "/"
    $imageName = [regex]::Match($imageUrl,"(?<=\/)[^/]*$").Value
    
    # Verify that the storage account in which the image is located (1) exists and (2)
    # is accessible using current Azure credentials
    $imageStorageAccount = Get-AzureRmStorageAccount | Where-Object {$_.StorageAccountName -eq $imageStorageAccountName}
    if ($imageStorageAccount -eq $null) {
            
        Write-Host "The URL that you specified for the custom image VHD is: $imageUrl." -BackgroundColor Black -ForegroundColor Red
        Write-Host "The storage account with the name $imageStorageAccountName was not found in subscription $subscriptionName." -BackgroundColor Black -ForegroundColor Red
        Exit -2
    }

    # Get the context of the origin storage account
    $pwImage = Get-AzureRmStorageAccountKey -ResourceGroupName $imageStorageAccount.ResourceGroupName -Name $imageStorageAccount.StorageAccountName
    $contextImage = New-AzureStorageContext -StorageAccountName $imageStorageAccount.StorageAccountName -StorageAccountKey $pwImage.Value[0] -Protocol Https

    # Intialize counter to hold number of copy operations required
    $numberCopyJobs = 0

    # Initialize an array to hold storage account contexts
    $contexts = @()

    # Loop through each storage account to be used
    # For each storage account, check that the image exists in the pre-defined container
    # for images (i.e. $imageContainerName)
    # If it does not exist, start a copy job
    foreach ($existingStorageAccount in $existingStorageAccounts) {
        
        # Get the context of the current storage account
        $pw = Get-AzureRmStorageAccountKey -ResourceGroupName $vmResourceGroupName -Name $existingStorageAccount.StorageAccountName
        $context = New-AzureStorageContext -StorageAccountName $existingStorageAccount.StorageAccountName -StorageAccountKey $pw.Value[0] -Protocol Https

        try{
            # Attempt to get the blob associated with the image VHD in the current storage account
            $imageBlob = Get-AzureStorageBlob -Blob $imageName -Container $imageContainerName -Context $context

            Write-Host "The image VHD $imageName already exists in storage account $($existingStorageAccount.StorageAccountName) and container $imageContainerName."

        } catch {

            ####################
            # If blob is not found, begin copy operation
            ####################

            Write-Host "Starting operation to copy image VHD from origin storage account $($imageStorageAccount.StorageAccountName) to destination storage account $($existingStorageAccount.StorageAccountName)..."

            # Update job counter
            $numberCopyJobs++

            # Store storage account context
            $contexts += $context

            # If the target container does not exist, create it
            $existingContainer = Get-AzureStorageContainer -Name $imageContainerName -Context $context -ErrorAction SilentlyContinue
            if ( !($existingContainer) ){
                New-AzureStorageContainer -Name $imageContainerName -Permission Off -Context $context | Out-Null
            }

            # Start the copy job
            Start-AzureStorageBlobCopy  -Context $contextImage `
                                        -SrcContainer $imageContainerName `
                                        -SrcBlob $imageName `
                                        -DestContext $context `
                                        -DestContainer $imageContainerName `
                                        | Out-Null

        } finally {

            # Regardless of whether image blob is found or not, delete sensitive information from current PowerShell session
            Remove-Variable -Name pw
            Remove-Variable -Name context
        }

    } # end foreach storage account

    # Delete other sensitive information
    Remove-Variable -Name pwImage
    Remove-Variable -Name contextImage

    $runningCount = $numberCopyJobs
    # Logic waiting for the jobs to complete
    while($runningCount -gt 0){
        
        # Reset counter for number of jobs still running
        $runningCount=0 
 
        # Loop through all jobs
        foreach ($i in $offset..$numberCopyJobs){ 

            # Get the status of the job
            # Get the context of the current storage account
            $jobStatus = Get-AzureStorageBlob -Container $imageContainerName -Blob $imageName -Context $contexts[$i-1] `
                                                | Get-AzureStorageBlobCopyState

            if(   $jobStatus.Status -eq "Pending"   ){ 
                # If the copy operation is still pending, increase the counter for number of jobs still running
                $runningCount++ 
            } 
        } 

        Write-Host "Number of copy operations still running: $runningCount. Number of total jobs: $numberCopyJobs."
         
        Start-Sleep -Seconds 30
    }

    # Delete other sensitive information
    Remove-Variable -Name contexts

    Write-Host "All copy operations complete."
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
                    computerName = "[concat('" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'))]"
                    adminUsername = $username
                    adminPassword = "[parameters('adminPassword')]"
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

# Set the private IP allocation method for the VMs' NICs
if (   $staticPrivateIP -and !($useAzureDHCP)   ) {
    
    # Set each IP address as a variable in the JSON template
    for($i = 0;$i -lt $numIPAddresses; $i++) {

        $ipNumber = $i + $offset
        $ipAddressName = "staticIP-$ipNumber"
        $armTemplate['variables'][$ipAddressName] = $listPrivateIPAddresses[$i]
    }

    # Assign the static IP address to the NIC resource, leveraging the ARM template function copyIndex() to assign all
    # IP addresses simultaneously
    $armTemplate['resources'][$nicindex]['properties']['ipConfigurations'][0]['properties']['privateIPAddress'] = "[variables(concat('staticIP-', copyindex($offset)))]"

    # Set IP allocation method to Static
    $armTemplate['resources'][$nicindex]['properties']['ipConfigurations'][0]['properties']['privateIPAllocationMethod'] = 'Static'

} else {

    # Set IP allocation method to Dyamic
    $armTemplate['resources'][$nicindex]['properties']['ipConfigurations'][0]['properties']['privateIPAllocationMethod'] = 'Dynamic'

}

# Modify storage profile of the VM depending on whether VM is created from a standard gallery image or from a user-uploaded custom image
if ($createFromCustomImage) {

    # Modify the location where to find VHD holding image, depending on whether VM deployment is using an availabiliy set
    # (and therefore multiple storage accounts), or no availability set and therefore only one storage account
    if ([string]::IsNullOrEmpty($availabilitySetName)) {

        $newImageUri = "[concat('http://" + $storageAccountName + "','.blob.core.windows.net/','" + $imageContainerName + "','/','" + $imageName + "')]"
             
    } else {

        $newImageUri = "[concat('http://','" + $storageAccountBaseName + "',padLeft(copyindex($storageAccountStartIndex),2,'0'),'.blob.core.windows.net/','" + $imageContainerName + "','/','" + $imageName + "')]"
    }

    $armTemplate['resources'][$vmindex]['properties']['storageProfile'] = @{
                            osDisk = @{
                                name = "[concat('" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), 'osdisk')]"
                                osType = $image.OSFlavor
                                caching = "ReadWrite"
                                createOption = "FromImage"
                                image =  @{
                                  uri = $newImageUri
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
                    }
    }
}

# Modify the location of the OS disk
# If VM(s) will be placed in an availability set, each VMs' OS disks will be placed in a separate storage account
# Otherwise, all VMs OS disks will be placed in the same storage account
if ( [string]::IsNullOrEmpty($availabilitySetName) ) {

    $armTemplate['resources'][$vmindex]['properties']['storageProfile']['osDisk']['vhd'] = @{
                            uri = "[concat('http://" + $storageAccountName + ".blob.core.windows.net/vhds/','" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), 'osdisk.vhd')]"
                        }
} else {

    $armTemplate['resources'][$vmindex]['properties']['storageProfile']['osDisk']['vhd'] = @{
                            uri = "[concat('http://','" + $storageAccountBaseName + "',padLeft(copyindex($storageAccountStartIndex),2,'0'),'.blob.core.windows.net/vhds/','" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), 'osdisk.vhd')]"
                        }
}


# Adding public IP address
if ($publicIPAddress -eq $true) {
    Write-Host "Adding public IP address..."

    # Add public IP as a dependency of the NIC
    if ($armTemplate['resources'][$nicindex]['dependsOn'] -eq $null){
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
if ( !([string]::IsNullOrEmpty($availabilitySetName)) ){
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

    

    # Modify the location of the data disks
    # If VM(s) will be placed in an availability set, each VMs' data disks will be placed in a separate storage account
    # Otherwise, all VMs data disks will be placed in the same storage account
    if ([string]::IsNullOrEmpty($availabilitySetName)) {

        $dataDiskUri = "[concat('http://" + $storageAccountName + ".blob.core.windows.net/vhds/','" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), 'datadisk$i.vhd')]"
             
    } else {

        $dataDiskUri = "[concat('http://','" + $storageAccountBaseName + "',padLeft(copyindex($storageAccountStartIndex),2,'0'),'.blob.core.windows.net/vhds/','" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), 'datadisk$i.vhd')]"
    }

    $armTemplate['resources'][$vmindex]['properties']['storageprofile']['dataDisks'] += @{
        name = "[concat('" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), 'datadisk$i')]"
        diskSizeGB = $sizeDataDisksGiB
        lun = $i - 1
        vhd = @{
            uri = $dataDiskUri
        }
        createOption = "Empty"
    }
}

# Set VM diagnostics extension for each VM, if selected by the user
if ($useVmDiagnostics) {

    Write-Host "Adding VM diagnostics..."
    
    # Modify the location of the diagnostics files
    # If VM(s) will be placed in an availability set, each VMs' data disks will be placed in a separate storage account
    # Otherwise, all VMs diagnostics files will be placed in the same storage account
    if ([string]::IsNullOrEmpty($availabilitySetName)) {

        $storageNameForDiagnostics = $storageAccountName
        $storageNameForDiagnostics2 = "'" + $storageAccountName + "'"
        $storageUri = "[concat('http://" + $storageAccountName + ".blob.core.windows.net')]"
             
    } else {

        $storageNameForDiagnostics = "[concat('" + $storageAccountBaseName + "',padLeft(copyindex($storageAccountStartIndex),2,'0'))]"
        $storageNameForDiagnostics2 = "concat('" + $storageAccountBaseName + "',padLeft(copyindex($storageAccountStartIndex),2,'0'))"
        $storageUri = "[concat('http://','" + $storageAccountBaseName + "',padLeft(copyindex($storageAccountStartIndex),2,'0'),'.blob.core.windows.net')]"
    }

    
    # Define the variables needed for the default VM diagnotics configuration
    # Reference: https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-extensions-diagnostics-template/#diagnostics-configuration-variables
    $vmDiagnosticsVariables = @{
                                    wadlogs = "<WadCfg> <DiagnosticMonitorConfiguration overallQuotaInMB=\""4096\"" xmlns=\""http://schemas.microsoft.com/ServiceHosting/2010/10/DiagnosticsConfiguration\""> <DiagnosticInfrastructureLogs scheduledTransferLogLevelFilter=\""Error\""/> <WindowsEventLog scheduledTransferPeriod=\""PT1M\"" > <DataSource name=\""Application!*[System[(Level = 1 or Level = 2)]]\"" /> <DataSource name=\""Security!*[System[(Level = 1 or Level = 2)]]\"" /> <DataSource name=\""System!*[System[(Level = 1 or Level = 2)]]\"" /></WindowsEventLog>"
                                    wadperfcounters1 = "<PerformanceCounters scheduledTransferPeriod=\""PT1M\""><PerformanceCounterConfiguration counterSpecifier=\""\\Processor(_Total)\\% Processor Time\"" sampleRate=\""PT15S\"" unit=\""Percent\""><annotation displayName=\""CPU utilization\"" locale=\""en-us\""/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier=\""\\Processor(_Total)\\% Privileged Time\"" sampleRate=\""PT15S\"" unit=\""Percent\""><annotation displayName=\""CPU privileged time\"" locale=\""en-us\""/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier=\""\\Processor(_Total)\\% User Time\"" sampleRate=\""PT15S\"" unit=\""Percent\""><annotation displayName=\""CPU user time\"" locale=\""en-us\""/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier=\""\\Processor Information(_Total)\\Processor Frequency\"" sampleRate=\""PT15S\"" unit=\""Count\""><annotation displayName=\""CPU frequency\"" locale=\""en-us\""/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier=\""\\System\\Processes\"" sampleRate=\""PT15S\"" unit=\""Count\""><annotation displayName=\""Processes\"" locale=\""en-us\""/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier=\""\\Process(_Total)\\Thread Count\"" sampleRate=\""PT15S\"" unit=\""Count\""><annotation displayName=\""Threads\"" locale=\""en-us\""/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier=\""\\Process(_Total)\\Handle Count\"" sampleRate=\""PT15S\"" unit=\""Count\""><annotation displayName=\""Handles\"" locale=\""en-us\""/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier=\""\\Memory\\% Committed Bytes In Use\"" sampleRate=\""PT15S\"" unit=\""Percent\""><annotation displayName=\""Memory usage\"" locale=\""en-us\""/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier=\""\\Memory\\Available Bytes\"" sampleRate=\""PT15S\"" unit=\""Bytes\""><annotation displayName=\""Memory available\"" locale=\""en-us\""/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier=\""\\Memory\\Committed Bytes\"" sampleRate=\""PT15S\"" unit=\""Bytes\""><annotation displayName=\""Memory committed\"" locale=\""en-us\""/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier=\""\\Memory\\Commit Limit\"" sampleRate=\""PT15S\"" unit=\""Bytes\""><annotation displayName=\""Memory commit limit\"" locale=\""en-us\""/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier=\""\\PhysicalDisk(_Total)\\% Disk Time\"" sampleRate=\""PT15S\"" unit=\""Percent\""><annotation displayName=\""Disk active time\"" locale=\""en-us\""/></PerformanceCounterConfiguration>"
                                    wadperfcounters2 = "<PerformanceCounterConfiguration counterSpecifier=\""\\PhysicalDisk(_Total)\\% Disk Read Time\"" sampleRate=\""PT15S\"" unit=\""Percent\""><annotation displayName=\""Disk active read time\"" locale=\""en-us\""/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier=\""\\PhysicalDisk(_Total)\\% Disk Write Time\"" sampleRate=\""PT15S\"" unit=\""Percent\""><annotation displayName=\""Disk active write time\"" locale=\""en-us\""/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier=\""\\PhysicalDisk(_Total)\\Disk Transfers/sec\"" sampleRate=\""PT15S\"" unit=\""CountPerSecond\""><annotation displayName=\""Disk operations\"" locale=\""en-us\""/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier=\""\\PhysicalDisk(_Total)\\Disk Reads/sec\"" sampleRate=\""PT15S\"" unit=\""CountPerSecond\""><annotation displayName=\""Disk read operations\"" locale=\""en-us\""/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier=\""\\PhysicalDisk(_Total)\\Disk Writes/sec\"" sampleRate=\""PT15S\"" unit=\""CountPerSecond\""><annotation displayName=\""Disk write operations\"" locale=\""en-us\""/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier=\""\\PhysicalDisk(_Total)\\Disk Bytes/sec\"" sampleRate=\""PT15S\"" unit=\""BytesPerSecond\""><annotation displayName=\""Disk speed\"" locale=\""en-us\""/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier=\""\\PhysicalDisk(_Total)\\Disk Read Bytes/sec\"" sampleRate=\""PT15S\"" unit=\""BytesPerSecond\""><annotation displayName=\""Disk read speed\"" locale=\""en-us\""/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier=\""\\PhysicalDisk(_Total)\\Disk Write Bytes/sec\"" sampleRate=\""PT15S\"" unit=\""BytesPerSecond\""><annotation displayName=\""Disk write speed\"" locale=\""en-us\""/></PerformanceCounterConfiguration><PerformanceCounterConfiguration counterSpecifier=\""\\LogicalDisk(_Total)\\% Free Space\"" sampleRate=\""PT15S\"" unit=\""Percent\""><annotation displayName=\""Disk free space (percentage)\"" locale=\""en-us\""/></PerformanceCounterConfiguration></PerformanceCounters>"
                                    wadcfgxstart = "[concat(variables('wadlogs'), variables('wadperfcounters1'), variables('wadperfcounters2'), '<Metrics resourceId=\""')]"
                                    wadmetricsresourceid = "[concat('/subscriptions/', subscription().subscriptionId, '/resourceGroups/', resourceGroup().name , '/providers/', 'Microsoft.Compute/virtualMachines/')]"
                                    wadcfgxend = "\""><MetricAggregation scheduledTransferPeriod=\""PT1H\""/><MetricAggregation scheduledTransferPeriod=\""PT1M\""/></Metrics></DiagnosticMonitorConfiguration></WadCfg>"
                                }

    # Add variables to ARM template
    foreach ($item in $vmDiagnosticsVariables.GetEnumerator()) {
        
        $armTemplate['variables'].Add($item.Name,$item.Value)
        
    }

    # Adding VM diagnostics
    $armTemplate['resources'] += @{
        name = "[concat('" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), '/','VMDiagnostics')]"
        type = "Microsoft.Compute/virtualMachines/extensions"
        location = $location
        apiVersion = "2015-06-15"
        copy = @{
                name = "diagnosticsLoop"
                count = "[parameters('numberOfInstances')]"
            }
        dependsOn = @(
                "[concat('Microsoft.Compute/virtualMachines/', '" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'))]"
            )
        tags = @{
            displayName = "AzureDiagnostics"
        }
        properties = @{
            publisher = "Microsoft.Azure.Diagnostics"
            type = "IaaSDiagnostics"
            typeHandlerVersion = "1.5"
            autoUpgradeMinorVersion = $true
            settings = @{
                xmlCfg = "[base64(concat(variables('wadcfgxstart'), variables('wadmetricsresourceid'), concat('" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0')), variables('wadcfgxend')))]"
                StorageAccount = $storageNameForDiagnostics
            }
            protectedSettings = @{
                storageAccountName = $storageNameForDiagnostics
                storageAccountKey = "[listKeys(resourceId('Microsoft.Storage/storageAccounts', $storageNameForDiagnostics2), '2016-01-01').keys[0].value]"
                storageAccountEndPoint = "https://core.windows.net"
            }
        }
    }
}

# Adding Custom Script Extension
if ($useCustomScriptExtension) {

    # Deploying multiple instances of Custom Script Extension (CSE) in a single
    # VM will not work if these CSE instances have different names. Therefore, the name
    # of the CSE extension should be kept consistent per VM.
    $extensionName = "CustomScriptExtension"
    
    # Custom Script Extension type is different for Windows vs. Linux VMs
    if ($image.OSFlavor -eq 'Windows'){
        Write-Host "Adding Custom Script Extension for Windows VM..."

        $armTemplate['resources'] += @{
            type = "Microsoft.Compute/virtualMachines/extensions"
            name = "[concat('" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), '/" + $extensionName + "')]"
            apiVersion = "2015-06-15"
            location = $location
            copy = @{
                name = "extension2loop"
                count = "[parameters('numberOfInstances')]"
            }
            dependsOn = @(
                "[concat('Microsoft.Compute/virtualMachines/','" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'))]"
            )
           properties = @{ 
                publisher = "Microsoft.Compute"
                type = "CustomScriptExtension"
                typeHandlerVersion = "1.7"
                autoUpgradeMinorVersion = $true
                settings = @{ 
                    fileUris = $fileUris
                    commandToExecute = $commandToExecute
                }
            protectedSettings = @{ 
                    storageAccountName = $customScriptExtensionStorageAccountName
                    storageAccountKey = $customScriptExtensionStorageKey
                }
            }
        }
    }

    elseif ($image.OSFlavor -eq 'Linux'){
        Write-Host "Adding Custom Script Extension for Linux VM..."

        $armTemplate['resources'] += @{
            type = "Microsoft.Compute/virtualMachines/extensions"
            name = "[concat('" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'), '/" + $extensionName + "')]"
            apiVersion = "2015-06-15"
            location = $location
            copy = @{
                name = "extensionloop"
                count = "[parameters('numberOfInstances')]"
            }
            dependsOn = @( 
                "[concat('Microsoft.Compute/virtualMachines/','" + $virtualMachineBaseName + "', padLeft(copyindex($offset),2,'0'))]"
            )
            properties = @{ 
                publisher = "Microsoft.OSTCExtensions"
                type = "CustomScriptForLinux"
                typeHandlerVersion = "1.3"
                autoUpgradeMinorVersion = $true
                settings = @{ 
                    fileUris = $fileUris
                    commandToExecute = $commandToExecute
                }
                protectedSettings = @{ 
                    storageAccountName = $customScriptExtensionStorageAccountName
                    storageAccountKey = $customScriptExtensionStorageKey
                }
            }
        }
    }
}


# Set output
$armTemplate['outputs'] = @{}
foreach ($i in $offset..$numberVmsToDeploy){
    $outputVmName = $virtualMachineBaseName + $i.ToString("00")
    $outputNicName = $virtualMachineBaseName + $i.ToString("00") + 'nic1'

    $armTemplate['outputs'][$outputVmName] = @{
        type = "object"
        value = "[reference('Microsoft.Compute/virtualMachines/" + $outputVmName + "' , '2015-06-15')]"
    }
    $armTemplate['outputs'][$outputNicName] = @{
        type = "object"
        value = "[reference('Microsoft.Network/networkInterfaces/" + $outputNicName + "', '2015-06-15')]"
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
$json = $json -replace "\\\\\\","\" # Replace all instances of three backward slashes with just one (workaround using the XML config for VM diagnostics resource)

# Save JSON file
Out-File -FilePath $jsonFilePath -Force -InputObject $json


try{
    $deploymentResult = New-AzureRmResourceGroupDeployment -ResourceGroupName $vmResourceGroupName `
                                       -Name $deploymentName `
                                       -Mode Incremental `
                                       -TemplateFile $jsonFilePath `
                                       -numberOfInstances $numberVmsToDeploy `
                                       -adminPassword ( ConvertTo-SecureString -String $password -AsPlainText -Force )
                                       

    Write-Host "ARM Template deployment $deploymentName finished successfully."

}
catch {
    
    $ErrorMessage = $_.Exception.Message
    

    Write-Host "ARM Template deployment $deploymentName failed with the following error message:" -BackgroundColor Black -ForegroundColor Red
    throw "$ErrorMessage"

}

##################
# If selected, after the DHCP server in Azure has automatically assigned the NICs a private IP address, 
# set the allocation method of the NICs' private IP address to static
#
# We want these tasks to be run synchronously to save time.
# Start-Job may NOT be used, because it does not execute within the context of the current 
# PowerShell session and therefore does not have the necessary Azure credentials (i.e. will fail
# by asking the user to run Login-AzureRmAccount)
#
# Instead, we are creating jobs using [PowerShell]::Create(), which creates a new PowerShell instance in the context
# of the current PowerShell session.
##################

# Execute ONLY if static private IP addresses are required AFTER being automatically assigned by DHCP functionality in
# Azure
if ($staticPrivateIP -and $useAzureDHCP) {

    Write-Host "Changing private IP address allocation to Static..."

    # Loop through each NIC to create the job to set private IP addresses to static, and start the job
    foreach ($i in $offset..$numberVmsToDeploy){
        
        # Define the script block that will be executed in each block
        $scriptBlock = { 
            # Define the paratemers to be passed to this script block
            Param($virtualMachineBaseName,$i,$vmResourceGroupName) 

            try{
                # The actual lines of code that set NIC's private IP address to static.
                Import-Module AzureRM.Network
                $nicName = $virtualMachineBaseName + $i.ToString("00") + 'nic1'
                $nic = Get-AzureRmNetworkInterface -ResourceGroupName $vmResourceGroupName -Name $nicName
                $nic.IpConfigurations[0].PrivateIpAllocationMethod = "Static"
                $nic | Set-AzureRmNetworkInterface | Out-Null
            } catch {
                $ErrorMessage = $_.Exception.Message
                Write-Host "Setting the private IP address of a NIC as 'Static' failed with the following message:" -BackgroundColor Black -ForegroundColor Red
                throw "$ErrorMessage"
            }
        } 
        
        # Create a new PowerShell object and store it in a variable
        New-Variable -Name "psSession-$virtualMachineBaseName-$i" -Value ([PowerShell]::Create())

        # Add the script block to the PowerShell session, and add the parameter values
        (Get-Variable -Name "psSession-$virtualMachineBaseName-$i" -ValueOnly).AddScript($scriptBlock).AddArgument($virtualMachineBaseName).AddArgument($i).AddArgument($vmResourceGroupName) | Out-Null

        # Start the execution of the script block in the newly-created PowerShell session, and save its execution in a new variable as job
        New-Variable -Name "job-$virtualMachineBaseName-$i" -Value ((Get-Variable -Name "psSession-$virtualMachineBaseName-$i" -ValueOnly).BeginInvoke())
    }

    # Logic waiting for the jobs to complete
    $jobsRunning=$true 
    while($jobsRunning){
        
        # Reset counter for number of jobs still running
        $runningCount=0 
 
        # Loop through all jobs
        foreach ($i in $offset..$numberVmsToDeploy){ 
            
            if(   !(Get-Variable -Name "job-$virtualMachineBaseName-$i" -ValueOnly).IsCompleted   ){ 
                # If the PowerShell command being executed is not completed, increase the counter for number of jobs still running
                $runningCount++ 
            } 
            else{ 
                # If the PowerShell command has been completed, store the results of the job in the psSession variable, and then 
                # release all resources of the PowerShell object
                $temp = Get-Variable -Name "job-$virtualMachineBaseName-$i" -ValueOnly
                (Get-Variable -Name "psSession-$virtualMachineBaseName-$i" -ValueOnly).EndInvoke($temp)
                (Get-Variable -Name "psSession-$virtualMachineBaseName-$i" -ValueOnly).Dispose()
            } 
        } 
        
        # If there are no more running jobs, set while-loop flap to end
        if ($runningCount -eq 0){ 
            $jobsRunning=$false 
        } 
 
        Start-Sleep -Seconds 5
    }

    # Delete all the variables holding jobs and PowerShell sessions
    foreach ($i in $offset..$numberVmsToDeploy){
        Remove-Variable -Name "psSession-$virtualMachineBaseName-$i"
        Remove-Variable -Name "job-$virtualMachineBaseName-$i"
    }
}
#end region





###################################################
# region: Reporting
###################################################

# Initializations
$toOutput = "" # Info to display on console
$toCSV = "" # Info to store in a CSV file
$longpadspace = 20

# Loop through each VM created to extract properties
foreach ($i in $offset..$numberVmsToDeploy){
    $outputVmName = $virtualMachineBaseName + $i.ToString("00")
    $outputNicName = $virtualMachineBaseName + $i.ToString("00") + 'nic1'

    $data = $deploymentResult.Outputs[$outputNicName].Value.ToString() | ConvertFrom-Json
    $ip = $data.ipConfigurations[0].Properties.privateIPAddress   
    
    # Build output for console
    $toOutput += ($outputVmName.PadRight($longpadspace,'-') + $ip.Trim().PadRight($longpadspace,'-') + $username.PadRight($longpadspace,'-') + $password) + "`r`n"

    # Build output for CSV file
    $toCSV = $outputVmName + ',' + $($ip.Trim()) + ',' + $username + ',' + $password
    Out-File -FilePath $csvfilepath -Append -InputObject $toCSV -Encoding unicode # Save output to CSV file
}

# Display VM name, private IP address, local admin username, and local admin password on the console
$toOutput

#endregion