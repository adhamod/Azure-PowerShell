param (
    # Resource group where the VM is located
    [string]
    $resourceGroupName = "testResourceGroup",

    [string]
    $vmName = "testVMName",

    [string[]]
    $diskNames = @("vmname-5675-1234587",
                   "vmname-5675-1234588",
                   "vmname-5675-1234589",
                   "vmname-5675-1234590"
                   ),

    [int[]]
    $diskSizesInGB = @("127",
                       "1023",
                       "512",
                       "127"
                       ),

    <#
      Logical Unit Number (LUN).
      Run Get-Disk (as an administrator) on target VM to see the
      Numbers already assigned to other disks.
      Pick a starting LUN that is not taken.
    #> 
    [int]
    $startingLUN = 2,

    [string]
    $storageAccountName = "teststorageaccountname",

    [string]
    $storageContainerName = "vhds",

    [string[]]
    #[ValidateSet('None','ReadOnly','ReadWrite')]
    $cacheSettings = @("ReadOnly",
                      "ReadOnly",
                      "None",
                      "ReadOnly"
                       )

)

# Get VM object
$vm = Get-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmName

$numDisks = ($diskNames | Measure).Count

for($i = 0; $i -lt $numDisks; $i++) {

    # Get properties for this specific disk
    $diskname = $diskNames[$i]
    $diskSizeInGB = $diskSizesInGB[$i]
    $cacheSetting = $cacheSettings[$i]
    $LUN = $startingLUN + $i

    # Add disk to VM configuration
    Add-AzureRmVMDataDisk -VM $vm `
                          -Name $diskname `
                          -VhdUri "https://$storageAccountName.blob.core.windows.net/$storageContainerName/$diskname.vhd" `
                          -Caching $cacheSetting `
                          -DiskSizeInGB $diskSizeInGB `
                          -Lun $LUN `
                          -CreateOption empty
}


# Update disk with updated VM configuration
Update-AzureRmVM -VM $vm -ResourceGroupName $resourceGroupName