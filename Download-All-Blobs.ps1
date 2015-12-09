<#
 This script downloads all of the contents of a particular container to the specified
 destination folder.
#>


#### USER INPUITS
$container_name = 'packageitems'
$destination_path = 'C:\pstest'
$connection_string = 'DefaultEndpointsProtocol=https;AccountName=[REPLACEWITHACCOUNTNAME];AccountKey=[REPLACEWITHACCOUNTKEY]'


#### MAIN FUNCTION

$storage_account = New-AzureStorageContext -ConnectionString $connection_string

$blobs = Get-AzureStorageBlob -Container $container_name -Context $storage_account

foreach ($blob in $blobs)
    {
        New-Item -ItemType Directory -Force -Path $destination_path

        Get-AzureStorageBlobContent `
        -Container $container_name -Blob $blob.Name -Destination $destination_path `
        -Context $storage_account

    }