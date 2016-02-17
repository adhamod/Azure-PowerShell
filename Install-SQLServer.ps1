<#

.NAME
	Install-SQLServer.
	
.SYNOPSIS 
    InstallS SQL Server 2012 or 2014 on a Windows Server 2012 R2 host machine.

.DESCRIPTION
	
	This script performs the following operations:
        - Install SQL Server from a source file.
            - A SQL Server service account is used as the Log On As account for the SQL Server instance.
            - A SQL Server Agent service account is used as the Log On As account for the SQL Server Agent instance.
            - Nondefault locations are used for User databases, Backups, System databases, and Log files, according to
                a company standard and SQL Server best practices.
        - Performs certain post-installation SQL Server configurations through a SQL query:
            - Set the number of TempDB files
            - Set the size and autogrow sizes of the TempDB files
            - Enable certain flags
            

.PARAMETER sqlInstallationPath
	Path of the SQL Server installation file (i.e. Setup.exe). This can be either SQL Server 2012 or 2014.

.PARAMETER sizeTempDBDataFileMB
	The initial configured size of the TempDB data files, in MB.
	
.PARAMETER autogrowTempDBinMB
	The file growth of the TempDB data files, in MB.

.NOTES
    AUTHOR: Carlos Patiño
    LASTEDIT: February 8, 2016

    WARNING: Passwords with a single quote (') our double quote (") are likely to fail.
    
    WARNING: Service accounts with a space in them (such as "NT Service\MSSQLSERVER") will fail.

#>

param (
    [String]
    $sqlInstallationPath = "\\targetVM\Source\SQLServer2014\Setup.exe",

    [String]
    $sqlServerSvcAcct = "CLOUD\SVCsqlserver",

    [String]
    $sqlServerSvcAcctPwd = "testpassword",

    [String]
    $sqlAgentSvcAcct = "CLOUD\SVCsqlagent",

    [String]
    $sqlAgentSvcAcctPwd = "testpassword",

    [String]
    $intergrationServicesPwd = "testpassword",

    [String]
    $sqlServerSAPwd = "testpassword",

    [int]
    $numTempDBFiles = 8,

    [int]
    $sizeTempDBDataFileMB = 5000,

    [int]
    $autogrowTempDBinMB = 500,

    [string]
    $LocalAdmin = "AzrRootAdminUser"

    )


########################################
# Initialize variables
########################################
$ServerName = $env:COMPUTERNAME # Name of the local computer.

# It appears that Try/Catch/Finally and Trap in PowerShell only works with terminating errors.
# Make all errors terminating
$ErrorActionPreference = "Stop"; 

########################################
# Install and configure SQL Server
########################################
# Using the following document as a reference for list of parameters:
# https://msdn.microsoft.com/en-us/library/ms144259(v=sql.120).aspx

<#
 The following features are being installed:
 - Database Engine
    - Replication component of Database Engine
    - Full Text component of Database Engine
- Integration Services
- Management Tools - Complete
- Client Tools Backward Compatibility
- Client Tools Connectivity 
- SDK for SQL Server Native Client
- Software development kit
#>

# Specify installation parameters
$myArgList =  '/QS '                                               # Only shows progress, does not accept any user input
$myArgList += '/ACTION=INSTALL '
$myArgList += '/IAcceptSQLServerLicenseTerms=1 '                   # Accept the SQL Server license agreement
$myArgList += '/UPDATEENABLED=0 '                                  # Specify to NOT include product updates.
$myArgList += '/ERRORREPORTING=0 '                                 # Specify that errors CANNOT be reported to Microsoft.
$myArgList += '/SQMREPORTING=0 '                                   # Specify that SQL Server feature usage data CANNOT be collected and sent to Microsoft.                                     

$myArgList += '/FEATURES=SQLENGINE,REPLICATION,FULLTEXT,IS,ADV_SSMS,BC,CONN,SNAC_SDK,SDK '  # Specifies the Features to install        

$myArgList += '/INSTALLSHAREDDIR="E:\SQLSys\Program Files\Microsoft SQL Server" '            # Specifies a nondefault installation directory for 64-bit shared components.
$myArgList += '/INSTALLSHAREDWOWDIR="E:\SQLSys\Program Files(x86)\Microsoft SQL Server" '    # Specifies a nondefault installation directory for 32-bit shared components. 
$myArgList += '/INSTANCEDIR="E:\SQLSys\Program Files\Microsoft SQL Server" '                 # Specifies a nondefault installation directory for instance-specific components.
$myArgList += '/INSTALLSQLDATADIR="E:\SQLSys\Program Files\Microsoft SQL Server" '           # Specifies the data directory for SQL Server data files.

$myArgList += '/INSTANCENAME=MSSQLSERVER '                         # Specifies a SQL Server instance name.
      
$myArgList += "/AGTSVCACCOUNT=$sqlAgentSvcAcct "                   # Agent account name
$myArgList += "/AGTSVCPASSWORD=$sqlAgentSvcAcctPwd "               # Agent account Password
$myArgList += '/AGTSVCSTARTUPTYPE=Automatic '                      # Auto-start service after installation

$myArgList += '/SQLTEMPDBDIR="T:\TempDB" '                         # Specifies the directory for the data files for tempdb.
$myArgList += '/SQLTEMPDBLOGDIR="J:\TempDBLog" '                   # Specifies the directory for the log files for tempdb.

$myArgList += '/SQLUSERDBDIR="F:\SQLData" '                        # Specifies the directory for the data files for user databases.
$myArgList += '/SQLBACKUPDIR="E:\SQLBackup" '                      # Specifies the directory for backup files.
$myArgList += '/SQLUSERDBLOGDIR="J:\SQLLog" '                      # Specifies the directory for the log files for user databases.

$myArgList += '/ISSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE" '      # Specifies the account for Integration Services.
$myArgList += "/ISSVCPASSWORD=$intergrationServicesPwd "           # Specifies the Integration Services password.

$myArgList += "/SQLSVCACCOUNT=$sqlServerSvcAcct "                  # Account for SQL Server service
$myArgList += "/SQLSVCPASSWORD=$sqlServerSvcAcctPwd "              # SQL Service Password
$myArgList += '/SQLSVCSTARTUPTYPE=Automatic '                      # Startup type for the SQL Server service
$myArgList += "/SQLSYSADMINACCOUNTS=$ServerName\$LocalAdmin "      # Windows account(s) to provision as SQL Server system administrators.
$myArgList += 'HOMEOFFICE\CP-IaaS-Azure '                          # Add CP-IaaS-Azure group also as a SQL Server system administrator (the delimiter for /SQLSYSADMINACCOUNTS is simply a space)

$myArgList += '/SECURITYMODE=SQL '                                 # Use SQL for Mixed Mode authentication
$myArgList += "/SAPWD=$sqlServerSAPwd "                            # Specifies the password for the SQL Server sa account.

$myArgList += '/TCPENABLED=1'                                      # Enable TCP/IP Protocol

Write-Host "Installing SQL Server..."

try {
    # Start the installation process with the specified parameters.
    Start-Process -Verb runas -FilePath $sqlInstallationPath -ArgumentList $myArgList -Wait

    # TODO: How to programatically verify tha SQL Server was successfully installed.
    Write-Host "SQL Server successfully installed."

} catch {
    
    throw "Error: Something went wrong with the SQL Server installation."

}


########################################
# SQL Server Post-Installation
########################################
<#
    Build a multi-line string to be used as a SQL query.
    This query will:
        - Configure the flags to be enabled
        - Set the number of TempDB file
        - Set the initial size and autogrow size of the TempDB files

    Reference for the number of TempDB files to create according to SQL best practices:
    http://www.brentozar.com/sql/tempdb-performance-and-configuration/
    
#>

Write-Host "Configuring TempDB files and enabling SQL Server flags..."

# Enable certain trace flags.
$Query = "DBCC TRACEON (1117, 1118, 1204, 3226, 3605, -1);"

# Continue building the SQL query string. Two new lines.
$Query += "`n `n"

# Set the first TempDB file according to user-selected initial size and autogrow size
$Query += "ALTER DATABASE tempdb `n"
$Query += "MODIFY FILE (name = tempdev, FILENAME = 'T:\TempDB\tempdb.mdf', SIZE = $($sizeTempDBDataFileMB)MB, FILEGROWTH = $($autogrowTempDBinMB)MB);"

# If the user has selected to make more than 1 TempDB file, loop through to build the string for SQL query to add new TempDB files
if (   $numTempDBFiles -gt 1   ) {
    
    for ($i=2; $i -le $numTempDBFiles; $i++) {
        
        $Query += "`n `n"
        $Query += "ALTER DATABASE tempdb `n"
        $Query += "ADD FILE (NAME = tempdev$i, FILENAME = 'T:\TempDB\tempdb$i.mdf', SIZE = $($sizeTempDBDataFileMB)MB, FILEGROWTH = $($autogrowTempDBinMB)MB);"
    }
}


# Database name on which to perform query
$DatabaseName = "master"

# Timeout parameters
$QueryTimeout = 600
$ConnectionTimeout = 120

# Create the connection string and open the connection with the SQL Server instance
$conn=New-Object System.Data.SqlClient.SQLConnection
$ConnectionString = "Server={0};Database={1};Integrated Security=True;Connect Timeout={2}" -f $ServerName,$DatabaseName,$ConnectionTimeout
$conn.ConnectionString=$ConnectionString
$conn.Open()

# Create a new SQL Command with the Query and run the Command
$cmd=New-Object System.Data.SqlClient.SqlCommand($Query,$conn)
$cmd.CommandTimeout=$QueryTimeout
$ds=New-Object System.Data.DataSet
$da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
[void]$da.fill($ds)

<#
# Change the default location of the Data, Log, and Backup databases
# To add Microsoft.SqlServer.Smo objects, following the instructions on the following website: 
# http://sqlmag.com/powershell/using-sql-server-management-objects-powershell
Add-Type -path "C:\Windows\assembly\GAC_MSIL\Microsoft.SqlServer.Smo\10.0.0.0__89845dcd8080cc91\Microsoft.SqlServer.Smo.dll"
$SQLServer = New-Object Microsoft.SqlServer.Management.Smo.Server($ServerName)
$SQLServer.DefaultFile = "F:\SQL_Data"                        # Change the default location of data files
$SQLServer.DefaultLog = "F:\SQL_Logs"                         # Change the default location of log files
$SQLServer.BackupDirectory = "F:\SQL_Backup"                  # Change the default location of backup files
$SQLServer.Alter()                                            # Updates any Server object property changes on the instance of SQL Server. 
#>

# Close the connection and output any results.
$conn.Close()
$ds.Tables

# Restart the SQL Server instance
Restart-Service -Name 'MSSQLSERVER' -Force

Write-Host "SQL Server successfully configured."