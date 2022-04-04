/*
 * Begin commands to execute this file using Azure CLI with PowerShell
 * $name='AADB2C_BlazorServerDemo'
 * $rg="rg_$name"
 * $loc='westus2'
 * az.cmd group create --location $loc --resource-group $rg 
 * Set-AzDefault -ResourceGroupName $rg 
 * az.cmd deployment group create --name $name --resource-group $rg   --template-file deploy.bicep   --parameters '@deploy.parameters.json' --parameters ownerId=$env:AZURE_OBJECTID
 * End commands to execute this file using Azure CLI with Powershell
 *
 * Begin commands to execute this file using Azure CLI with PowerShell
 * $name='AADB2C_BlazorServerDemo'
 * $rg="rg_$name"
 * $loc='westus2'
 * az.cmd group delete --name $rg --yes
 * End commands to execute this file using Azure CLI with Powershell
 */


@description('The base name for resources')
param name string = uniqueString(resourceGroup().id)

@description('The location for resources')
param location string = resourceGroup().location

@description('Azure AD B2C Configuration [{key:"", value:""}]')
param aadb2cConfig object

@description('Azure AD B2C App Registration client secret')
@secure()
param clientSecret string

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

param ownerId string

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

  resource aadb2cClientSecret 'keyValues@2020-07-01-preview' = {
    // Store secrets in Key Vault with a reference to them in App Configuration e.g., client secrets, connection strings, etc.
    name: 'AzureAdB2C:ClientSecret'
    properties: {
      // Most often you will want to reference a secret without the version so the current value is always retrieved.
      contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
      value: '{"uri":"${kvaadb2cSecret.properties.secretUri}"}'
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

resource web 'Microsoft.Web/sites@2020-12-01' = {
  name: '${name}web'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: plan.id
    siteConfig: {
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
output siteUrl string = 'https://${web.properties.defaultHostName}/'
output vaultUrl string = kv.properties.vaultUri
