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