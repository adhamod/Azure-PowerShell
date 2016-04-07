﻿<#

.NAME
	Post-SQL-Installation-Config
	
.DESCRIPTION 
    

    PRECONDITION: The scripts Pre-SQL-Installation-COnfig.ps1 and 
        Install-SQLServer.ps1 have been executed successfully on this machine.

  Look into this:
  https://github.com/RamblingCookieMonster/PowerShell/blob/master/Invoke-Sqlcmd2.ps1

.NOTES
    AUTHOR: Carlos Patiño
    LASTEDIT: March 30, 2016
#>

param (
        #########################################
        # 10_SQL_Instance_2014_Config.sql params
        #########################################
        [string] $SMTPServerName,
        [string] $OperatorEmailAddress,

        #########################################
        # 15_SQL_TempDB_Configuration.sql params
        #########################################
        [string] $TargetDataFilesLocation = 'T:\TempDB\',
        [string] $TargetDataSizeMB = '10000MB',
        [string] $TargetDataFilegrowthMB = '5000MB',
        [string] $TargetTlogFilesLocation = 'J:\TempDBLog\',
        [string] $TargetTlogSizeMB = '5000MB',
        [string] $TargetTlogFilegrowthMB = '1000MB'

    )

########################################
# Initialize variables
########################################
$ServerName = $env:COMPUTERNAME # Name of the local computer.

# It appears that Try/Catch/Finally and Trap in PowerShell only works with terminating errors.
# Make all errors terminating
$ErrorActionPreference = "Stop";

# The SQL Server instance. For default instances, only specify the computer name
$DBServer = "$ServerName" 

# Execute scripts against the master database
$database = "master"

# Base folder with all TSQL scripts
$rootFolder = "C:\MicrosoftScripts"

# Import Invoke-SqlCMD cmdlet
Import-Module SQLPS -DisableNameChecking


########################################
# 10_SQL_Instance_2014_Config.sql
########################################

# Location of script
$DBScriptFile = "$rootFolder\10_SQL_Instance_2014_Config.sql"          

# Build the list of parameters names and parameter values to be passed to the TSQL script
$Param1 = "SMTPServerName=" + "$SMTPServerName"
$Param2 = "OperatorEmailAddress=" + "$OperatorEmailAddress"
$Params = $Param1, $Param2

Invoke-Sqlcmd -InputFile $DBScriptFile -ServerInstance $DBServer -Database $database -Variable $Params


########################################
# 15_SQL_TempDB_Configuration.sql
########################################

# Location of script
$DBScriptFile = "$rootFolder\15_SQL_TempDB_Configuration.sql"          


# Build the list of parameters names and parameter values to be passed to the TSQL script
$Param1 = "TargetDataFilesLocation=" + "$TargetDataFilesLocation"
$Param2 = "TargetDataSizeMB=" + "$TargetDataSizeMB"
$Param3 = "TargetDataFilegrowthMB=" + "$TargetDataFilegrowthMB"
$Param4 = "TargetTlogFilesLocation=" + "$TargetTlogFilesLocation"
$Param5 = "TargetTlogSizeMB=" + "$TargetTlogSizeMB"
$Param6 = "TargetTlogFilegrowthMB=" + "$TargetTlogFilegrowthMB"
$Params = $Param1, $Param2, $Param3, $Param4, $Param5, $Param6

Invoke-Sqlcmd -InputFile $DBScriptFile -ServerInstance $DBServer -Database $database -Variable $Params