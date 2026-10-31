metadata name = 'Optional New Fabric Capacity'
metadata description = 'Creates a capacity only when the customer explicitly selects new capacity mode.'

@description('Capacity Azure region.')
param location string

@description('Resource ownership tags.')
param tags object

@description('Capacity name.')
param name string

@description('Capacity SKU.')
param sku string

@description('Capacity administrator user principal names.')
param administrators array

resource capacity 'Microsoft.Fabric/capacities@2023-11-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
    tier: 'Fabric'
  }
  properties: {
    administration: {
      members: administrators
    }
  }
}

@description('Capacity ARM resource ID, not its Fabric capacity GUID.')
output id string = capacity.id
