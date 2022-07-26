/*
 *
 * emacs 1: Deploy without using powsershell to assign roles to System Assigned SP and NO vnet
 * Begin commands to execute this file using Azure CLI with PowerShell
 * echo WaitForBuildComplete
 * WaitForBuildComplete
 * $name='AADB2C_BlazorServerDemo'
 * $rg="rg_$name"
 * $loc='westus2'
 * echo Set-AzDefault -ResourceGroupName $rg 
 * Set-AzDefault -ResourceGroupName $rg
 * echo begin create deployment group
 * az.cmd identity create --name umid-cosmosid --resource-group $rg --location $loc 
 * $MI_PRINID=$(az.cmd identity show -n umid-cosmosid -g $rg --query "principalId" -o tsv)
 * $MI_CLIENTID=$(az.cmd identity show -n umid-cosmosid -g $rg --query "clientId" -o tsv)
 * write-output "principalId=${MI_PRINID} MI_CLIENTID=${MI_CLIENTID}"
 * write-output "az.cmd deployment group create --name $name --resource-group $rg   --template-file deploy.bicep"
 * az.cmd deployment group create --name $name --resource-group $rg   --template-file deploy.bicep  --parameters '@deploy.parameters.json' --parameters useVNet1=true managedIdentityName=umid-cosmosid ownerId=$env:AZURE_OBJECTID --parameters principalId=$MI_PRINID clientId=$MI_CLIENTID
 * $accountName="xyfolxgnipoog-cosmosdb"
 * write-output "az.cmd cosmosdb sql role definition list --account-name $accountName --resource-group $rg"
 * az.cmd cosmosdb sql role definition list --account-name $accountName --resource-group $rg
 * write-output "az.cmd cosmosdb sql role assignment list --account-name $accountName --resource-group $rg"
 * az.cmd cosmosdb sql role assignment list --account-name $accountName --resource-group $rg
 * Get-AzResource -ResourceGroupName $rg | ft
 * echo end create deployment group
 * End commands to execute this file using Azure CLI with Powershell
 *
 * emacs 2: Shutdown website & database
 * Begin commands to execute this file using Azure CLI with PowerShell
 * echo CreateBuildEvent.exe
 * CreateBuildEvent.exe&
 * $name='AADB2C_BlazorServerDemo'
 * $rg="rg_$name"
 * $loc='westus2'
 * Get-AzResource -ResourceGroupName $rg -ResourceType Microsoft.KeyVault | ft
 * $kv=$(Get-AzResource -ResourceGroupName $rg -ResourceType Microsoft.KeyVault/vaults  |  Select-Object -ExpandProperty Name)
 * Write-Output "kv=$kv"
 * echo begin delete 
 * az.cmd deployment group create --mode complete --template-file ./clear-resources.json --resource-group rg_AADB2C_BlazorServerDemo
 * Get-AzResource -ResourceGroupName $rg | ft
 * write-output "begin purge key vault"
 * write-output "az.cmd keyvault purge --name $kv --location $loc --no-wait"
 * az.cmd keyvault purge --name $kv --location $loc --no-wait
 * BuildIsComplete.exe
 * echo all done
 * End commands to execute this file using Azure CLI with Powershell
 *
 * emacs 3: Assign roles to System Assigned with powershell (no deployment). This is superfluous
 * Begin commands to execute this file using Azure CLI with PowerShell
 * $name='AADB2C_BlazorServerDemo'
 * $rg="rg_$name"
 * $loc='westus2'
 * $accountName="xyfolxgnipoog-cosmosdb"
 * $webappname="xyfolxgnipoog-web" 
 * $appId=(Get-AzWebApp -ResourceGroupName $rg -Name $webappname).Identity.PrincipalId
 * write-output "principalId of website= $appId"
 * New-AzCosmosDBSqlRoleDefinition -AccountName $accountName `
 *     -ResourceGroupName $rg `
 *     -Type CustomRole -RoleName SiegSystemAssignedRoles001 `
 *     -DataAction @( `
 *         'Microsoft.DocumentDB/databaseAccounts/readMetadata', `
 *         'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*', `
 *         'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*', `
 *         'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/readChangeFeed', `
 *         'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeStoredProcedure', `
 *         'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery') `
 *     -AssignableScope "/"
 * $idRole=$(az.cmd cosmosdb sql role definition list --account-name $accountName --resource-group $rg -o tsv --query [0].id)
 * echo idRole=$idRole
 * New-AzCosmosDBSqlRoleAssignment -AccountName $accountName -ResourceGroupName $rg -RoleDefinitionId $idRole -Scope "/dbs/rbacsample" -PrincipalId $appId
 * az.cmd cosmosdb sql role definition list --account-name $accountName --resource-group $rg
 * az.cmd cosmosdb sql role assignment list --account-name $accountName --resource-group $rg
 * Get-AzResource -ResourceGroupName $rg | ft
 * echo Assign roles to System Assigned with powershell
 * End commands to execute this file using Azure CLI with Powershell
 *
 */


 @description('Azure Sql Server Admin Password')
 @secure()
 param azureSqlServerAdminPassword string

 @description('Are we using VNET to protect database?')
 param useVNet1 bool = true

