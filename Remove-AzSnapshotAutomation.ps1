<#
    .SYNOPSIS
        Within an Azure subscription, this script automatically deletes manual snapshots older than 3 days.
    .DESCRIPTION
        This script is deployed via Bicep, in the form of a PowerShell Runbook under an Automation Account running on a recurring schedule.
        The Automation Account requires a system assigned managed identity. The identity requires 'Disk Snapshot Contributor' RBAC permissions assigned to the tenant's Azure subscription.
        It first initialises the connection to Azure with the system managed identity. 
        If you are running this script ad-hoc and not in the context of a runbook, simply comment out the initialisations, and run Connect-AzAccount and sign in as a tenant admin with appropriate RBAC permissions, prior to running script.
        The script gets and iterates through all Azure snapshots. If the snapshot meets the conditions (created 3+ days ago and does not have the excusion Azure Tags applied (snapshotLock : doNotDelete)), it then deletes the snapshot.
    .NOTES
        AUTHOR: Christopher Cooper
#>

#-------------------[INITIALISATIONS]-------------------#

# Ensures no AzContext is inherited
Disable-AzContextAutosave -Scope Process
# Connect to Azure with system-assigned managed identity
$azureContext = (Connect-AzAccount -Identity).context
# Set and store context
$azureContext = Set-AzContext -SubscriptionName $azureContext.Subscription -DefaultProfile $azureContext

####----------------[SCRIPT]----------------####

# Get all snapshots
$snapshots = Get-AzSnapshot
# Iterate through each snapshot
foreach($snapshot in $snapshots) {
    # Get snapshot's Azure tags
    $snapshotTags = (Get-AzResource -Name $snapshot.Name).Tags
    # If snapshot is 3+ days old and does not have the Azure tag to exclude from deletion
    if ($snapshot.TimeCreated -lt ([datetime]::UtcNow.AddDays(-3)) -and $snapshotTags.snapshotLock -ne 'doNotDelete') {       
        # Delete snapshot
        Write-Output "Deleting snapshot $($snapshot.Name)"
        Get-AzSnapshot -SnapshotName $snapshot.Name | Remove-AzSnapshot -Verbose -Force
    }
}