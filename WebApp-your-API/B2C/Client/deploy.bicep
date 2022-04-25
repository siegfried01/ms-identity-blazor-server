/*
 * Begin commands to execute this file using Azure CLI with PowerShell
 * echo WaitForBuildComplete
 * WaitForBuildComplete
 * $name='AADB2C_BlazorServerDemo'
 * $rg="rg_$name"
 * $loc='westus2'
 * echo az.cmd group create --location $loc --resource-group $rg 
 * az.cmd group create --location $loc --resource-group $rg 
 * echo Set-AzDefault -ResourceGroupName $rg 
 * Set-AzDefault -ResourceGroupName $rg
 * echo begin create deployment group
 * az.cmd identity create --name umid-cosmosid --resource-group $rg --location $loc
 * $MI_PRINID=$(az identity show -n umid-cosmosid -g $rg --query "principalId" -o tsv)
 * write-output "principalId=${MI_PRINID}"
 * az.cmd deployment group create --name $name --resource-group $rg   --template-file deploy.bicep  --parameters '@deploy.parameters.json' --parameters managedIdentityName=umid-cosmosid ownerId=$env:AZURE_OBJECTID --parameters principalId=$MI_PRINID
 * $accountName="cosmos-xyfolxgnipoog"
 * $webappname="xyfolxgnipoogweb" 
 * $appId=(Get-AzWebApp -ResourceGroupName $rg -Name $webappname).Identity.PrincipalId
 * echo $appId
 * $accountName="cosmos-xyfolxgnipoog"
 * New-AzCosmosDBSqlRoleDefinition -AccountName $accountName `
 *     -ResourceGroupName $rg `
 *     -Type CustomRole -RoleName SiegReadWriteRole007 `
 *     -DataAction @( `
 *         'Microsoft.DocumentDB/databaseAccounts/readMetadata',
 *         'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*', `
 *         'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*') `
 *     -AssignableScope "/"
 * $idRole=$(az.cmd cosmosdb sql role definition list --account-name $accountName --resource-group $rg -o tsv --query [0].id)
 * echo idRole=$idRole
 * New-AzCosmosDBSqlRoleAssignment -AccountName $accountName -ResourceGroupName $rg -RoleDefinitionId $idRole -Scope "/dbs/rbacsample" -PrincipalId $appId
 * az.cmd cosmosdb sql role definition list --account-name $accountName --resource-group $rg
 * az.cmd cosmosdb sql role assignment list --account-name $accountName --resource-group $rg
 * Get-AzResource -ResourceGroupName $rg | ft
 * echo end create deployment group
 * End commands to execute this file using Azure CLI with Powershell
 *
 * Begin commands to execute this file using Azure CLI with PowerShell
 * echo CreateBuildEvent.exe
 * CreateBuildEvent.exe&
 * $name='AADB2C_BlazorServerDemo'
 * $rg="rg_$name"
 * $loc='westus2'
 * Get-AzResource -ResourceGroupName $rg -ResourceType Microsoft.KeyVault | ft
 * $kv=$(Get-AzResource -ResourceGroupName $rg -ResourceType Microsoft.KeyVault/vaults  |  Select-Object -ExpandProperty Name)
 * Write-Output "kv=$kv"
 * echo az.cmd group delete --name $rg --yes
 * az.cmd group delete --name $rg --yes
 * write-output "az.cmd keyvault purge --name $kv --location $loc --no-wait"
 * az.cmd keyvault purge --name $kv --location $loc --no-wait
 * BuildIsComplete.exe
 * echo all done
 * End commands to execute this file using Azure CLI with Powershell
 */

 @description('Are we using VNET to protect database?')
 param useVNET bool = false

@description('AAD Object ID of the developer so s/he can access key vault when running on development')
param ownerId string
@description('Principal ID of the managed identity')
param principalId string
@description('The base name for resources')
param name string = uniqueString(resourceGroup().id)

@description('The location for resources')
param location string = resourceGroup().location

@description('Cosmos DB Configuration [{key:"", value:""}]')
param cosmosConfig object
@description('Azure AD B2C Configuration [{key:"", value:""}]')
param aadb2cConfig object

@description('Azure AD B2C App Registration client secret')
@secure()
param clientSecret string

@description('Azure AD B2C App Cosmos Account Key')
@secure()
param cosmosAccountKey string

@description('Azure AD B2C App Cosmos End Point')
@secure()
param cosmosEndPoint string


@description('The web site hosting plan')
@allowed([
  'F1'
  'D1'
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1'
  'P2'
  'P3'
  'P4'
])
param sku string = 'F1'

@description('The App Configuration SKU. Only "standard" supports customer-managed keys from Key Vault')
@allowed([
  'free'
  'standard'
])
param configSku string = 'free'

