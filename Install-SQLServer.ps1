<#

.NAME
	Install-SQLServer.
	
.SYNOPSIS 
    InstallS SQL Server 2012 or 2014 on a Windows Server 2012 R2 host machine.

.DESCRIPTION
	
	This script performs the following operations:
        - Create a storage pool from the available data disks attached to the host.
        - Create a Virtual Disk on the F: drive from the storage pool, 
            with an allocation unit size of 64KB (i.e. 65,536 bytes)
        - Install .NET Framework 3.5 from a source file.
        - Open ports 1433 (for the SQL Server Engine) and port 2383 (for Analysis Services) on the firewall.
        - Install SQL Server from a source file.
        - Move the tempdb database to the F: drive.
        - Move the default locations for the Data, Backup, and Log databases to the F: drive.

.PARAMETER DotNet35SourcePath
	Path of the .NET 3.5 installation files (i.e. the \sources\sxs folder)

.PARAMETER sqlInstallationPath
	Path of the SQL Server installation file (i.e. Setup.exe)
	
.EXAMPLE
    Install-SQLServer -ServerName testVM1 -LocalAdmin charliebrown -DotNet35SourcePath C:\Downloads\sources\sxs -sqlInstallationPath "C:\Downloads\SQLFULL_x64_ENU\Setup.exe"

.NOTES
    AUTHOR: Carlos Patiño
    LASTEDIT: November 30, 2015

# Improvement possibilites: using Custom Script Extension
# http://www.powershellmagazine.com/2014/04/30/understanding-azure-custom-script-extension/

#>

param (
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String]
    $DotNet35SourcePath = "C:\Users\TestAdmin\Downloads\dotnet35source\sxs",

    [ValidateNotNullOrEmpty()]
    [String]
    $sqlInstallationPath = "C:\Users\TestAdmin\Downloads\SQLServer2014\Setup.exe"

    )


########################################
# Initialize variables
########################################
$ServerName = $env:COMPUTERNAME # Name of the local computer.
$LocalAdmin = "TestAdmin" # Name of the current user (which in our particular case is always going to be the local administrator)




########################################
# Set up Storage Pool and Virtual Disk
########################################

# Gets the storage subsystem object for the Storage Spaces subsystem, passes it to the 
# Get-PhysicalDisk cmdlet, which then gets the physical disks in the specified subsystem that are available to add to a 
# storage pool
$PhysicalDisks = Get-StorageSubSystem -FriendlyName "Storage Spaces*" | Get-PhysicalDisk -CanPool $True

