metadata name = 'GeoAnalytics Key Vault'
metadata description = 'Private-only RBAC vault, dedicated private endpoint network and DNS, and access for the interactive customer user.'

@description('Azure region.')
param location string

@description('Resource ownership tags.')
param tags object

@description('Key Vault name.')
param name string

@description('Interactive customer user object ID.')
param userObjectId string

@description('Dedicated virtual network name.')
param virtualNetworkName string

@description('Private IPv4 address space for the virtual network.')
param virtualNetworkAddressPrefix string

@description('Dedicated private endpoint subnet name.')
param privateEndpointSubnetName string

@description('Private endpoint subnet IPv4 address prefix.')
param privateEndpointSubnetPrefix string

@description('Azure Key Vault private endpoint name.')
param privateEndpointName string

@description('Name of the network interface managed by the private endpoint.')
param privateEndpointNetworkInterfaceName string

@description('Private DNS virtual network link name.')
param privateDnsLinkName string

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
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
    }
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: virtualNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressPrefix
      ]
    }
    subnets: [
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2025-05-01' = {
  name: privateEndpointName
  location: location
  tags: tags
  properties: {
    customNetworkInterfaceName: privateEndpointNetworkInterfaceName
    subnet: {
      id: '${virtualNetwork.id}/subnets/${privateEndpointSubnetName}'
    }
    privateLinkServiceConnections: [
      {
        name: '${privateEndpointName}-vault'
        properties: {
          privateLinkServiceId: vault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

resource privateDnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZone
  name: privateDnsLinkName
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-05-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'vault'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
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

@description('Dedicated virtual network ARM ID.')
output virtualNetworkId string = virtualNetwork.id

@description('Azure Key Vault private endpoint ARM ID.')
output privateEndpointId string = privateEndpoint.id

@description('Key Vault private DNS zone ARM ID.')
output privateDnsZoneId string = privateDnsZone.id
