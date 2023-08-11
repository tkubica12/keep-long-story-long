param location string = 'westeurope'

// Create virtual network
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: 'myVnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'sub1'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'sub2'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
}

// Create NIC
resource nic 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: 'nic1'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/sub1'
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}
