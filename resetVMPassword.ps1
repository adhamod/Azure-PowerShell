<#

###########################
# For Azure Service Management
###########################

# Identify the VM
$csName = "testVMCarlos4"
$vmName = "testVMCarlos4"

# Identify the current name of the local administrator
$LocalAdminUsername = "charliebrown"

# Identify the new password of the local administrator
$LocalAdminPassword = "Letmeinpls123"

# Get Azure VM
$vm = Get-AzureVM -ServiceName $csName -Name $vmName

# This line is a hotfix based on this: https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-reset-password/
# Don't really know what it does
$vm.GetInstance().ProvisionGuestAgent = $true

# Make a credential object
$cred = New-Object System.Management.Automation.PSCredential ($LocalAdminUsername, (ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force))

# Reset password with new credential
Set-AzureVMAccessExtension –vm $vm -UserName $cred.GetNetworkCredential().Username -Password $cred.GetNetworkCredential().Password  | Update-AzureVM

#>

###########################
# For Azure Tesource Manager
###########################

# Identify the VM
$resourceGroup = "test"
$vmName = "testVMCarlos1"

# Identify the current name of the local administrator
$LocalAdminUsername = "charliebrown"

# Identify the new password of the local administrator
$LocalAdminPassword = "Letmeinpls123"

# Get Azure VM
$vm = Get-AzureRmVM -ResourceGroupName $resourceGroup -Name $vmName

# Make a credential object
$cred = New-Object System.Management.Automation.PSCredential ($LocalAdminUsername, (ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force))

<#
Reset password with new credential

This command adds a VMAccess extension for the virtual machine named $vmName in 
$resourceGroup. The command specifies the name and type handler version for VMAccess.

Why the VMAccess extension needs a name and a Type Handler Version, I do not know...

Parameters definition:
Location: Specifies the location of the virtual machine.
Name: Specifies the name of the extension that this cmdlet adds.
TypeHandlerVersion: Specifies the version of the extension to use for this virtual machine. To obtain the 
        version, run the Get-AzureRmVMExtensionImage cmdlet with a value of Microsoft.Compute 
        for the PublisherName parameter and VMAccessAgent for the Type parameter.
#>
Set-AzureRmVMAccessExtension -ResourceGroupName $resourceGroup `
                             -VMName $vmName `
                             -Location "East US 2" `
                             -Name "testVMAccessExtension" `
                             -TypeHandlerVersion "2.0" `
                             -UserName $cred.GetNetworkCredential().Username `
                             -Password $cred.GetNetworkCredential().Password
