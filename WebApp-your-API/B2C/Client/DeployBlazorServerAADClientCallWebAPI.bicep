/**
 * Begin commands to execute this file using Azure CLI with PowerShell
 * $name='DeployBlazorServerAADClientCallWebAPI'
 * $rg="rg_$name"
 * $loc='westus2'
 * az.cmd group create --location $loc --resource-group $rg 
 * az.cmd deployment group create --name $name --resource-group $rg   --template-file DeployBlazorServerAADClientCallWebAPI.bicep    --parameters accountName=siegfriedsqldavidemauri002westus2 ownerId=$env:AZURE_OBJECTID
 * End commands to execute this file using Azure CLI with Powershell
 */



@description('Location for all resources')
param location string=resourceGroup().location

@description('Cosmos DB account name, max length 44 characters')
param accountName string = toLower('sql-rbac-${uniqueString(resourceGroup().id)}')

@description('Friendly name for the SQL Role Definition')
param roleDefinitionName string = 'My Read Write Role'

@description('Data actions permitted by the role definition')
param dataActions  array = [
  'Microsoft.DocumentDB/databaseAccounts/readMetadata'
  'Microsoft.DocumentsDB/databaseAccounts/sqlDatabases/containers/items/*'
]

@description('Object ID of AAD identity. Must be a GUID')
param principalId string

var locations=[
  {
    locationName: location
    failoverPriority: 0
    isZoneRedundant: false
  }
]


