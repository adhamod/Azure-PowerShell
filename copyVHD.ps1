<#
Starts a copy operation of a specific blob. This script works for both ARM and ASM.

User input is required.
#>


##################################
# START OF REQUIRED USER INPUT
##################################

# Connection String for the SOURCE storage account
$srcConnectionString = "DefaultEndpointsProtocol=https;AccountName=testresourcegroup16710;AccountKey=xxx"

# Container name in which the SOURCE file is located (container must be inside SOURCE storage account)
$srcContainerName = "vhds"

# Blob name of the SOURCE file (must be located inside SOURCE container)
$srcBlobName = "testVM-SV3-2.vhd"

###

# Connection String for the SOURCE storage account
$destConnectionString = "DefaultEndpointsProtocol=https;AccountName=teststore123456;AccountKey=xxx"

# Container name in which the DESTINATION file will be located (container must be inside DESTINATION storage account)
$destContainerName = "testblob"

##################################
# END OF REQUIRED USER INPUT
##################################

# Make context for SOURCE storage account
$srcContext = New-AzureStorageContext -ConnectionString $srcConnectionString
# Make context for DESTINATION storage account
$destContext = New-AzureStorageContext -ConnectionString $destConnectionString

# Start copy operation
Start-AzureStorageBlobCopy -Context $srcContext -SrcContainer $srcContainerName -SrcBlob $srcBlobName -DestContext $destContext -DestContainer $destContainerName