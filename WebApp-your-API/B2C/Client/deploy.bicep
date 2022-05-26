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
param webPlanSku string = 'F1'

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

param subnetName001 string = 'subnet001'
param subnetName002 string = 'subnet002'

// end VNET params

@secure()
param dockerhubPassword string
param dockerUsername string = 'siegfried01'

// https://stackoverflow.com/questions/34198392/docker-official-registry-docker-hub-url get info on dockerhub
output dockerhubCreds object = appConfigNew


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
    serverFarmId: plan.id   // it should look like /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/virtualNetworks/{vnetName}/subnets/{subnetName}
  //  virtualNetworkSubnetId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().id}/providers/Microsoft.Network/virtualNetworks/${virtualNetworkName_resource.name}/subnets/${subnetName}'
     //virtualNetworkSubnetId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().id}/providers/Microsoft.Network/virtualNetworks/${virtualNetworkName_resource.name}/subnets/${subnetName}'
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
      linuxFxVersion: 'DOCKER|siegfried01/demovisualstudiocicdforblazorserver:latest'
      //linuxFxVersion: 'DOTNETCORE|6'
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

var appConfigNew = {
  DOCKER_ENABLE_CI: 'true'
  DOCKER_REGISTRY_SERVER_PASSWORD: dockerhubPassword
  DOCKER_REGISTRY_SERVER_URL: 'https://index.docker.io/v1/'
  DOCKER_REGISTRY_SERVER_USERNAME: dockerUsername
}

