<#
Starts a copy operation from a specific blob to another in ARM.

Prerequisites:
    - The Subscription to which the blob will be copied is already
    the current Subscription. I.e., the DESTINATION subscription 
    is already set as the current subscription in PowerShell.
#>

# Switch between ASM and ARM
$mode = Read-Host "Type ASM to use Azure Service Management, or type ARM to use Azure Resource Manager"

switch ($mode)
{
    # Use ASM
    "ASM" {

        Switch-AzureMode AzureServiceManagement -WarningAction SilentlyContinue
        
        #### Not yet finished


    }

    # Use ARM
    "ARM" {
        
        Switch-AzureMode AzureResourceManager -WarningAction SilentlyContinue
        
        #########
        # SOURCE
        #########

        # Get connection string for the SOURCE storage account
        # $srcConnectionString = Read-Host "Please paste the connection string of the Source storage account"
        $srcConnectionString = "DefaultEndpointsProtocol=https;AccountName=testresourcegroup16710;AccountKey=WUD0Bcn/yBtu/3/Ee9uaZ/F3GOeZGWKY6vBIUkc1FTHHEtWK/UyLd9tzA0aerOLfYY8Ws8UtVxRvpZGIGuNh+g=="

        # Make context for SOURCE storage account
        $srcContext = New-AzureStorageContext -ConnectionString $srcConnectionString
        
        # Get container name and blob name of SOURCE file
        $srcContainerName = "vhds"
        $srcBlobName = "testVM-SV3-2.vhd"


        #########
        # DESTINATION
        #########

        # Get connection string for the DESTINATION storage account
        # $srcConnectionString = Read-Host "Please paste the connection string of the Destination storage account"
        $destConnectionString = "DefaultEndpointsProtocol=https;AccountName=teststore123456;AccountKey=V7LvSTswsEknsbLU2NJg1+AhoSc7k/mVRYGDVwGh2B5FGqkon5Zyj44+dOY+p4JJcWZ49rb/6b/wPobtaxbVXw=="
        
        # Make context for SOURCE storage account
        $destContext = New-AzureStorageContext -ConnectionString $destConnectionString

        # Get container name of DESTINATION file
        $destContainerName = "testblob"

        # Start copy operation
        Start-AzureStorageBlobCopy -Context $srcContext -SrcContainer $srcContainerName -SrcBlob $srcBlobName -DestContext $destContext -DestContainer $destContainerName

    }

    # Error handling in case of incorrect user input.
    default {"Incorrect input. Please type in ASM or ARM when running this script again"; break}
}