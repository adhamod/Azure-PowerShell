<#

.NAME
	Post-SQL-Installation-Config
	
.DESCRIPTION 
    

    PRECONDITION: The scripts Pre-SQL-Installation-COnfig.ps1 and 
        Install-SQLServer.ps1 have been executed successfully on this machine.

.NOTES
    AUTHOR: Carlos Patiño
    LASTEDIT: March 30, 2016
#>

param (

    )

########################################
# Initialize variables
########################################
$ServerName = $env:COMPUTERNAME # Name of the local computer.

# It appears that Try/Catch/Finally and Trap in PowerShell only works with terminating errors.
# Make all errors terminating
$ErrorActionPreference = "Stop";