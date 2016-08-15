﻿# Loop through each NIC to create the job to set private IP addresses to static, and start the job
$vmResourceGroupName = "powershellLearning"
#$nics = Get-AzureRmNetworkInterface -ResourceGroupName $vmResourceGroupName | Where-Object {$_.Name -like "vm*"}
$nics = Get-AzureRmPublicIpAddress -ResourceGroupName $vmResourceGroupName | Where-Object {$_.Name -like "vm*"}
#$nics = Get-AzureRmVM -ResourceGroupName $vmResourceGroupName | Where-Object {$_.Name -like "vm*"}
$i = 1
$offset = 1
$count = ($nics | measure).Count

$ErrorActionPreference = 'Stop'

foreach ($nic in $nics){
        
    # Define the script block that will be executed in each block
    $scriptBlock = { 
        # Define the paratemers to be passed to this script block
        Param($nic) 

        try{
            Import-Module AzureRM.Network
            #$nic | Remove-AzureRmNetworkInterface -Force
            $nic | Remove-AzureRmPublicIpAddress -Force
            #$nic | Remove-AzureRmVM -Force
        } catch {
            $ErrorMessage = $_.Exception.Message
            Write-Host "Failed with the following message:" -BackgroundColor Black -ForegroundColor Red
            throw "$ErrorMessage"
        }
    } 
        
    # Create a new PowerShell object and store it in a variable
    New-Variable -Name "psSessionRem-$i" -Value ([PowerShell]::Create())

    # Add the script block to the PowerShell session, and add the parameter values
    (Get-Variable -Name "psSessionRem-$i" -ValueOnly).AddScript($scriptBlock).AddArgument($nic) | Out-Null

    Write-Host "Starting job to remove NIC $($nic.Name)..."
    
    # Start the execution of the script block in the newly-created PowerShell session, and save its execution in a new variable as job
    New-Variable -Name "jobRem-$i" -Value ((Get-Variable -Name "psSessionRem-$i" -ValueOnly).BeginInvoke())

    $i++
}


# Logic waiting for the jobs to complete
$jobsRunning=$true 
while($jobsRunning){
        
    # Reset counter for number of jobs still running
    $runningCount=0 
 
    # Loop through all jobs
    foreach ($i in $offset..$count){ 
            
        if(   !(Get-Variable -Name "jobRem-$i" -ValueOnly).IsCompleted   ){ 
            # If the PowerShell command being executed is not completed, increase the counter for number of jobs still running
            $runningCount++ 
        } 
        else{ 
            # If the PowerShell command has been completed, store the results of the job in the psSession variable, and then 
            # release all resources of the PowerShell object
            (Get-Variable -Name "psSessionRem-$i" -ValueOnly).EndInvoke((Get-Variable -Name "jobRem-$i" -ValueOnly))
            (Get-Variable -Name "psSessionRem-$i" -ValueOnly).Dispose()
        } 
    } 
        
    # If there are no more running jobs, set while-loop flap to end
    if ($runningCount -eq 0){ 
        $jobsRunning=$false 
    } 
 
    Write-Host "Jobs remaining: $runningCount out of $count"
    Start-Sleep -Seconds 5
}


# Delete all the variables holding jobs and PowerShell sessions
foreach ($i in $offset..$count){
    
    Remove-Variable -Name "psSessionRem-$i"
    Remove-Variable -Name "jobRem-$i"
}