<#

.NAME
	Give-FullControlOverDir
	
.DESCRIPTION 
    Assign the specified user accounts full control over the specified directories

.PARAMETER identities
	An array containing the list of accounts to be given full control permissions over the
    specified folders. Specify each account in the format "DOMAIN\USER"

.PARAMETER directories
	An array containing the list of directories over which the specified users will have
    full control permissions. Specify each directory with its full path (e.g. "C:\testfolder")

.NOTES
    AUTHOR: Carlos Patiño
    LASTEDIT: June 14, 2016
#>
param(
    [string[]]
    $identities = @("DOMAIN\user1",
                    "DOMAIN\user2"),
    
    [string[]]
    $directories = @("C:\test1",
                     "C:\test2")
)

# Define the properties of the Access Rule
$fileSystemRights = [System.Security.AccessControl.FileSystemRights]::FullControl
$inheritanceFlags = [System.Security.AccessControl.InheritanceFlags]::ObjectInherit -bor `
                    [System.Security.AccessControl.InheritanceFlags]::ContainerInherit
$propagationFlags = [System.Security.AccessControl.PropagationFlags]::None
$accessControlType = [System.Security.AccessControl.AccessControlType]::Allow

#Initialize an array to contain the access rules. A separate access rule is created per user.
$accessRulesArray = @($false) * ($identities | Measure).Count

# Create the access rules, one for each user.
for($i = 0; $i -lt ($identities | Measure).Count; $i++) {

    $accessRulesArray[$i] = New-Object System.Security.AccessControl.FileSystemAccessRule( `
                        $identities[$i], `
                        $fileSystemRights, `
                        $inheritanceFlags, `
                        $propagationFlags, `
                        $accessControlType `
                )

}

# Loop through all Access Rules (one per user)
for($j = 0; $j -lt ($accessRulesArray | Measure).Count; $j++) {

    # Loop through all directories
    for ($k = 0; $k -lt ($directories | Measure).Count; $k++) {

        # For each directory and for each user, add an Access Control List (ACL)
        # giving the user full control over the directory.
        $acl = Get-Acl -Path $directories[$k]
        $acl.SetAccessRule($accessRulesArray[$j])
        Set-Acl -Path $directories[$k] -AclObject $acl
    }

}
