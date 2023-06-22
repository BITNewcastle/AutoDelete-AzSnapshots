<#
    .SYNOPSIS
        Automatically deletes all snapshots in an Azure tenant older than 3 days.

    .DESCRIPTION
        This script is deployed in the form of an Azure Runbook under an Automation Account, running on a recurring schedule.
        The Automation Account requires a system assigned managed identity. The identity requires 'Disk Snapshot Contributor' RBAC permissions assigned to the tenant's Azure subscription.
        It first initialises the connection to Azure with the system managed identity. 
        If you are running this script ad-hoc and not in the context of a runbook, simply comment out the initialisations, and run Connect-AzAccount and sign in as a tenant admin with appropriate RBAC permissions, prior to running script.
        The script gets and iterates through all Azure snapshots. If the snapshot meets the conditions (created 3+ days ago and does not contain the 'exclude from deletion' Azure Tags (Mark4Deletion : No)), it then deletes the snapshot.

    .NOTES
        AUTHOR: Christopher Cooper
#>

#-------------------[INITIALISATIONS]-------------------#

# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process
# Connect to Azure with system-assigned managed identity
$AzureContext = (Connect-AzAccount -Identity).context
# Set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext


####----------------[SCRIPT]----------------####

# Get all snapshots
$Snapshots = Get-AzSnapshot
# Iterate through each snapshot
Foreach($Snapshot in $Snapshots)
{
    # Get snapshot's Azure tags
    $SnapshotResource = Get-AzResource -Name $Snapshot.Name
    $Tags = $SnapshotResource.Tags
    # If snapshot is 3+ days old and does not have the Azure tag to exclude from deletion
    If ($Snapshot.TimeCreated -lt ([datetime]::UtcNow.AddDays(-3)) -and $tags.snapshotLock -ne 'canNotDelete')
    {       
        Write-Output "$($resource.Name) is being deleted"
        # Delete snapshot
        Get-AzSnapshot -SnapshotName $Snapshot.Name | Remove-AzSnapshot -Force    
    }
}