// begin VNET params
@description('Virtual network name')
param virtualNetworkName string ='vnet-${uniqueString(resourceGroup().id)}'

@description('Cosmos DB account name (must contain only lowercase letters, digits, and hyphens)')
@minLength(3)
@maxLength(44)
param cosmosAccountName string = 'cosmos-${uniqueString(resourceGroup().id)}'

@description('Enable public network traffic to access the account; if set to Disabled, public network traffic will be blocked even before the private endpoint is created')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

//@description('Private endpoint name')
//param privateEndpointName string='cosmosPrivateEndpoint'

var subnetName = 'default'

// end VNET params


resource config 'Microsoft.AppConfiguration/configurationStores@2020-06-01' = {
  name: 'asc-${name}config'
  location: location
  sku: {
    name: configSku
  }

  resource Aadb2cConfigValues 'keyValues@2020-07-01-preview' = [for item in items(aadb2cConfig): {
    name: 'AzureAdB2C:${item.key}'
    properties: {
      value: item.value
    }
  }]
  resource CosmosConfigValues 'keyValues@2020-07-01-preview' = [for item in items(cosmosConfig): {
    name: 'CosmosConfig:${item.key}'
    properties: {
      value: item.value
    }
  }]

  resource cosmosUri 'keyValues@2020-07-01-preview'={
    name: 'CosmosConfig:uri'
    properties: {
      value:  cosmosDbAccount.properties.documentEndpoint
    }
  }
/*
  resource cosmosFQDN 'keyValues@2020-07-01-preview'= if (useVNET) {
    name: 'CosmosConfig:fqdn'
    properties: {
      value:  privateEndpointName_resource.properties.subnet.name
    }
  }
*/


  resource aadb2cClientSecret 'keyValues@2020-07-01-preview' = {
    // Store secrets in Key Vault with a reference to them in App Configuration e.g., client secrets, connection strings, etc.
    name: 'AzureAdB2C:ClientSecret'
    properties: {
      // Most often you will want to reference a secret without the version so the current value is always retrieved.
      contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
      value: '{"uri":"${kvaadb2cSecret.properties.secretUri}"}'
    }
  }

  resource cosmosConnectionStringSecret 'keyValues@2020-07-01-preview' = {
    // Store secrets in Key Vault with a reference to them in App Configuration e.g., client secrets, connection strings, etc.
    name: 'CosmosConnectionStringSecret'
    properties: {
      // Most often you will want to reference a secret without the version so the current value is always retrieved.
      contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
      value: '{"uri":"${kvCosmosConnectionStringSecret.properties.secretUri}"}'
    }
  }
  resource cosmosAccountKeySecret 'keyValues@2020-07-01-preview' = {
    // Store secrets in Key Vault with a reference to them in App Configuration e.g., client secrets, connection strings, etc.
    name: 'CosmosAccountKeySecret'
    properties: {
      // Most often you will want to reference a secret without the version so the current value is always retrieved.
      contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
      value: '{"uri":"${kvCosmosAccountKeySecret.properties.secretUri}"}'
    }
  }
  resource cosmosEndPointSecret 'keyValues@2020-07-01-preview' = {
    // Store secrets in Key Vault with a reference to them in App Configuration e.g., client secrets, connection strings, etc.
    name: 'CosmosEndPointSecret'
    properties: {
      // Most often you will want to reference a secret without the version so the current value is always retrieved.
      contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
      value: '{"uri":"${kvCosmosEndPointSecret.properties.secretUri}"}'
    }
  }
}

resource kv 'Microsoft.KeyVault/vaults@2019-09-01' = {
  // Make sure the Key Vault name begins with a letter.
  name: 'kv-${name}'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: ownerId
        permissions:{
          secrets:[
            'all'
          ]
        }
      }
      {
        tenantId: subscription().tenantId
        objectId: web.identity.principalId
        permissions: {
          // Secrets are referenced by and enumerated in App Configuration so 'list' is not necessary.
          secrets: [
            'get'
          ]
        }
      }
      {
        tenantId: subscription().tenantId
        objectId: principalId
        permissions: {
          // Secrets are referenced by and enumerated in App Configuration so 'list' is not necessary.
          secrets: [
            'get'
          ]
        }
      }
    ]
  }
}

// Separate resource from parent to reference in configSecret resource.
resource kvaadb2cSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${kv.name}/AzureAdB2CClientSecret'
  properties: {
    value: clientSecret
  }
}

resource kvCosmosConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${kv.name}/CosmosConnectionStringSecret'
  properties: {
    value: cosmosDbAccount.listConnectionStrings().connectionStrings[0].connectionString
  }
}

