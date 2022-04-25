
//@description ('cosmosDbAccount')
//param cosmosDbAccount object

@description ('cosmosDbAccountId')
param cosmosDbAccountId string

@description ('cosmosDbAccountName')
param cosmosDbAccountName string

@description('Principal ID of the managed identity')
param principalId string

@description('iteration')
param it int

var roleDefId = guid('sql-role-definition-', principalId, cosmosDbAccountId)
var roleDefName = 'Custom Read/Write role ${it}'
var roleAssignId = guid(roleDefId, principalId, cosmosDbAccountId)

resource roleDefinition 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2021-06-15' = {
  name: '${cosmosDbAccountName}/${roleDefId}'
  properties: {
    roleName: roleDefName
    type: 'CustomRole'
    assignableScopes: [
      cosmosDbAccountId
    ]
    permissions: [
      {
        dataActions: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*'
        ]
      }
    ]
  }
}

resource roleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-06-15' = {
  name: '${cosmosDbAccountName}/${roleAssignId}'
  properties: {
    roleDefinitionId: roleDefinition.id
    principalId: principalId
    scope: cosmosDbAccountId
  }
}