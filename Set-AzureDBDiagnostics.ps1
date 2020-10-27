
<#
.SYNOPSIS
    Runbook to enable diagnostics on SQL databases for use in OMS.

.DESCRIPTION
    This runbook is enabling the diagnostics settings on SQL databases for analysis in OMS. 
    It is possible to run this on a single database, a single SQL server or for all SQL databases

.PARAMETER SQLDatabase
    The name of the Datase that will have diagnostics enabled. Leave blank if all databases.
    This setting is optional. If no SQL database is selected, it will enable on all databases.

.PARAMETER SQLServer
    Name of the SQL server where the database(s) are stored. Leave blank for all servers.
    This setting is optional. If no SQL server is selected, it will enable on all SQL servers.

.PARAMETER OMSWorkspace
    OMS workspace where the diagnostics should be forwarded to.

.PARAMETER SQLResourceGroup 
    Resourcegroup where the SQL server(s) are located.

.PARAMETER SQLSubscriptionID
    SubscriptionID for the server(s)

.PARAMETER AutomationAccount
    Azure Automation account 

.PARAMETER OMSResourceGroup
    Resource group for the OMS
    

#>

param (
    [Parameter()][string]$SQLDatabase,
    [Parameter()][string]$SQLServer,
    [Parameter(Mandatory=$true)][string]$OMSWorkspaceName,
    [Parameter(Mandatory=$true)][string]$SQLResourceGroup,
    [Parameter(Mandatory=$true)][string]$OMSResourceGroup,
    [Parameter(Mandatory=$true)][string]$SQLSubscriptionId,
    [Parameter(Mandatory=$true)][string]$AutomationAccount
    
)

## Getting credentials
$Credentials = Get-AutomationPSCredential -Name $Automationaccount

## Login to Azure
write-Output "Logging into Azure"
Add-AzureRmAccount -Credential $Credentials 
Write-Output "Setting Context"
Set-AzureRmContext -subscriptionid $SQLSubscriptionId

#If only one SQLServer is selected
if($SQLServer)
{
    [string[]]$ServerList = $SQLServer
}
else
{
    $ServerList = (Get-AzureRmSqlServer).ServerName
}



#Get OMS workspaceid
$OmsWorkspaceID = Get-AzureRmOperationalInsightsWorkspace -ResourceGroupName $OMSResourceGroup -Name $OMSWorkspaceName

foreach($SqlSrv in $ServerList)
{

    #Getting the DB's and activating.
    Write-Output "Getting list of databases"

    #If only one DB is selected
    if($SQLDatabase)
    {
        $DatabaseList = Get-AzureRmSqlDatabase -ServerName $SqlSrv -DatabaseName $SQLDatabase -ResourceGroupName $SQLResourceGroup
    }
    else
    {
        $DatabaseList = Get-AzureRmSqlDatabase -ServerName $SqlSrv -ResourceGroupName $SQLResourceGroup
    }

    
    Write-Output "Looping databases and enabling those not enabled"
    foreach($db in $DatabaseList)
    {
    Write-Output $db.DatabaseName

        #If diagnostics is not enabled - enable!
        if((Get-AzureRmDiagnosticSetting -ResourceId $db.ResourceId).Metrics.Enabled -eq $false)
        {
            Write-Output $db.DatabaseName " is not enabled. Enabling"
    
            try {
                Set-AzureRmDiagnosticSetting -workspaceid $OMSWorkspaceID.ResourceId -Enabled $true -ResourceId $db.ResourceId -Verbose
                Write-Output "Enabled"
            }
            catch {
                Write-Output "Something went wrong with updating " $db.DatabaseName
            }
    
        }

    }

}


