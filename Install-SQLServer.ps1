<#

.NAME
	Install-SQLServer.
	
.SYNOPSIS 
    InstallS SQL Server 2012 or 2014 on a Windows Server 2012 R2 host machine.

.DESCRIPTION
	
	This script performs the following operations:
        - Create a storage pool from the available data disks attached to the host.
        - Create a Virtual Disk from the storage pool.
        - Create a number of volues with an allocation unit size of 64KB (i.e. 65,536 bytes)
        - Install .NET Framework 3.5 from a source file.
        - Open ports 1433 (for the SQL Server Engine) and port 59999 (for ILB Probe Port) on the firewall.
        - Install SQL Server from a source file, with certain volume configurations.

.PARAMETER DotNet35SourcePath
	Path of the .NET 3.5 installation folder (i.e. the \sources\sxs folder)

.PARAMETER sqlInstallationPath
	Path of the SQL Server installation file (i.e. Setup.exe)

.PARAMETER sizeTempDBDataFileMB
	The initial configured size of the TempDB data files, in MB.
	
.PARAMETER autogrowTempDBinMB
	The file growth of the TempDB data files, in MB.

.NOTES
    AUTHOR: Carlos Patiño
    LASTEDIT: January 15 2016

#>

param (
    [Parameter(Mandatory=$false)]
    [String]
    $DotNet35SourcePath = "\\ps11170644tou02.cloud.wal-mart.com\Source\dotnet35source\sxs\",

    [ValidateNotNullOrEmpty()]
    [String]
    $sqlInstallationPath = "\\ps11170644tou02.cloud.wal-mart.com\Source\SQLServer2014\Setup.exe",

    [ValidateNotNullOrEmpty()]
    [int]
    $sizeTempDBDataFileMB = 5000,

    [ValidateNotNullOrEmpty()]
    [int]
    $autogrowTempDBinMB = 500,

    [ValidateNotNullOrEmpty()]
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
# Set up Storage Pool and Virtual Disk
########################################
<# Overarching logic:
    Skip this entire section if the F: drive already exists.
    If it does not exist, create a new Storage Pool, a Virtual Disk, and a Volume with Drive Letter F:
#>

# Check for existence of current Storage Pools. Do not attept to create a Storage Pool if a 
# non-Primordial Storage Pool already exists
$DriveFexists = $false
foreach ($volume in (Get-Volume)) {
    if ($volume.DriveLetter -eq 'F') {
        $DriveFexists = $true
    }
}

if ($DriveFexists) {
    Write-Host "
                Drive F: already exists in the target machine.
                Creation of a Storage Pool, a new Virtual Disk, and a new Volume, will be skipped.
                Please ensure that Drive F is configured appropriately for SQL Server."
}
else {

    try
    {
    
        # Gets the storage subsystem object for the Storage Spaces subsystem, passes it to the 
        # Get-PhysicalDisk cmdlet, which then gets the physical disks in the specified subsystem that are 
        # available to add to a storage pool
        $PhysicalDisks = Get-StorageSubSystem -FriendlyName "Storage Spaces*" | Get-PhysicalDisk -CanPool $True

    }
    catch [Microsoft.PowerShell.Cmdletization.Cim.CimJobException]
    {
        throw "
                Error: There are no physical disks available to add to a new Storage Pool. 
                Please check that the data disks have been successfully attached to the VM."
    }

    # Check for existence of current Storage Pools. Do not attept to create a Storage Pool if a 
    # non-Primordial Storage Pool already exists
    foreach ($storagePool in (Get-StoragePool)) {
        if (  !($storagePool.IsPrimordial)  ) {
            throw "
                    Error: A non-primordial Storage Pool already exists.
                    This script is intended to run on a newly-provisioned VM, and may fail if
                    a Storage Pool has already exists in the target machine."
        }
    }

    <# 
       Create a new storage pool using the $PhysicalDisks variable to specify the disks to include 
       from the Storage Spaces subsystem (specified with a wildcard * to remove the need to modify the 
       friendly name for different computers).
    #>
    New-StoragePool -FriendlyName DataDiskStoragePool `
                    -StorageSubsystemFriendlyName "Storage Spaces*" `
                    -PhysicalDisks $PhysicalDisks `
                    -ResiliencySettingNameDefault Simple `
                    -ProvisioningTypeDefault Fixed | Out-Null

    # Stops the Hardware Detection Service to prevent the Format Disk prompt window from popping up
    Stop-Service -Name ShellHWDetection

    # Create new virtual disk, then Initialize it.
    New-VirtualDisk -StoragePoolFriendlyName DataDiskStoragePool `
                    -FriendlyName "VirtualDataDisk" `
                    -UseMaximumSize -ProvisioningType Fixed `
                    | Initialize-Disk -PassThru | Out-Null

    # Get the virtual disk created
    # The C: and D: disks will have numbers 0 and 1. 
    # Logic: if storage pool successfully created, any disk with a number greater or equal to 2
    # must be the disk just created
    $VirtualDisk = Get-Disk | Where-Object {$_.Number -ge 2}

    <#
        Make partitions on the disk according to SQL Server standard
    #>

    # E drive
    try 
    {
        $VirtualDisk `
                | New-Partition -DriveLetter 'E' -Size (50GB) `
                | Format-Volume -AllocationUnitSize 65536 -FileSystem NTFS `
                                -NewFileSystemLabel "SQLSys" -Confirm:$false -Force | Out-Null
    }
    
    catch
    {
        $drv = Get-WmiObject win32_volume -filter 'DriveLetter = "E:"'
        $drv.DriveLetter = "Z:"
        $drv.Put() | Out-Null

        # Try again after reassigning DVD drive to Z: drive
        $VirtualDisk `
                | New-Partition -DriveLetter 'E' -Size (50GB) `
                | Format-Volume -AllocationUnitSize 65536 -FileSystem NTFS `
                                -NewFileSystemLabel "SQLSys" -Confirm:$false -Force | Out-Null
    }
    

    # I drive
    $VirtualDisk `
                | New-Partition -DriveLetter 'I' -Size (300GB) `
                | Format-Volume -AllocationUnitSize 65536 -FileSystem NTFS `
                                -NewFileSystemLabel "SQLLog" -Confirm:$false -Force | Out-Null

    # T drive
    $VirtualDisk `
                | New-Partition -DriveLetter 'T' -Size (224GB) `
                | Format-Volume -AllocationUnitSize 65536 -FileSystem NTFS `
                                -NewFileSystemLabel "TempDB" -Confirm:$false -Force | Out-Null

    # U drive
    $VirtualDisk `
                | New-Partition -DriveLetter 'U' -Size (50GB) `
                | Format-Volume -AllocationUnitSize 65536 -FileSystem NTFS `
                                -NewFileSystemLabel "TempLog" -Confirm:$false -Force | Out-Null

    # F drive
    $VirtualDisk `
                | New-Partition -DriveLetter 'F' -UseMaximumSize `
                | Format-Volume -AllocationUnitSize 65536 -FileSystem NTFS `
                                -NewFileSystemLabel "SQLData" -Confirm:$false -Force | Out-Null

    # Starts the Hardware Detection Service again
    Start-Service -Name ShellHWDetection

    Write-Host "Volumes have been successfully configured."

}

# Create new directories if they do not already exist
$pathsToCreate = @( "E:\SQLSys";
                    "F:\SQLData";
                    "F:\SQLData";
                    "F:\SQLBackup";
                    "I:\SQLLog";
                    "T:\SQLTempDB";
                    "U:\SQLTempLog")

foreach ($path in $pathsToCreate) {
    if (!(Test-Path $path)) {
        New-Item -ItemType directory -Path $path | Out-Null
    }
}

Write-Host "Drive folders created."


########################################
# Install .NET Framework 3.5
########################################

Install-WindowsFeature -Name Net-Framework-Core -source $DotNet35SourcePath | Out-Null

Write-Host ".NET Framework 3.5 successfully installed."


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

$myArgList += '/INSTALLSHAREDDIR="E:\SQLSys\Program Files\MicrosoftSQL Server" '            # Specifies a nondefault installation directory for 64-bit shared components.
$myArgList += '/INSTALLSHAREDWOWDIR="E:\SQLSys\Program Files(x86)\MicrosoftSQL Server" '    # Specifies a nondefault installation directory for 32-bit shared components. 
$myArgList += '/INSTANCEDIR="E:\SQLSys\Program Files\MicrosoftSQL Server" '                 # Specifies a nondefault installation directory for instance-specific components.
$myArgList += '/INSTALLSQLDATADIR="E:\SQLSys\Program Files\MicrosoftSQL Server" '           # Specifies the data directory for SQL Server data files.

$myArgList += '/INSTANCENAME=MSSQLSERVER '                         # Specifies a SQL Server instance name.
      
$myArgList += '/AGTSVCACCOUNT="NT Service\SQLSERVERAGENT" '        # Agent account name
$myArgList += '/AGTSVCPASSWORD=W3lc0me0 '                          # Agent account Password
$myArgList += '/AGTSVCSTARTUPTYPE=Automatic '                      # Auto-start service after installation

$myArgList += '/SQLTEMPDBDIR="T:\SQLTempDB" '                      # Specifies the directory for the data files for tempdb.
$myArgList += '/SQLTEMPDBLOGDIR="U:\SQLTempLog" '                  # Specifies the directory for the log files for tempdb.

$myArgList += '/SQLUSERDBDIR="F:\SQLData" '                        # Specifies the directory for the data files for user databases.
$myArgList += '/SQLBACKUPDIR="F:\SQLBackup" '                      # Specifies the directory for backup files.
$myArgList += '/SQLUSERDBLOGDIR="I:\SQLLog" '                      # Specifies the directory for the log files for user databases.

$myArgList += '/ISSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE" '      # Specifies the account for Integration Services.
$myArgList += '/ISSVCPASSWORD=W3lc0me0 '                           # Specifies the Integration Services password.

$myArgList += '/SQLSVCACCOUNT="NT Service\MSSQLSERVER" '           # Account for SQL Server service
$myArgList += '/SQLSVCPASSWORD=W3lc0me0 '                          # SQL Service Password
$myArgList += '/SQLSVCSTARTUPTYPE=Automatic '                      # Startup type for the SQL Server service
$myArgList += "/SQLSYSADMINACCOUNTS=$ServerName\$LocalAdmin "      # Windows account(s) to provision as SQL Server system administrators.
$myArgList += 'HOMEOFFICE\CP-IaaS-Azure '                          # Add CP-IaaS-Azure group also as a SQL Server system administrator (the delimiter for /SQLSYSADMINACCOUNTS is simply a space)

$myArgList += '/SECURITYMODE=SQL '                                 # Use SQL for Mixed Mode authentication
$myArgList += '/SAPWD=W3lc0me0 '                                   # Specifies the password for the SQL Serversa account.

$myArgList += '/TCPENABLED=1'                                      # Enable TCP/IP Protocol

# Start the installation process with the specified parameters.
Start-Process -Verb runas -FilePath $sqlInstallationPath -ArgumentList $myArgList -Wait

Write-Host "SQL Server successfully installed."


########################################
# SQL Server Post-Installation
########################################


# Open up firewall ports
# For Database Engine default instance
netsh advfirewall firewall add rule name="SQLServer-TCP-1433" dir=in action=allow protocol=TCP localport=1433
# For Internal Load Balancer probe port
netsh advfirewall firewall add rule name="ILBProbePort-TCP-59999" dir=in action=allow protocol=TCP localport=59999

<#

    Create a SQL query to set the size and number of TempDB files.

    For TempDB, create 8 data files (as opposed to the default of 1).
    Using this as a Best Practices source: http://www.brentozar.com/sql/tempdb-performance-and-configuration/
    
#>
$DatabaseName = "master"
$Query = "

          DBCC TRACEON (1117, 1118, 1204, 3226, 3605, -1);

          ALTER DATABASE tempdb
          MODIFY FILE (name = tempdev, FILENAME = 'T:\SQLTempDB\tempdb.mdf', SIZE = $($sizeTempDBDataFileMB)MB, FILEGROWTH = $($autogrowTempDBinMB)MB);

          ALTER DATABASE tempdb
          ADD FILE (NAME = tempdev2, FILENAME = 'T:\SQLTempDB\tempdb2.mdf', SIZE = $($sizeTempDBDataFileMB)MB, FILEGROWTH = $($autogrowTempDBinMB)MB);

          ALTER DATABASE tempdb
          ADD FILE (NAME = tempdev3, FILENAME = 'T:\SQLTempDB\tempdb3.mdf', SIZE = $($sizeTempDBDataFileMB)MB, FILEGROWTH = $($autogrowTempDBinMB)MB);

          ALTER DATABASE tempdb
          ADD FILE (NAME = tempdev4, FILENAME = 'T:\SQLTempDB\tempdb4.mdf', SIZE = $($sizeTempDBDataFileMB)MB, FILEGROWTH = $($autogrowTempDBinMB)MB);

          ALTER DATABASE tempdb
          ADD FILE (NAME = tempdev5, FILENAME = 'T:\SQLTempDB\tempdb5.mdf', SIZE = $($sizeTempDBDataFileMB)MB, FILEGROWTH = $($autogrowTempDBinMB)MB);

          ALTER DATABASE tempdb
          ADD FILE (NAME = tempdev6, FILENAME = 'T:\SQLTempDB\tempdb6.mdf', SIZE = $($sizeTempDBDataFileMB)MB, FILEGROWTH = $($autogrowTempDBinMB)MB);

          ALTER DATABASE tempdb
          ADD FILE (NAME = tempdev7, FILENAME = 'T:\SQLTempDB\tempdb7.mdf', SIZE = $($sizeTempDBDataFileMB)MB, FILEGROWTH = $($autogrowTempDBinMB)MB);

          ALTER DATABASE tempdb
          ADD FILE (NAME = tempdev8, FILENAME = 'T:\SQLTempDB\tempdb8.mdf', SIZE = $($sizeTempDBDataFileMB)MB, FILEGROWTH = $($autogrowTempDBinMB)MB);
         "

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