resource kvCosmosEndPointSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${kv.name}/CosmosEndPointSecret'
  properties: {
    value: cosmosEndPoint
  }
}
resource kvCosmosAccountKeySecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${kv.name}/CosmosAccountKeySecret'
  properties: {
    value: cosmosAccountKey
  }
}

resource plan 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: '${name}plan'
  location: location
  sku: {
    name: sku
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

@description('Specifies managed identity name')
param managedIdentityName string
resource msi 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30'  existing = {
  name: managedIdentityName
}
// https://github.com/Azure/azure-quickstart-templates/blob/master/quickstarts/microsoft.web/web-app-managed-identity-sql-db/main.bicep#L73
resource web 'Microsoft.Web/sites@2020-12-01' = {
  name: '${name}web'
  location: location
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${msi.id}': {}
    }
  }
  properties: {
    httpsOnly: true
    serverFarmId: plan.id
    siteConfig: {
      appSettings: [ // https://github.com/Azure/azure-quickstart-templates/blob/master/quickstarts/microsoft.web/documentdb-webapp/main.bicep
        {
          name: 'DOCUMENTDB_ENDPOINT'
          value: cosmosDbAccount.properties.documentEndpoint
        }
        {
          name: 'DOCUMENTDB_PRIMARY_KEY'
          value: cosmosDbAccount.listKeys().primaryMasterKey
        }
      ]
      linuxFxVersion: 'DOTNETCORE|6'
      connectionStrings: [
        {
          name: 'AppConfig'
          connectionString: listKeys(config.id, config.apiVersion).value[0].connectionString
        }
      ]
    }
  }
}

output appConfigConnectionString string = listKeys(config.id, config.apiVersion).value[0].connectionString
// output siteUrl string = 'https://${web.properties.defaultHostName}/'
output vaultUrl string = kv.properties.vaultUri
var dbName = 'rbacsample'
var containerName = 'data'
// Cosmos DB Account
resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2021-06-15' = {
  name: cosmosAccountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    disableLocalAuth: false // switch to 'true', if you want to disable connection strings/keys 
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    publicNetworkAccess: publicNetworkAccess
    enableMultipleWriteLocations: false
  }
}
// Cosmos DB
resource cosmosDbDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-06-15' = {
  name: '${cosmosDbAccount.name}/${dbName}'
  location: location
  properties: {
    resource: {
      id: dbName
    }
  }
}
// Data Container
resource containerData 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-06-15' = {
  name: '${cosmosDbDatabase.name}/${containerName}'
  location: location
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: [
          '/partitionKey'
        ]
        kind: 'Hash'
      }
    }
  }
}
var principals =   [ 
  principalId
  ownerId
]
@batchSize(1)
module cosmosRole 'cosmosRole.bicep' = [for (princId, jj) in principals: {
  name: 'cosmos-role-definition-and-assignment-${jj}'
  params: {
//    cosmosDbAccount: cosmosDbAccount
    cosmosDbAccountId: cosmosDbAccount.id
    cosmosDbAccountName: cosmosDbAccount.name
    principalId: princId
    it: jj
  }
}]
// var roleDefId = guid('sql-role-definition-', principalId, cosmosDbAccount.id)
// var roleDefName = 'Custom Read/Write role'
// var roleAssignId = guid(roleDefId, principalId, cosmosDbAccount.id)
// resource roleDefinition 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2021-06-15' = {
//   name: '${cosmosDbAccount.name}/${roleDefId}'
//   properties: {
//     roleName: roleDefName
//     type: 'CustomRole'
//     assignableScopes: [
//       cosmosDbAccount.id
//     ]
//     permissions: [
//       {
//         dataActions: [
//           'Microsoft.DocumentDB/databaseAccounts/readMetadata'
//           'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*'
//         ]
//       }
//     ]
//   }
// }
// resource roleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-06-15' = {
//   name: '${cosmosDbAccount.name}/${roleAssignId}'
//   properties: {
//     roleDefinitionId: roleDefinition.id
//     principalId: principalId
//     scope: cosmosDbAccount.id
//   }
// }


// begin VNET resources
resource virtualNetworkName_resource 'Microsoft.Network/virtualNetworks@2020-06-01'  = if (useVNET) {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '172.20.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '172.20.0.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}
/*
resource privateEndpointName_resource 'Microsoft.Network/privateEndpoints@2020-07-01' =  if (useVNET) {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/VirtualNetworks/subnets', virtualNetworkName, subnetName)
    }
    privateLinkServiceConnections: [
      {
        name: 'MyConnection'
        properties: {
          privateLinkServiceId: cosmosDbAccount.id
          groupIds: [
            'Sql'
          ]
        }
      }
    ]
  }
}
*/
// end VNET resources
