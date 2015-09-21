<#
This script copies a blob using user-inputted connection strings for the Source and the
Destination storage accounts. Can be used to copy VHD files across storage accounts.

This script has been tested to function correctly in both ASM and ARM.

Author: Carlos Patiño, carpat@microsoft.com
#>


##################################
# START OF REQUIRED USER INPUT
##################################

# Connection String for the SOURCE storage account
$srcConnectionString = "DefaultEndpointsProtocol=https;AccountName=xxx;AccountKey=xxx"

# Container name in which the SOURCE file is located (container must be inside SOURCE storage account)
$srcContainerName = "testContainer"

# Blob name of the SOURCE file (must be located inside SOURCE container)
$srcBlobName = "testBlob.vhd"

###

# Connection String for the DESTINATION storage account
$destConnectionString = "DefaultEndpointsProtocol=https;AccountName=xxx;AccountKey=xxx"

# Container name in which the DESTINATION file will be located (container must be inside DESTINATION storage account)
$destContainerName = "testDestinationContainer"

##################################
# END OF REQUIRED USER INPUT
##################################

# Make context for SOURCE storage account
$srcContext = New-AzureStorageContext -ConnectionString $srcConnectionString
# Make context for DESTINATION storage account
$destContext = New-AzureStorageContext -ConnectionString $destConnectionString

# Start copy operation
Start-AzureStorageBlobCopy -Context $srcContext -SrcContainer $srcContainerName -SrcBlob $srcBlobName -DestContext $destContext -DestContainer $destContainerName