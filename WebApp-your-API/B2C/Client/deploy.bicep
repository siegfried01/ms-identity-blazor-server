/*
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
 * echo begin delete 
 * az.cmd deployment group create --mode complete --template-file ./clear-resources.json --resource-group rg_AADB2C_BlazorServerDemo
 * Get-AzResource -ResourceGroupName $rg | ft
 * write-output "begin purge key vault"
 * write-output "az.cmd keyvault purge --name $kv --location $loc --no-wait"
 * az.cmd keyvault purge --name $kv --location $loc --no-wait
 * BuildIsComplete.exe
 * echo all done
 * End commands to execute this file using Azure CLI with Powershell
 */

 @description('Azure Sql Server Admin Password')
 @secure()
 param azureSqlServerAdminPassword string

 @description('Are we using VNET to protect database?')
 param useVNet1 bool = true
 param useVNet2 bool = false

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
param webPlanSku string = useVNet1?'S1':'F1'

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

@description('Private endpoint name')
param privateEndpointName string='cosmosPrivateEndpoint'

param subnetCosmos string = 'subnetCosmos'
param subnetWebsite string = 'subnetWebsite'
param virtualNetworks_vnet_xyfolxgnipoog_externalid string = '/subscriptions/acc26051-92a5-4ed1-a226-64a187bc27db/resourceGroups/rg_AADB2C_BlazorServerDemo/providers/Microsoft.Network/virtualNetworks/${virtualNetworkName}'

param privateDnsZones_dns_aadb2c_blazorserverdemo_name string = 'dns_aadb2c.blazorserverdemo'
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

/*
virtualNetworkSubnetId (see below in resource webApp) is causing this error:

ERROR: {"status":"Failed","error":{"code":"DeploymentFailed","message":"At least one resource deployment operation failed. Please list deployment operations for details. Please see https://aka.ms/DeployOperations for usage details.","details":[{"code":"BadRequest","message":"{
  "Code": "BadRequest",
  "Message": "Subnet vnet-xyfolxgnipoog in VNET subnetWebsite is missing a delegation to Microsoft.Web/serverFarms. Please add the delegation and try again.",
  "Target": null,
  "Details": [
    {
      "Message": "Subnet vnet-xyfolxgnipoog in VNET subnetWebsite is missing a delegation to Microsoft.Web/serverFarms. Please add the delegation and try again."
    },
    {
      "Code": "BadRequest"
    },
    {
      "ErrorEntity": {
        "ExtendedCode": "55928",
        "MessageTemplate": "Subnet {0} in VNET {1} is missing a delegation to {2}. Please add the delegation and try again.",
        "Parameters": [
          "vnet-xyfolxgnipoog",
          "subnetWebsite",
          "Microsoft.Web/serverFarms"
        ],
        "Code": "BadRequest",
        "Message": "Subnet vnet-xyfolxgnipoog in VNET subnetWebsite is missing a delegation to Microsoft.Web/serverFarms. Please add the delegation and try again."
      }
    }
  ],
  "Innererror": null
}"}]}}


*/


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
    httpsOnly: true         // https://stackoverflow.com/questions/54534924/arm-template-for-to-configure-app-services-with-new-vnet-integration-feature/59857601#59857601
    serverFarmId: plan.id   
    // This does the VNET integration for S1
     //virtualNetworkSubnetId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().id}/providers/Microsoft.Network/virtualNetworks/${VirtualNetwork.name}/subnets/${subnetWebsite}'
     // /subscriptions/acc26051-92a5-4ed1-a226-64a187bc27db/resourceGroups/rg_AADB2C_BlazorServerDemo/providers/Microsoft.Network/virtualNetworks/vnet-xyfolxgnipoog

    virtualNetworkSubnetId: '${virtualNetworks_vnet_xyfolxgnipoog_externalid}/subnets/subnetWebsite'
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



// begin Sql Database
// end Sql Database

var principals =   [ 
  principalId
  ownerId
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


// Access from azure webapp to cosmos DB was working via RBAC and then added AnuragSharma-MSFT's script to constrain access cosmos database via VNET.
// New error message: 2022 April 25 22:59:57.1890 (Mon): Response status code does not indicate success: Forbidden (403); Substatus: 0; ActivityId: 36b85649-d9e4-493f-9755-8aef38a9db47; Reason: (Request originated from IP 20.69.64.79 through public internet. This is blocked by your Cosmos DB account firewall settings. More info: https://aka.ms/cosmosdb-tsg-forbidden ActivityId: 36b85649-d9e4-493f-9755-8aef38a9db47, Microsoft.Azure.Documents.Common/2.14.0, Linux/10 cosmos-netstandard-sdk/3.24.1);
//                    2022 April 26 01:35:06.7308 (Tue): Response status code does not indicate success: Forbidden (403); Substatus: 0; ActivityId: 84239951-6e27-4e84-b08f-4e0d5f5c97d6; Reason: (Request originated from IP 20.72.222.133 through public internet. This is blocked by your Cosmos DB account firewall settings. More info: https://aka.ms/cosmosdb-tsg-forbidden ActivityId: 84239951-6e27-4e84-b08f-4e0d5f5c97d6, Microsoft.Azure.Documents.Common/2.14.0, Linux/10 cosmos-netstandard-sdk/3.24.1);
// Perhaps the problem is that I'm not including the VNET? How do I do that?
//
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
        name: subnetCosmos
        properties: {
          addressPrefix: '172.20.0.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: subnetWebsite
        properties: {
          addressPrefix: '172.20.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource privateEndpointName_resource 'Microsoft.Network/privateEndpoints@2020-07-01' =  if (useVNet1) {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/VirtualNetworks/subnets', virtualNetworkName, subnetCosmos)
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

// ERROR: {"status":"Failed","error":{"code":"DeploymentFailed","message":"At least one resource deployment operation failed. Please list deployment operations for details. Please see https://aka.ms/DeployOperations for usage details.","details":[{"code":"PreconditionFailed","message":"{
//  "code": "PreconditionFailed",
//  "message": "There is already an operation in progress which requires exclusive lock on this service cosmos-xyfolxgnipoog. Please retry the operation after sometime.
// ActivityId: 3c6f5526-a67a-4908-8cd9-c4bb6533ba20, Microsoft.Azure.Documents.Common/2.14.0"

resource privateDnsZones_dns_aadb2c_blazorserverdemo_name_resource 'Microsoft.Network/privateDnsZones@2018-09-01' = if (useVNet1){
  name: privateDnsZones_dns_aadb2c_blazorserverdemo_name
  location: 'global'
  properties: {
  }
}

resource Microsoft_Network_privateDnsZones_SOA_privateDnsZones_dns_aadb2c_blazorserverdemo_name 'Microsoft.Network/privateDnsZones/SOA@2018-09-01' = if (useVNet1){
  parent: privateDnsZones_dns_aadb2c_blazorserverdemo_name_resource
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

resource privateDnsZones_dns_aadb2c_blazorserverdemo_name_virtnetlnk001 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = if (useVNet1){
  parent: privateDnsZones_dns_aadb2c_blazorserverdemo_name_resource
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
