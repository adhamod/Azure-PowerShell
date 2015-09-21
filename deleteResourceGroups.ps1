<#
Gets all the Resource Groups in the default subscription and
deletes them, except those specified by the user when prompted.

Prerequisites:
    - The Subscription from which to delete Resource Groups
    is already the default subscription.
#>

# Switch to ARM
Switch-AzureMode AzureResourceManager -WarningAction SilentlyContinue

# Get the names of all resources in the subscription and display them
$resourceGroups = Get-AzureResourceGroup | Select ResourceGroupName, Location -WarningAction SilentlyContinue
$resourceGroups # Display
$numResGrps = ($resourceGroups).Count #Get the total number of resource groups

# Workaround to force the resource groups to be displayed prior to anything else. Bug in PowerShell when
# mixing Write-Host and Read-Host commands.
Read-Host -Prompt "Press Enter to continue"


# Prompt the user for the number of resource groups to NOT delete
$numResGrpsToKeep = Read-Host "Type the number of resource groups to keep (not delete)"
$numResGrpsToKeep = [int]$numResGrpsToKeep # Cast the string input as an integer.

# Error handling - break if 0 <= number of resource groups to keep <= total number of resource groups
if (  !(( $numResGrpsToKeep -le $numResGrps ) -and ( $numResGrpsToKeep -ge 0) )  ) {

    Write-Host "Incorrect input. Please type in a valid number for the number of resource groups to keep."
    break
}

# Initialize array to containing the names of all the resource groups that
# will NOT be deleted
$arrayRsgGrpsToKeep = @("") * $numResGrpsToKeep

# Get from the user the names of the resource groups to not delete
For ($i=0; $i -lt $numResGrpsToKeep; $i++)  {
    
    $rscGroupCounter = $i + 1
    $arrayRsgGrpsToKeep[$i] = Read-Host "Enter the exact name of Resource Group #" $rscGroupCounter " to keep"
}

#######################
# Delete all resource groups, except those that the
# user specified.
#######################

foreach ($rs in $resourceGroups) {

    # Check to see if the name of the resource group
    # to be deleted is in the list of resource groups
    # to be kept.
    $found = $false

    For ($i=0; $i -lt $numResGrpsToKeep; $i++)  {

        if (  ($arrayRsgGrpsToKeep[$i] -eq $rs.ResourceGroupName) ) {

            #Update found variable to true (resource group WILL NOT be deleted)
            $found = $true

        }
    }

    # Only delete if the resource group is NOT in the list of resource groups to be kept
    if ( !($found) ) {
        Write-Host "Deleting Resource Group: " $rs.ResourceGroupName
        Remove-AzureResourceGroup -Name $rs.ResourceGroupName -Force
    }
}