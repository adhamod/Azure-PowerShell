<#

.NAME
	Create-Multi-Tier-VMs
	
.SYNOPSIS 
    Deploys VMs and their associated resources in a multi-tier environment.

.DESCRIPTION
    This script allows the user to deploy multiple sets of VMs to different tiers. That is:
    - The user can select how many tiers to deploy.
    - The user can then select how many identical VMs to deploy in each tier.
    - All VMs in the same tier belong to the same subnet, and their 
            respective OS disks belong to the same storage account.
    -If any of the resources named (including the VNet, the storage accounts, 
            the subnets, the public IP address objects, the resource group itself,
            the NICs, and the VMs) do not already exist, this script will create them.
	

.PARAMETER $numberOfTiers
    Describes the number of tiers that will be deployed. For example, if the environment you are
    deploying requires a Web tier, an Application tier, and a Database tier, this parameter would be 3.
    All VMs in the same tier will be placed in the same subnet. VMs in different tiers will be placed
    in different subnets.

.PARAMETER $numOfVMInstances
    This parameter is an array (of length equal to $numberOfTiers) that contains the number of identical
    VM instances to be deployed in each tier. For example, if $numberOfTiers = 3, 
    and $numOfVMInstances = @(1,4,2), that means that 1 VM will be deployed in the 1st tier; 4 VMs will
    be deployed in the 2nd tier; and 2 VMs will be created in the 3rd tier.


.NOTES
    Before using this script, make sure to log into your Azure Resource Manager account
    by using the command:
        Login-AzureRmAccount

    This script uses Azure PowerShell version 1.0 and above.

    AUTHOR: Carlos Patiño
    LASTEDIT: December 3, 2015
#>

param (

    # Global parameters

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String]
    $ResourceGroupName = "testRG",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [Int]
    $numberOfTiers = 3,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String]
    $Location = "East US 2",

    # Compute

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String]
    $LocalAdminUsername = "charliebrown",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String]
    $LocalAdminPassword = "Letmeinpls123",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    $vmNamePrefix = @("HAZRWeb","HAZRApp","HAZRDB"),

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    $numOfVMInstances = @(1,2,3),

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    $vmSizes = @("Standard_D2","Standard_D1","Standard_D1"),

    
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    $imageSku = @( # This is Windows Server 2012 R2 Datacenter, October 2015
                    "2012-R2-Datacenter",
                    "2012-R2-Datacenter",
                    "2012-R2-Datacenter"),

    # Storage

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    $osDiskNames = @("charlieosdisk1","charlieosdisk2","charlieosdisk3"),

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    $storageAccountNames = @("teststorageacct111","teststorageacct111","teststoragetoacct112"),

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    $storageAccountTypes = @("Standard_LRS","Standard_LRS","Standard_LRS"),

    # VM-specific Networking

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    $PrefixDNSNamesforPublicIP = @("charliewebtier","charlieapptier","charliedbtier"),

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    $InterfaceNamePrefix = @("charliewebnic","charlieappnic","charliedbnic"),

    # General networking

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String]
    $vNetName = "myVNet",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String]
    $vNetAddressPrefix = "10.0.0.0/16",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    $SubnetNames = @("testsubnet1","testsubnet2","testsubnet3"),

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    $SubnetAddressPrefixes = @("10.0.0.0/24","10.0.1.0/24","10.0.2.0/24")

)

############################################
# User input is NOT needed beyond this point
############################################

function Does-Resource-Exist {
<#
  .SYNOPSIS
  Returns true if a particular item already exists in a list. False otherwise.
#>

    param
      (
        [Parameter(Mandatory=$True)]
        [AllowNull()]
        $listOfResources,
	
        [Parameter(Mandatory=$True)]	
        [string]
        $resourceName,

        [Parameter(Mandatory=$false)]	
        [string]
        $nameField
      )

    # Get the length of the list of resources
    $lengthOfList = $listOfResources.Length

    # If there are no elements in the list of resources, return false
    if ($lengthOfList -eq 0) {
        $false
        return
    }

    # Sequentially search through the list for the resource
    for ($i=0; $i -lt $lengthOfList; $i++) {

        if ($listOfResources[$i].($nameField) -eq $resourceName) {
            $true
            return
        }

    }

    # Output result as false if the resource was not found
    $false

}


############################################################
################ MAIN FUNCTION #############################
############################################################

# Resource Group
Write-Host "Resource Group configuration..."

if (Does-Resource-Exist -listOfResources (Get-AzureRmResourceGroup -ErrorAction Stop ) -resourceName $ResourceGroupName -nameField "ResourceGroupName") {
    
    Write-Host "Resource Group $ResourceGroupName already exists."

} else {

    Write-Host "Creating resource group $ResourceGroupName ..."

    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction Stop | Out-Null

}


# VNet
Write-Host "Virtual Network configuration..."

if (Does-Resource-Exist -listOfResources (Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroupName -ErrorAction Stop) -resourceName $vNetName -nameField "Name") {

    Write-Host "Virtual Network $vNetName already exists."

} else {

    Write-Host "Creating virtual network $vNetName ..."

    New-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $vNetName -Location $Location -AddressPrefix $vNetAddressPrefix -ErrorAction Stop | Out-Null

}

# Subnets
Write-Host "Subnet configuration..."

$existingVNet = Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $vNetName

