metadata name = 'Fabric GeoAnalytics deployment experience'
metadata description = 'Azure foundation for a guided Fabric GeoAnalytics workload. Finish Fabric setup separately.'
targetScope = 'subscription'

@description('Deployment name used for resource ownership tags.')
@minLength(3)
@maxLength(41)
param deploymentName string

@description('Azure region for the resource group, vault, and optional new capacity.')
param location string

@description('Resource group for deployment-created Azure resources.')
param resourceGroupName string

@description('Globally unique Key Vault name.')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Object ID of the interactive deployment and notebook user.')
param userObjectId string

@description('Name of the dedicated Key Vault virtual network.')
param virtualNetworkName string = 'vnet-${deploymentName}'

@description('Private IPv4 address space for the dedicated virtual network. Review for overlap before deployment.')
param virtualNetworkAddressPrefix string = '10.0.0.0/16'

@description('Name of the dedicated private endpoint subnet.')
param privateEndpointSubnetName string = 'snet-private-endpoints'

@description('Private IPv4 subnet prefix within the virtual network address space.')
param privateEndpointSubnetPrefix string = '10.0.0.0/24'

@description('Name of the Azure Key Vault private endpoint.')
param privateEndpointName string = 'pe-${keyVaultName}'

@description('Name of the network interface created and managed by the private endpoint.')
param privateEndpointNetworkInterfaceName string = 'nic-${privateEndpointName}'

@description('Name of the private DNS virtual network link.')
param privateDnsLinkName string = '${virtualNetworkName}-vault'

@description('Whether to create a new capacity. False preserves the existing customer capacity.')
param shouldCreateCapacity bool = false

@description('New capacity name. Required only when creating a capacity.')
param capacityName string?

@description('SKU for an explicitly requested new capacity.')
param capacitySku string = 'F2'

@description('Capacity administrator user principal names for an explicitly requested new capacity.')
param capacityAdministrators array = []

var tags = {
  accelerator: 'fabric-zombie-outbreak'
  deployment: deploymentName
}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module vault 'modules/key-vault.bicep' = {
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    name: keyVaultName
    userObjectId: userObjectId
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressPrefix: virtualNetworkAddressPrefix
    privateEndpointSubnetName: privateEndpointSubnetName
    privateEndpointSubnetPrefix: privateEndpointSubnetPrefix
    privateEndpointName: privateEndpointName
    privateEndpointNetworkInterfaceName: privateEndpointNetworkInterfaceName
    privateDnsLinkName: privateDnsLinkName
  }
}

module capacity 'modules/fabric-capacity.bicep' = if (shouldCreateCapacity) {
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    name: capacityName!
    sku: capacitySku
    administrators: capacityAdministrators
  }
}

@description('Nonsecret Key Vault endpoint.')
output keyVaultUri string = vault.outputs.uri

@description('Key Vault ARM ID.')
output keyVaultId string = vault.outputs.id

@description('Dedicated virtual network ARM ID. This does not connect the deployment computer or Fabric to the virtual network.')
output virtualNetworkId string = vault.outputs.virtualNetworkId

@description('Azure Key Vault private endpoint ARM ID. Connection approval must be verified separately.')
output keyVaultPrivateEndpointId string = vault.outputs.privateEndpointId

@description('Key Vault private DNS zone ARM ID.')
output keyVaultPrivateDnsZoneId string = vault.outputs.privateDnsZoneId

@description('Optional new capacity ARM ID. The Fabric capacity ID is resolved separately.')
output capacityResourceId string? = shouldCreateCapacity ? capacity!.outputs.id : null

@description('Handoff contract version for the guided Fabric setup.')
output experienceVersion string = '1.0'

@description('Next step after Azure deployment succeeds.')
output nextStep string = 'Clone Tonyfra91/fabric-geoanalytics-deploy and follow docs/getting-started.md. No Fabric notebook has been deployed or executed.'