@description('AAD Object ID of the developer so s/he can access key vault when running on development/deskop computer')
param ownerId string

@description('Principal ID of the managed identity Service Principal (used to grant permissions to the database)')
param principalId string

@description('Client ID of the managed identity Service Principal (Passed to the ASP.NET Core app)')
param clientId string

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
param webPlanSku string = useVNet1?'S1':'F1'

@description('The App Configuration SKU. Only "standard" supports customer-managed keys from Key Vault')
@allowed([
  'free'
  'standard'
])
param configSku string = 'free'


// begin VNET params
@description('Virtual network name')
param virtualNetworkName string ='${uniqueString(resourceGroup().id)}-vnet'

@description('Cosmos DB account name (must contain only lowercase letters, digits, and hyphens)')
@minLength(3)
@maxLength(44)
param cosmosAccountName string = '${uniqueString(resourceGroup().id)}-cosmosdb'

@description('Enable public network traffic to access the account; if set to Disabled, public network traffic will be blocked even before the private endpoint is created')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Private endpoint name')
param cosmosPrivateEndpointName string='cosmosPrivateEndpoint'

param subnetWebsiteName string = 'subnetWebsite'

param privateDnsZone_name string = 'dns_aadb2c.blazorserverdemo'
param virtualLinkName string = 'vnetlink001'
param privateDnsHost string = 'azureprivatedns.net'

// end VNET params

 
@secure()
param dockerhubPassword string
param dockerUsername string = 'siegfried01'
// https://stackoverflow.com/questions/34198392/docker-official-registry-docker-hub-url get info on dockerhub
//output dockerhubCreds object = appConfigNew

resource config 'Microsoft.AppConfiguration/configurationStores@2020-06-01' = {
  name: '${name}-config'
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
  resource userAssignedPrincipalId 'keyValues@2020-07-01-preview'={  // This is now superfluous except for tutorial purposes
    name: 'userAssignedPrincipalId'
    properties: {
      value:  principalId
    }
  }

  resource userAssignedClientId 'keyValues@2020-07-01-preview'={ // This is used by default azure credential call
    name: 'userAssignedClientId'
    properties: {
      value:  clientId
    }
  }

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
  name: '${name}-kv'
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
  name: '${name}-plan'
  location: location
  sku: {
    name: webPlanSku
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
  name: '${name}-web'
  location: location
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${msi.id}': {}
    }
  }
  properties: {
    httpsOnly: true         // https://stackoverflow.com/questions/54534924/arm-template-for-to-configure-app-services-with-new-vnet-integration-feature/59857601#59857601
    serverFarmId: plan.id   
    virtualNetworkSubnetId: useVNet1 ? VirtualNetwork.properties.subnets[0].id : json('null')
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
      //linuxFxVersion: 'DOCKER|siegfried01/blazorserverclient:latest'
      linuxFxVersion: 'DOTNETCORE|6'
      connectionStrings: [
        {
          name: 'AppConfig'
          connectionString: listKeys(config.id, config.apiVersion).value[0].connectionString
        }
      ]
    }
  }

  resource logs 'config' = {
    name: 'logs'
    properties: {
      applicationLogs: {
        fileSystem: {
          level: 'Warning'
        }
      }
      httpLogs: {
        fileSystem: {
          enabled: true
        }
      }
      detailedErrorMessages: {
        enabled: true
      }
    }
  }
}