# Iterate through each of the tier levels
for ($i=0; $i -lt $numberOfTiers; $i++) {

    $TierLevel = $i + 1
    $currentSubnetName = $SubnetNames[$i]
    $currentSubnetAddressPrefix = $SubnetAddressPrefixes[$i]

    if (Does-Resource-Exist -listOfResources (Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $existingVNet -ErrorAction Stop) -resourceName $SubnetNames[$i] -nameField "Name") {

        Write-Host "For Tier Level $TierLevel, the subnet with name $currentSubnetName already exists."

    } else {

        Write-Host "Creating subnet $currentSubnetName ..."

        $existingVNet | Add-AzureRmVirtualNetworkSubnetConfig -Name $currentSubnetName -AddressPrefix $currentSubnetAddressPrefix | Set-AzureRmVirtualNetwork -ErrorAction Stop | Out-Null 

    }
}

# Storage Accounts
Write-Host "Storage Account configuration..."

# Iterate through each of the tier levels
for ($i=0; $i -lt $numberOfTiers; $i++) {

    $TierLevel = $i + 1
    $currentStorageAccountName = $storageAccountNames[$i]
    $currentStorageAccountType = $storageAccountTypes[$i]
    
    if (Does-Resource-Exist -listOfResources (Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -ErrorAction Stop) -resourceName $storageAccountNames[$i] -nameField "StorageAccountName") {

        Write-Host "For Tier Level $TierLevel, the storage account with name $currentStorageAccountName already exists."

    } else {

        Write-Host "Creating storage account $currentStorageAccountName ..."

        New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $storageAccountNames[$i] -Type $storageAccountTypes[$i] -Location $Location -ErrorAction Stop | Out-Null

    }
}

# Public IPs
for ($i=0; $i -lt $numberOfTiers; $i++) {

    for ($j=1; $j -lt ($numOfVMInstances[$i]+1); $j++) {

        $TierLevel = $i + 1
        # Take the DNS prefix and append to it a number from 1 to the total number of VM instances in this Tier
        $currentDNSNameforPublicIP = "$($PrefixDNSNamesforPublicIP[$i])" + "$j" 

        if (Does-Resource-Exist -listOfResources (Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName) -resourceName $currentDNSNameforPublicIP -nameField "Name") {

            Write-Host "For Tier Level $TierLevel, the public IP address with name $currentDNSNameforPublicIP already exists."

        } else {

            Write-Host "Creating public IP address $currentDNSNameforPublicIP ..."
            New-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $currentDNSNameforPublicIP -Location $Location -AllocationMethod Dynamic -DomainNameLabel $currentDNSNameforPublicIP | Out-Null

        }
    }
}

# NICs
for ($i=0; $i -lt $numberOfTiers; $i++) {

    for ($j=1; $j -lt ($numOfVMInstances[$i]+1); $j++) {

        $TierLevel = $i + 1
        # Take the NIC prefix and append to it a number from 1 to the total number of VM instances in this Tier
        $currentInterfaceNamePrefix = "$($InterfaceNamePrefix[$i])" + "$j"

        # Get the public IP address and Subnet corresponding to this Tier and this VM instance
        $thisPublicIPResource = Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName -Name ("$($PrefixDNSNamesforPublicIP[$i])" + "$j")
        $thisSubnet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $existingVNet  -Name $SubnetNames[$i]

        if (Does-Resource-Exist -listOfResources (Get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroupName) -resourceName $currentInterfaceNamePrefix -nameField "Name") {

            Write-Host "For Tier Level $TierLevel, the NIC with name $currentInterfaceNamePrefix already exists."

        } else {

            Write-Host "Creating NIC $currentInterfaceNamePrefix in subnet $($thisSubnet.Name) and with public IP $($thisPublicIPResource.Name) ..."
            write-host "$($thisSubnet.Id)"
            New-AzureRmNetworkInterface -ResourceGroupName $ResourceGroupName `
                                        -Name $currentInterfaceNamePrefix `
                                        -Location $Location `
                                        -PublicIpAddressId $thisPublicIPResource.Id `
                                        -SubnetId $thisSubnet.Id `
                                        | Out-Null -ErrorAction Stop

        }
    }
}


### Virtual Machine
for ($i=0; $i -lt $numberOfTiers; $i++) {

    for ($j=1; $j -lt ($numOfVMInstances[$i]+1); $j++) {

        $TierLevel = $i + 1
        # Take the VM prefix and append to it a number from 1 to the total number of VM instances in this Tier
        $currentVMName = "$($vmNamePrefix[$i])" + "$j"

        # Get the NIC and OS diskcorresponding to this Tier and this VM instance
        $thisNIC = Get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroupName -Name ("$($InterfaceNamePrefix[$i])" + "$j")
        $thisOSDisk = "$("$($osDiskNames[$i])" + "$j")"

        # Create the path of where this VM's OS disk should be locate
        $thisStorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $storageAccountNames[$i]
        $thisOSDiskURI = $thisStorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + "$thisOSDisk" + ".vhd"

        if (Does-Resource-Exist -listOfResources (Get-AzureRmVM -ResourceGroupName $ResourceGroupName) -resourceName $currentVMName -nameField "Name") {

            Write-Host "For Tier Level $TierLevel, the VM with name $currentVMName already exists."

        } else {

            Write-Host "Creating VM $currentVMName ..."

            $Credential = New-Object System.Management.Automation.PSCredential ($LocalAdminUsername, (ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force))

            $thisVM = New-AzureRmVMConfig -VMName $currentVMName -VMSize $vmSizes[$i]
            $thisVM | Set-AzureRmVMOperatingSystem -Windows -ComputerName $currentVMName -Credential $Credential -ProvisionVMAgent
            $thisVM | Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus $imageSku[$i] -Version "latest"
            $thisVM | Add-AzureRmVMNetworkInterface -Id $thisNIC.Id
            $thisVM | Set-AzureRmVMOSDisk -Name $thisOSDisk -CreateOption fromImage -VhdUri $thisOSDiskURI 
            $thisVM | New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location | out-null
           

        }
    }
}