#This line creates a new storage pool using the $PhysicalDisks variable to specify the disks to include from the Storage 
#Spaces subsystem (specified with a wildcard * to remove the need to modify the friendly name for different computers).
New-StoragePool -FriendlyName DataDiskStoragePool `
    -StorageSubsystemFriendlyName "Storage Spaces*" `
    -PhysicalDisks $PhysicalDisks `
    -ResiliencySettingNameDefault Simple `
    -ProvisioningTypeDefault Fixed `
    -ErrorAction Stop

# Create new virtual disk, then Initialize it, then make a new partition on the F drive.
New-VirtualDisk -StoragePoolFriendlyName DataDiskStoragePool -FriendlyName "VirtualDataDisk" `
            -UseMaximumSize -ProvisioningType Fixed | Initialize-Disk  -PassThru | New-Partition -DriveLetter 'F' -UseMaximumSize `
            | Format-Volume -AllocationUnitSize 65536 -FileSystem NTFS -Confirm:$false -Force -ErrorAction Stop




########################################
# Install .NET Framework 3.5
########################################

Install-WindowsFeature -Name Net-Framework-Core -source $DotNet35SourcePath -ErrorAction Stop

# Areas for improvement: reference this article:
# http://stackoverflow.com/questions/303045/connecting-to-a-network-folder-with-username-password-in-powershell




########################################
# Install and configure SQL Server
########################################

# Create new directories
New-Item -ItemType directory -Path F:\SQL_Data | Out-Null
New-Item -ItemType directory -Path F:\SQL_Backup | Out-Null
New-Item -ItemType directory -Path F:\SQL_Logs | Out-Null
New-Item -ItemType directory -Path F:\SQL_TempDB | Out-Null

# Open up firewall ports
# For Database Engine default instance
netsh advfirewall firewall add rule name="SQL Instances" dir=in action=allow protocol=TCP localport=1433
# For Analysis Services
netsh advfirewall firewall add rule name="SQL Analysis Services" dir=in action=allow protocol=TCP localport=2383

# Specify installation parameters
$myArgList =  '/QS '                                               # Only shows progress, does not accept any user input
$myArgList += '/ACTION=INSTALL '
$myArgList += '/IAcceptSQLServerLicenseTerms=1 '                   # Accept the SQL Server license agreement
$myArgList += '/SQMREPORTING=0 '                                   # Specify that SQL Server feature usage data CANNOT be collected and sent to Microsoft.                            
            
$myArgList += '/ERRORREPORTING=0 '                                 # Specify that errors CANNOT be reported to Microsoft.
$myArgList += '/UPDATEENABLED=0 '                                  # Specify to NOT include product updates.
$myArgList += '/FEATURES=SQLENGINE,FULLTEXT,AS,RS,SSMS '           # Specifies the Features to install
            
$myArgList += '/INSTANCENAME=MSSQLSERVER ' 
            
$myArgList += '/AGTSVCACCOUNT="NT Service\SQLSERVERAGENT" '        # Agent account name
$myArgList += '/AGTSVCPASSWORD=W3lc0me0 '                          # Agent account Password
$myArgList += '/AGTSVCSTARTUPTYPE=Automatic '                      # Auto-start service after installation

$myArgList += '/ASSVCACCOUNT="NT Service\MSSQLServerOLAPService" ' # The name of the account that Analysis Services service runs under
$myArgList += '/ASSVCPASSWORD=W3lc0me0 '                           # Agent Services service Password
$myArgList += '/ASSVCSTARTUPTYPE=Automatic '                       # Controls the service starup type setting after the service has been created.
$myArgList += "/ASSYSADMINACCOUNTS=$ServerName\$LocalAdmin "       # Specifies the list of administrator accounts that need to be provisioned. 

$myArgList += '/SQLSVCSTARTUPTYPE=Automatic '                      # Startup type for the SQL Server service
$myArgList += '/SQLSVCACCOUNT="NT Service\MSSQLSERVER" '           # Account for SQL Server service
$myArgList += '/SQLSVCPASSWORD=W3lc0me0 '                          # SQL Service Password
$myArgList += "/SQLSYSADMINACCOUNTS=$ServerName\$LocalAdmin "      # Windows account(s) to provision as SQL Server system administrators.

$myArgList += '/RSSVCACCOUNT="NT Service\ReportServer" '           # Name of the accout for Reporting Services
$myArgList += '/RSSVCPASSWORD=W3lc0me0 '

$myArgList += '/SECURITYMODE=SQL '                                 # Use SQL for Mixed Mode authentication
$myArgList += '/SAPWD=W3lc0me0 '         

$myArgList += '/TCPENABLED=1'                                      # Enable TCP/IP Protocol

# Start the installation process with the specified parameters.
Start-Process -Verb runas -FilePath $sqlInstallationPath -ArgumentList $myArgList -Wait -ErrorAction Stop




########################################
# SQL Server Post-Installation
########################################

# Create SQL Query to move the TEMPDB database from its default location to the F: drive
# Using this guide: http://stackoverflow.com/questions/8423541/how-do-you-run-a-sql-server-query-from-powershell
$DatabaseName = "master"
$Query = "
          ALTER DATABASE tempdb
          MODIFY FILE (name = tempdev, FILENAME = 'F:\SQL_TempDB\tempdb.mdf');
          
          ALTER DATABASE tempdb
          MODIFY FILE (name = templog, FILENAME = 'F:\SQL_TempDB\templog.ldf');
         "

# Timeout parameters
$QueryTimeout = 120
$ConnectionTimeout = 30

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

# Change the default location of the Data, Log, and Backup databases
# To add Microsoft.SqlServer.Smo objects, following the instructions on the following website: 
# http://sqlmag.com/powershell/using-sql-server-management-objects-powershell
Add-Type -path "C:\Windows\assembly\GAC_MSIL\Microsoft.SqlServer.Smo\10.0.0.0__89845dcd8080cc91\Microsoft.SqlServer.Smo.dll"
$SQLServer = New-Object Microsoft.SqlServer.Management.Smo.Server($ServerName)
$SQLServer.DefaultFile = "F:\SQL_Data"                        # Change the default location of data files
$SQLServer.DefaultLog = "F:\SQL_Logs"                         # Change the default location of log files
$SQLServer.BackupDirectory = "F:\SQL_Backup"                  # Change the default location of backup files
$SQLServer.Alter()                                            # Updates any Server object property changes on the instance of SQL Server. 

# Close the connection and output any results.
$conn.Close()
$ds.Tables

# Restart the SQL Server instance
Restart-Service -Name 'MSSQLSERVER' -Force