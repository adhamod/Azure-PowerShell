<#

.NAME
    MasterScript-Install-SQL-Server

.DESCRIPTION
    Remotely executes a number of PowerShell scripts on a specified target VM to configure and install SQL Server.

    PREREQUISITES: The following PowerShell scripts must exist in the same folder as MasterScript-Install-SQL-Server.ps1:
        - Pre-SQL-Installation-Config.ps1
        - Install-SQLServer.psq1
        - Post-SQL-Installation-Config.ps1

    See the individual PowerShell scripts listed above for detailed documentation.

.NOTES
    AUTHOR: Carlos Patiño
    LASTEDIT: April 1, 2016
#>

param (

    # FQDN of target VM
    $vm = "targetVM.com",

    #######################################
    <# Pre-SQL-Installation-Config.ps1 parameters #>
    #######################################
    [String] $DotNet35SourcePath = "\\fileshareVM.com\Source\dotnet35source\sxs\",
    [int] $SQLServerPort = 1433,
    [int] $SQLListenerPort = 1434,
    [int] $ILBProbePort = 59999,


    #######################################
    <# Install-SQLServer.ps1 parameters #>
    #######################################

    [String] $sqlInstallationPath = "\\fileshareVM.com\Source\SQLServer2014SP1\Setup.exe",
    [string] $LocalAdmin = "AzrRootAdminUser",
    [String] $sqlServerSAPwd = "testpassword", # Password for the SQL sa account for SQL authentication

    <# Array of Windows user accounts or Windows group accounts that will be added as sysadmins 
        of SQL Server instance #>  
    [string[]]
    $sqlAdminsArray = @("CLOUD\TESTACCOUNT1",
                        "CLOUD\TESTACCOUNT2"),

    [int] $sizeTempDBDataFileMB = 5000,
    [int] $autogrowTempDBinMB = 500,

    <# Boolean to indicate whether to use Local service accounts (e.g. NT Service\MSSQLSERVER) 
        or Domain service accounts (e.g. MyCompanyDomain\SqlServiceAccount) for SQL Server and SQL Agent #>  
    [bool]
    $UseDefaultLocalServiceAccounts = $true,

    <# Parameters only applicable if using Domain Service Accounts for SQL Server and SQL Agent #>

    [String] $sqlServerSvcAcct = "CLOUD\SVCsqlserver", # SQL Server service account name
    [String] $sqlServerSvcAcctPwd = "testpassword", # SQL Server service account password
    [String] $sqlAgentSvcAcct = "CLOUD\SVCsqlagent", # SQL Agent service account name
    [String] $sqlAgentSvcAcctPwd = 'testpassword' # SQL Agent service account password


)

################################################
# Initializations
###############################################

$ErrorActionPreference = 'Stop'

# Prompt the user for a domain credential that will have access to all of the VMs
$cred = Get-Credential

echo "`n Processing $vm"


################################################
# Run Pre-SQL-Installation-Config.ps1 remotely
###############################################

try {

    Write-Host "Running Pre-SQL-Installation-Config.ps1..."

    Invoke-Command -ComputerName $vm -Credential $cred -FilePath "$PSScriptRoot\Pre-SQL-Installation-Config.ps1" `
                   -ArgumentList $DotNet35SourcePath,`
                                 $SQLServerPort,`
                                 $SQLListenerPort,`
                                 $ILBProbePort
} catch {

    $ErrorMessage = $_.Exception.Message
    
    Write-Host "Pre-SQL-Installation-Config.ps1 failed with the following error message:"
    Write-Host "$ErrorMessage"

}


################################################
# Run Install-SQLServer.ps1 remotely
###############################################
                       
try{

    Write-Host "Running Install-SQLServer.ps1..."

    # Enable Util server as the CredSSP Client
    Enable-WSManCredSSP -Role Client -DelegateComputer $vm -Force | Out-Null

    Write-Host "Set current VM as CredSSP Client"

    # Enable the target VM as the CredSSP Server
    Invoke-Command -ComputerName $vm -Credential $cred -ScriptBlock { Enable-WSManCredSSP -Role Server -Force | Out-Null }

    Write-Host "Set target VM as CredSSP Server"

    <#
     Run Install-SQLServer remotely

     The SQL Server installation will retrieve the SQL Server installation bits from a remote file-share server
     This will involve a double-hop authentication, which is by default not allowed using Kerberos authentication.
     Use CredSSP authentication so that the user's credentials are passed to a remote computer to be authenticated,
     thus avoiding 
    
    #>
    Invoke-Command -ComputerName $vm -Credential $cred -FilePath "$PSScriptRoot\Install-SQLServer.ps1" `
                   -Authentication Credssp `
                   -ArgumentList $sqlInstallationPath,`
                                 $LocalAdmin,`
                                 $sqlServerSAPwd,`
                                 $sqlAdminsArray,`
                                 $sizeTempDBDataFileMB,`
                                 $autogrowTempDBinMB,`
                                 $UseDefaultLocalServiceAccounts,`
                                 $sqlServerSvcAcct,`
                                 $sqlServerSvcAcctPwd,`
                                 $sqlAgentSvcAcct,`
                                 $sqlAgentSvcAcctPwd
                                
    # Disable Util server as the CredSSP Client
    Disable-WSManCredSSP -Role Client

    Write-Host "Disabled current VM as CredSSP Client"

    # Disable the target VM as the CredSSP Server
    Invoke-Command -ComputerName $vm -Credential $cred -ScriptBlock { Disable-WSManCredSSP -Role Server }

    Write-Host "Disabled target VM as CredSSP Server"

} catch {

    $ErrorMessage = $_.Exception.Message
    
    Write-Host "Install-SQLServer.ps1 failed with the following error message:"
    Write-Host "$ErrorMessage"

}