param (
    # Resource group where the VM is located
    [string]
    $resourceGroupName = "testResourceGroup",

    [string]
    $vmName = "testVMName",

    [string]
    $diskName = "vmname-5675-1234587",

    [int]
    $diskSizeInGB = 510,

    <#
      Logical Unit Number (LUN).
      Run Get-Disk (as an administrator) on target VM to see the
      Numbers already assigned to other disks.
      Pick a LUN that is not taken.
    #> 
    [int]
    $LUN = 6,

    [string]
    $storageAccountName = "teststorageaccountname",

    [string]
    $storageContainerName = "vhds",

    [string]
    [ValidateSet('None','ReadOnly','ReadWrite')]
    $cacheSetting = "None"

)

# Get VM object
$vm = Get-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmName

# Add disk to VM configuration
Add-AzureRmVMDataDisk -VM $vm `
                      -Name $diskname `
                      -VhdUri "https://$storageAccountName.blob.core.windows.net/$storageContainerName/$diskname.vhd" `
                      -Caching $cacheSetting `
                      -DiskSizeInGB $diskSizeInGB `
                      -Lun $LUN `
                      -CreateOption empty


# Update disk with updated VM configuration
Update-AzureRmVM -VM $vm -ResourceGroupName $resourceGroupName