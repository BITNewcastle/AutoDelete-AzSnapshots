<#
    .SYNOPSIS
        Within an Azure subscription, automatically deletes manual snapshots older than 3 days.
    .DESCRIPTION
        This script is deployed via Bicep, in the form of a PowerShell Runbook under an Automation Account running on a recurring schedule.
        The Automation Account requires a system assigned managed identity. The identity requires 'Disk Snapshot Contributor' RBAC permissions assigned to the tenant's Azure subscription.
        If you are running this script ad-hoc and not in the context of a runbook, simply comment out the initialisations, and run Connect-AzAccount and sign in as a tenant admin with appropriate RBAC permissions, prior to running script.
        It first initialises the connection to Azure with the system assigned managed identity.       
        It then gets and iterates through all Azure snapshots. If the snapshot meets the conditions (created 3+ days ago and does not have the excusion Azure Tags applied (snapshotLock:doNotDelete)), it then deletes the snapshot.
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
    # If snapshot is within 3 days old, report that it has been skipped
    if ($snapshot.TimeCreated -gt ([datetime]::UtcNow.AddDays(-3))) {
        Write-Output "Snapshot $($snapshot.Name) is not due for deletion yet as it is not older than 3 days, skipping snapshot"
    }
    # If snapshot is 3+ days old and has the Azure tag applied to exclude from deletion, report that it has been excluded
    if ($snapshot.TimeCreated -lt ([datetime]::UtcNow.AddDays(-3)) -and $snapshotTags.snapshotLock -eq 'doNotDelete') {
        Write-Output "Snapshot $($snapshot.Name) is due for deletion as it is older than 3 days, but was excluded. It is currently marked for exclusion from deletion via Azure tag 'snapshotLock:doNotDelete' currently applied on snapshot"
    }
    # If snapshot is 3+ days old and does not have the Azure tag applied to exclude from deletion, delete snapshot
    if ($snapshot.TimeCreated -lt ([datetime]::UtcNow.AddDays(-3)) -and $snapshotTags.snapshotLock -ne 'doNotDelete') {       
        # Delete snapshot
        Write-Output "Snapshot $($snapshot.Name) is due for deletion as it is older than 3 days, deleting snapshot"
        Get-AzSnapshot -SnapshotName $snapshot.Name | Remove-AzSnapshot -Verbose -Force
    }
}
