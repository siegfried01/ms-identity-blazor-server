@description('Application Name')
@maxLength(30)
param applicationName string = 'todo-app-${uniqueString(resourceGroup().id)}'
@description('Location for all resources.')
param location string = resourceGroup().location
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
@description('App Service Plan\'s pricing tier. Details at https://azure.microsoft.com/en-us/pricing/details/app-service/')
param appServicePlanTier string = 'F1'
@minValue(1)
@maxValue(3)
@description('App Service Plan\'s instance count')
param appServicePlanInstances int = 1
@description('The URL for the GitHub repository that contains the project to deploy.')
param repositoryUrl string = 'https://github.com/Azure-Samples/cosmos-dotnet-core-todo-app.git'
@description('The branch of the GitHub repository to use.')
param branch string = 'main'
@description('The Cosmos DB database name.')
param databaseName string = 'Tasks'
@description('The Cosmos DB container name.')
param containerName string = 'Items'
var cosmosAccountName = toLower(applicationName)
var websiteName = applicationName
var hostingPlanName = applicationName
var keyvaultName = applicationName
// Use built-in roles https://docs.microsoft.com/en-us/azure/key-vault/general/rbac-guide?tabs=azure-cli#azure-built-in-roles-for-key-vault-data-plane-operations
var keyVaultSecretsUserRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2021-04-15' = {
  name: cosmosAccountName
  kind: 'GlobalDocumentDB'
  location: location
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
    databaseAccountOfferType: 'Standard'
  }
}
resource kv 'Microsoft.KeyVault/vaults@2019-09-01' = {
  // Make sure the Key Vault name begins with a letter.
  name: keyvaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enabledForDeployment: false
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: false
  }
  resource cosmosDbAccountSecret 'secrets' = {
    name: 'CosmosDbAccount'
    properties: {
      value: cosmosAccount.properties.documentEndpoint
    }
  }
  resource cosmostDbKeySecret 'secrets' = {
    name: 'CosmostDbKey'
    properties: {
      value: cosmosAccount.listKeys().primaryMasterKey
    }
  }
}
resource hostingPlan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: appServicePlanTier
    capacity: appServicePlanInstances
  }
}
resource website 'Microsoft.Web/sites@2020-06-01' = {
  name: websiteName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'CosmosDb:Account'
          value: '@Microsoft.KeyVault(VaultName=${kv.name};SecretName=${kv::cosmosDbAccountSecret.name})'
        }
        {
          name: 'CosmosDb:Key'
          value: '@Microsoft.KeyVault(VaultName=${kv.name};SecretName=${kv::cosmostDbKeySecret.name})'
        }
        {
          name: 'CosmosDb:DatabaseName'
          value: databaseName
        }
        {
          name: 'CosmosDb:ContainerName'
          value: containerName
        }
      ]
    }
  }
}
resource kvWebsitePermissions 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(kv.id, website.name, keyVaultSecretsUserRole)
  scope: kv
  properties: {
    principalId: website.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: keyVaultSecretsUserRole
  }
}
resource srcControls 'Microsoft.Web/sites/sourcecontrols@2020-06-01' = {
  name: '${website.name}/web'
  properties: {
    repoUrl: repositoryUrl
    branch: branch
    isManualIntegration: true
  }
}