resource appSettings 'Microsoft.Web/sites/config@2021-01-15' = {
name: 'appsettings'
parent: web
properties: appConfigNew
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
        name: subnetName001
        properties: {
          addressPrefix: '172.20.0.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: subnetName002
        properties: {
          addressPrefix: '172.20.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource privateEndpointName_resource 'Microsoft.Network/privateEndpoints@2020-07-01' =  if (useVNET) {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/VirtualNetworks/subnets', virtualNetworkName, subnetName001)
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

// end VNET resources
/*
022-05-26T13:06:22  Welcome, you are now connected to log-streaming service.
Starting Log Tail -n 10 of existing logs ----
/home/LogFiles/__lastCheckTime.txt  (https://xyfolxgnipoogweb.scm.azurewebsites.net/api/vfs/LogFiles/__lastCheckTime.txt)5/26/2022 1:05:58 PM
/home/LogFiles/kudu/trace/0fb53fc1f93b-e53b775c-56b3-40d0-83e6-14c16458c4c2.txt  (https://xyfolxgnipoogweb.scm.azurewebsites.net/api/vfs/LogFiles/kudu/trace/0fb53fc1f93b-e53b775c-56b3-40d0-83e6-14c16458c4c2.txt)
2022-05-26T13:05:56    Outgoing response, type: response, statusCode: 404, statusText: NotFound
/home/LogFiles/kudu/trace/0fb53fc1f93b-fea81e74-3023-4713-ae40-0397ee96048b.txt  (https://xyfolxgnipoogweb.scm.azurewebsites.net/api/vfs/LogFiles/kudu/trace/0fb53fc1f93b-fea81e74-3023-4713-ae40-0397ee96048b.txt)
2022-05-26T13:04:58  Startup Request, url: /api/vfs/site/wwwroot/?_=1653570269663, method: GET, type: request, pid: 66,1,5, ScmType: None
/home/LogFiles/2022_05_26_RD0050F221F9BC_docker.log  (https://xyfolxgnipoogweb.scm.azurewebsites.net/api/vfs/LogFiles/2022_05_26_RD0050F221F9BC_docker.log)
2022-05-26T13:06:06.258Z INFO  - Pulling image: demovisualstudiocicdforblazorserver:lastest
2022-05-26T13:06:07.261Z ERROR - DockerApiException: Docker API responded with status code=NotFound, response={"message":"pull access denied for demovisualstudiocicdforblazorserver, repository does not exist or may require 'docker login': denied: requested access to the resource is denied"}
2022-05-26T13:06:07.268Z ERROR - Pull image threw Exception: Input string was not in a correct format.
2022-05-26T13:06:07.270Z INFO  - Pulling image from Docker hub: library/demovisualstudiocicdforblazorserver:lastest
2022-05-26T13:06:08.261Z ERROR - DockerApiException: Docker API responded with status code=NotFound, response={"message":"pull access denied for demovisualstudiocicdforblazorserver, repository does not exist or may require 'docker login': denied: requested access to the resource is denied"}
2022-05-26T13:06:08.262Z WARN  - Image pull failed. Defaulting to local copy if present.
2022-05-26T13:06:08.271Z ERROR - Image pull failed: Verify docker image configuration and credentials (if using private repository)
2022-05-26T13:06:14.248Z INFO  - Stopping site xyfolxgnipoogweb because it failed during startup.
/home/LogFiles/2022_05_26_RD0050F221F9BC_msi_docker.log  (https://xyfolxgnipoogweb.scm.azurewebsites.net/api/vfs/LogFiles/2022_05_26_RD0050F221F9BC_msi_docker.log)
Ending Log Tail of existing logs ---
Starting Live Log Stream ---
2022-05-26T13:07:23  No new trace in the past 1 min(s).
2022-05-26T13:08:23  No new trace in the past 2 min(s).
2022-05-26T13:08:45.623Z INFO  - Starting container for site
2022-05-26T13:08:45.624Z INFO  - docker run -d -p 5009:8081 --name xyfolxgnipoogweb_0_cc82da51_msiProxy -e WEBSITE_ROLE_INSTANCE_ID=0 -e WEBSITE_HOSTNAME=xyfolxgnipoogweb.azurewebsites.net -e WEBSITE_INSTANCE_ID=8da86894c115aaa12b0cc1f0670e554342b94e94c464e9ea3d58600419d382ef -e HTTP_LOGGING_ENABLED=1 appsvc/msitokenservice:2007200210
:52.854Z ERROR - Pull image threw Exception: Input string was not in a correct format.
2022-05-26T13:08:52.855Z INFO  - Pulling image from Docker hub: library/demovisualstudiocicdforblazorserver:lastest
2022-05-26T13:08:53.815Z ERROR - DockerApiException: Docker API responded with status code=NotFound, response={"message":"pull access denied for demovisualstudiocicdforblazorserver, repository does not exist or may require 'docker login': denied: requested access to the resource is denied"}
2022-05-26T13:08:53.816Z WARN  - Image pull failed. Defaulting to local copy if present.
2022-05-26T13:08:53.822Z ERROR - Image pull failed: Verify docker image configuration and credentials (if using private repository)
2022-05-26T13:08:59.779Z INFO  - Stopping site xyfolxgnipoogweb because it failed during startup.
2022-05-26T13:10:23  No new trace in the past 1 min(s).
2022-05-26T13:11:15.425Z INFO  - Starting container for site
2022-05-26T13:11:15.426Z INFO  - docker run -d -p 5281:8081 --name xyfolxgnipoogweb_0_f10b05fb_msiProxy -e WEBSITE_ROLE_INSTANCE_ID=0 -e WEBSITE_HOSTNAME=xyfolxgnipoogweb.azurewebsites.net -e WEBSITE_INSTANCE_ID=8da86894c115aaa12b0cc1f0670e554342b94e94c464e9ea3d58600419d382ef -e HTTP_LOGGING_ENABLED=1 appsvc/msitokenservice:2007200210
:22.263Z ERROR - Pull image threw Exception: Input string was not in a correct format.
2022-05-26T13:11:22.265Z INFO  - Pulling image from Docker hub: library/demovisualstudiocicdforblazorserver:lastest
2022-05-26T13:11:23.206Z ERROR - DockerApiException: Docker API responded with status code=NotFound, response={"message":"pull access denied for demovisualstudiocicdforblazorserver, repository does not exist or may require 'docker login': denied: requested access to the resource is denied"}
2022-05-26T13:11:23.207Z WARN  - Image pull failed. Defaulting to local copy if present.
2022-05-26T13:11:23.209Z ERROR - Image pull failed: Verify docker image configuration and credentials (if using private repository)
2022-05-26T13:11:29.238Z INFO  - Stopping site xyfolxgnipoogweb because it failed during startup.
2022-05-26T13:13:23  No new trace in the past 1 min(s).
2022-05-26T13:13:47.655Z INFO  - Starting container for site
2022-05-26T13:13:47.656Z INFO  - docker run -d -p 8310:8081 --name xyfolxgnipoogweb_0_ab5f89f3_msiProxy -e WEBSITE_ROLE_INSTANCE_ID=0 -e WEBSITE_HOSTNAME=xyfolxgnipoogweb.azurewebsites.net -e WEBSITE_INSTANCE_ID=8da86894c115aaa12b0cc1f0670e554342b94e94c464e9ea3d58600419d382ef -e HTTP_LOGGING_ENABLED=1 appsvc/msitokenservice:2007200210
:55.022Z ERROR - Pull image threw Exception: Input string was not in a correct format.
2022-05-26T13:13:55.028Z INFO  - Pulling image from Docker hub: library/demovisualstudiocicdforblazorserver:lastest
2022-05-26T13:13:55.952Z ERROR - DockerApiException: Docker API responded with status code=NotFound, response={"message":"pull access denied for demovisualstudiocicdforblazorserver, repository does not exist or may require 'docker login': denied: requested access to the resource is denied"}
2022-05-26T13:13:55.953Z WARN  - Image pull failed. Defaulting to local copy if present.
2022-05-26T13:13:55.957Z ERROR - Image pull failed: Verify docker image configuration and credentials (if using private repository)
2022-05-26T13:14:01.819Z INFO  - Stopping site xyfolxgnipoogweb because it failed during startup.
2022-05-26T13:15:23  No new trace in the past 1 min(s).
2022-05-26T13:16:23  No new trace in the past 2 min(

fix lastest->latest

2022-05-26T15:33:28  Welcome, you are now connected to log-streaming service.
Starting Log Tail -n 10 of existing logs ----
/home/LogFiles/__lastCheckTime.txt  (https://xyfolxgnipoogweb.scm.azurewebsites.net/api/vfs/LogFiles/__lastCheckTime.txt)05/26/2022 15:33:05
/home/LogFiles/kudu/trace/583fc9661627-87e59a06-7a80-452f-92f2-95eaa7647282.txt  (https://xyfolxgnipoogweb.scm.azurewebsites.net/api/vfs/LogFiles/kudu/trace/583fc9661627-87e59a06-7a80-452f-92f2-95eaa7647282.txt)
2022-05-26T15:31:43  Startup Request, url: /api/vfs/site/wwwroot/?_=1653579060402, method: GET, type: request, pid: 63,1,5, ScmType: None
/home/LogFiles/2022_05_26_lw1sdlwk00013K_docker.log  (https://xyfolxgnipoogweb.scm.azurewebsites.net/api/vfs/LogFiles/2022_05_26_lw1sdlwk00013K_docker.log)
2022-05-26T15:33:00.170Z INFO  - Stopping site xyfolxgnipoogweb because it failed during startup.
2022-05-26T15:33:22.881Z INFO  - Pulling image: demovisualstudiocicdforblazorserver:latest
2022-05-26T15:33:23.829Z ERROR - DockerApiException: Docker API responded with status code=NotFound, response={"message":"pull access denied for demovisualstudiocicdforblazorserver, repository does not exist or may require 'docker login': denied: requested access to the resource is denied"}
2022-05-26T15:33:23.829Z ERROR - Pull image threw Exception: Input string was not in a correct format.
2022-05-26T15:33:23.842Z INFO  - Pulling image from Docker hub: library/demovisualstudiocicdforblazorserver:latest
2022-05-26T15:33:24.832Z ERROR - DockerApiException: Docker API responded with status code=NotFound, response={"message":"pull access denied for demovisualstudiocicdforblazorserver, repository does not exist or may require 'docker login': denied: requested access to the resource is denied"}
2022-05-26T15:33:24.853Z WARN  - Image pull failed. Defaulting to local copy if present.
2022-05-26T15:33:24.902Z ERROR - Image pull failed: Verify docker image configuration and credentials (if using private repository)
/home/LogFiles/2022_05_26_lw1sdlwk00013K_msi_docker.log  (https://xyfolxgnipoogweb.scm.azurewebsites.net/api/vfs/LogFiles/2022_05_26_lw1sdlwk00013K_msi_docker.log)
Ending Log Tail of existing logs ---
Starting Live Log Stream ---
2022-05-26T15:33:22.881Z INFO  - Pulling image: demovisualstudiocicdforblazorserver:latest
2022-05-26T15:33:23.829Z ERROR - DockerApiException: Docker API responded with status code=NotFound, response={"message":"pull access denied for demovisualstudiocicdforblazorserver, repository does not exist or may require 'docker login': denied: requested access to the resource is denied"}
2022-05-26T15:33:23.829Z ERROR - Pull image threw Exception: Input string was not in a correct format.
2022-05-26T15:33:23.842Z INFO  - Pulling image from Docker hub: library/demovisualstudiocicdforblazorserver:latest
2022-05-26T15:33:24.832Z ERROR - DockerApiException: Docker API responded with status code=NotFound, response={"message":"pull access denied for demovisualstudiocicdforblazorserver, repository does not exist or may require 'docker login': denied: requested access to the resource is denied"}
2022-05-26T15:33:24.853Z WARN  - Image pull failed. Defaulting to local copy if present.
2022-05-26T15:33:24.902Z ERROR - Image pull failed: Verify docker image configuration and credentials (if using private repository)
2022-05-26T15:33:30.602Z INFO  - Stopping site xyfolxgnipoogweb because it failed during startup.

 */
