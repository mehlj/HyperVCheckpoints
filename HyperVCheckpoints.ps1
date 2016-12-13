<#

.SYNOPSIS
    Automated Hyper-V VM restarts/checkpoints


.DESCRIPTION
    Performs a full reboot of all local Hyper-V VMs (save exempted VMs), and creates a new checkpoint for each VM. This script is best used with a scheduled task (nightly or weekly, etc.) running on a local Hyper-V server


.PARAMETER ExemptVMNames
    Comma separated names of VMs which should not be shutdown and for which checkpoints should not be created. 


.EXAMPLE
    .\AlphanumericComboGenerator.ps1


.EXAMPLE
    .\AlphanumericComboGenerator.ps1 -ExemptVMNames TestVM1, TestVM2, TestVM3

    TestVM1, TestVM2, and TestVM3 will not be powered off and checkpoints will not be created.


.NOTES
    Author: Justen Mehl, 
            mehlsec.com
            @mehlsec
            
    Created on: 13 December 2016
    Last Updated: 13 December 2016
    
#>


Param(
    [Parameter(Mandatory=$false)][String[]]$ExemptVMNames
)


$date = Get-Date -format g
$VMTotal = Get-VM
$isExempt = $false


# loop through all VMs
foreach ($VM in $VMTotal)
{
   
    $CheckpointName = $VM.Name + "_" + $date
    $VMName = $VM.VMName

    # loop through input array and see whether this VM is exempted or not
    foreach ($name in $ExemptVMNames)
    {
        if($VMName -eq $name)
        {
            $isExempt = $true
        }
    }   


    if (!($isExempt))
    {
        # shut down VM if it is running
        if ($VM.State -eq "Running")
        {
            Write-Host "$VMName is currently powered on. Safely powering off $VMName..."

            Stop-VM -Name $VMName -Force

            # loop until VM is powered off fully
            While ($VM.State -ne "Off")
            {
                Write-Progress -Activity "Waiting for $VMName to shutdown properly..."
                Start-Sleep -Milliseconds 200
            }

            Write-Host "$VMName is now powered off" -ForegroundColor Cyan
        }

    
        # delete checkpoints older than 60 days
        Write-Host "Deleting all $VMName checkpoints older than 60 days..." 
        $OldCheckpoints = Get-VMSnapshot -VMName $VMName | Where-Object {$_.CreationTime -lt (Get-Date).AddDays(-60)}
        $OldCheckpoints | Remove-VMSnapshot -VMName $VMName

        # create new checkpoint
        Write-Host "Creating checkpoint for $VMName..." 
        Checkpoint-VM -Name $VMName -SnapshotName $CheckpointName

        # powering on VM
        Write-Host "Powering on $VMName...`n"
        Start-VM -Name $VMName 

        # reset value of isExempt
        $isExempt = $false
    }

    else
    {
        Write-Host "$VMName has been exempted, moving onto the next VM...`n" -ForegroundColor Cyan
        
        # reset value of isExempt
        $isExempt = $false
    }
    
} # end foreach

exit
