<#
This script copies blobs using user-inputted connection strings for the Source and the
Destination storage accounts. Can be used to copy VHD files across storage accounts.

The container names and the blob names of the SOURCE blobs are stored in a CSV file,
in the following format:
        Container,Blob Name
        ContainerName1,BlobName1
        ContainerName12,BlobName2
        etc.

The name of the DESTINATION container must be specified under user input.

This script has been tested to function correctly in both ASM and ARM.

This script has been tested to function correctly in Azure PowerShell version 1.0.1

This script also works when the source VHD file has a lease (i.e. the VHD file is being used for an Azure disk).

Author: Carlos Patiño, carpat@microsoft.com
#>


##################################
# START OF REQUIRED USER INPUT
##################################

# Connection String for the SOURCE storage account
$srcConnectionString = "DefaultEndpointsProtocol=https;AccountName=xxxx;AccountKey=xxxx"

# Complete path for the CSV file where all the container names and blob names for all the blobs to be copied are stored.
$csvPath = "C:\Users\carpat\Desktop\testcsvfile.csv"

###

# Connection String for the DESTINATION storage account
$destConnectionString = "DefaultEndpointsProtocol=https;AccountName=xxxx;AccountKey=xxx"

# Container name in which the DESTINATION file will be located (container must be inside DESTINATION storage account)
$destContainerName = "testdestinationcontainer"

##################################
# END OF REQUIRED USER INPUT
##################################

# Make context for SOURCE storage account
$srcContext = New-AzureStorageContext -ConnectionString $srcConnectionString
# Make context for DESTINATION storage account
$destContext = New-AzureStorageContext -ConnectionString $destConnectionString

#Import contents from the CSV file
$blobobjects = Import-Csv -path $csvPath

#Get each blob and copy it individually
foreach ($blob in $blobobjects){

    $srcContainerName = $blob.Container
    $srcBlobName = $blob.'Blob Name'

    # Start copy operation for each blob
    Start-AzureStorageBlobCopy -Context $srcContext -SrcContainer $srcContainerName -SrcBlob $srcBlobName -DestContext $destContext -DestContainer $destContainerName

}