output appConfigConnectionString string = listKeys(config.id, config.apiVersion).value[0].connectionString
// output siteUrl string = 'https://${web.properties.defaultHostName}/'
output vaultUrl string = kv.properties.vaultUri
var dbName = 'rbacsample'
var containerName = 'data'
// Cosmos DB Account
resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2022-02-15-preview' = {
  name: cosmosAccountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    publicNetworkAccess: publicNetworkAccess
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    isVirtualNetworkFilterEnabled: true
    virtualNetworkRules: [
      {
        id: VirtualNetwork.properties.subnets[0].id
        ignoreMissingVNetServiceEndpoint: false
      }
    ]
    disableKeyBasedMetadataWriteAccess: false
    enableFreeTier: true
    enableAnalyticalStorage: false
    analyticalStorageConfiguration: {
      schemaType: 'WellDefined'
    }
    databaseAccountOfferType: 'Standard'
    defaultIdentity: 'FirstPartyIdentity'
    networkAclBypass: 'None'
    disableLocalAuth: false // switch to 'true', if you want to disable connection strings/keys 
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxIntervalInSeconds: 5
      maxStalenessPrefix: 100
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
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 1400 //1400/60==23.33
        backupRetentionIntervalInHours: 8
        backupStorageRedundancy: 'Local'
      }
    }
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
    options: {
      // autoscaleSettings: { maxThroughput: 400 }
      // throughput: 400 // not supported for serverless
    }
    resource: {
      id: containerName
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
      }
      partitionKey: {
        paths: [
          '/partitionKey'
        ]
        kind: 'Hash'
      }
      uniqueKeyPolicy: {
        uniqueKeys: []
      }
      conflictResolutionPolicy: {
        mode: 'LastWriterWins'
        conflictResolutionPath: '/_ts'
      }
    }
  }
}

var principals =   [ 
  principalId
  ownerId // this is for local debugging on local development computer
  // web.identity.principalId
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


// begin VNET resources

resource VirtualNetwork 'Microsoft.Network/virtualNetworks@2020-06-01'  = if (useVNet1) {
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
        name: subnetWebsiteName
        properties: {
          addressPrefix: '172.20.1.0/24'
          // steal code from https://github.com/Azure/bicep/blob/main/docs/examples/101/app-service-regional-vnet-integration/main.bicep#L37
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          networkSecurityGroup: {
            id: nsg.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.AzureCosmosDB'
              locations: [
                '*'
              ]
            }
          ]
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}
// https://docs.microsoft.com/en-us/azure/templates/microsoft.network/networksecuritygroups?tabs=bicep          
resource nsg 'Microsoft.Network/networkSecurityGroups@2020-06-01'  =  if (useVNet1) {
  name: '${name}-nsg'
  location: location
  properties: {
      securityRules: [
          {
              id: 'IdRule1'
              name: 'rule1'
                  properties: {
                  direction: 'Inbound'
                  protocol: '*'
                  sourcePortRange :  '*'
                  destinationPortRange :  '22'
                  sourceAddressPrefix :  '*'
                  destinationAddressPrefix: '*'
                  priority : 1010
                  access: 'Allow'
              }
          }
          {
              id: 'IdRule2'
              name: 'rule2'
              properties: {
                  direction: 'Outbound'
                  protocol: '*'
                  sourcePortRange :  '*'
                  destinationPortRange :  '22'
                  sourceAddressPrefix :  '*'
                  destinationAddressPrefix: '*'
                  priority : 1011
                  access: 'Allow'
              }
          }
      ]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = if (useVNet1){
  name: privateDnsZone_name
  location: 'global'
  properties: {
  }
}

resource Microsoft_Network_privateDnsZones_SOA_privateDnsZone_name 'Microsoft.Network/privateDnsZones/SOA@2018-09-01' = if (useVNet1){
  parent: privateDnsZone
  name: '@'
  properties: {
    ttl: 3600
    soaRecord: {
      email: 'azureprivatedns-host.microsoft.com'
      expireTime: 2419200
      host: privateDnsHost
      minimumTtl: 10
      refreshTime: 3600
      retryTime: 300
      serialNumber: 1
    }
  }
}

resource privateDnsZone_name_virtnetlnk001 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = if (useVNet1){
  parent: privateDnsZone
  name: virtualLinkName
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: VirtualNetwork.id
    }
  }
}

// end VNET resources
