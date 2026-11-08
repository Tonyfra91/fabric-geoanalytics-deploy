metadata name = 'Fast Pass GeoAnalytics credential'
metadata description = 'Stores the customer credential in the existing Key Vault through ARM without changing the vault or its networking.'
targetScope = 'resourceGroup'

@description('Existing Fast Pass Key Vault name. Select its existing resource group.')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Esri GeoAnalytics API key. Enter only in this secure deployment field, never in the template editor or a parameter file.')
@secure()
@minLength(1)
param geoAnalyticsApiKey string

resource vault 'Microsoft.KeyVault/vaults@2025-05-01' existing = {
  name: keyVaultName
}

resource apiKey 'Microsoft.KeyVault/vaults/secrets@2025-05-01' = {
  parent: vault
  name: 'geoanalytics-api-key'
  properties: {
    value: geoAnalyticsApiKey
    attributes: {
      enabled: true
    }
  }
}
