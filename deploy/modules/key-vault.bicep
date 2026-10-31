metadata name = 'GeoAnalytics Key Vault'
metadata description = 'RBAC-enabled vault and access for the interactive customer user.'

@description('Azure region.')
param location string

@description('Resource ownership tags.')
param tags object

@description('Key Vault name.')
param name string

@description('Interactive customer user object ID.')
param userObjectId string

resource vault 'Microsoft.KeyVault/vaults@2025-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

var secretsOfficerRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
resource secretAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vault.id, userObjectId, secretsOfficerRoleId)
  scope: vault
  properties: {
    roleDefinitionId: secretsOfficerRoleId
    principalId: userObjectId
    principalType: 'User'
  }
}

@description('Vault URI. No secret values are returned.')
output uri string = vault.properties.vaultUri

@description('Vault ARM ID.')
output id string = vault.id
