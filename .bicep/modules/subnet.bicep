
// ============== //
// Parameters     //
// ============== //

param subnetConfig subnetConfigType

// ============== //
// Variables      //
// ============== //

// ============== //
// Resources      //
// ============== //

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: subnetConfig.virtualNetworkName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: subnetConfig.name
  parent: virtualNetwork
  properties: {
    addressPrefix: subnetConfig.addressPrefix
    networkSecurityGroup: !empty(subnetConfig.?networkSecurityGroupResourceId)
    ? {
        id: subnetConfig.?networkSecurityGroupResourceId
      }
    : null
  routeTable: !empty(subnetConfig.?routeTableResourceId)
    ? {
        id: subnetConfig.?routeTableResourceId
      }
    : null
  natGateway: !empty(subnetConfig.?natGatewayResourceId)
    ? {
        id: subnetConfig.?natGatewayResourceId
      }
    : null
  serviceEndpoints: [
    for endpoint in subnetConfig.?serviceEndpoints!: {
      service: endpoint
    }
  ]
  }
}

// =============== //
// Outputs         //
// =============== //

@description('The resource group the virtual network peering was deployed into.')
output resourceGroupName string = resourceGroup().name

@description('The name of the virtual network peering.')
output name string = subnet.name

@description('The resource ID of the virtual network peering.')
output resourceId string = subnet.id

@description('The address prefix for the subnet.')
output addressPrefix string = subnet.properties.?addressPrefix ?? ''

// ================ //
// Definitions      //
// ================ //

type subnetConfigType = {
  @description('Mandatory. The name of the Virtual Network.')
  virtualNetworkName: string

  @description('Mandatory. The name of the subnet.')
  name: string

  @description('Mandatory. The address prefix of the subnet.')
  addressPrefix: string

  @description('Optional. The resource ID of a Route Table.')
  routeTableResourceId: string?
  
  @description('Optional. The resource ID of a Network Security Group.')
  networkSecurityGroupResourceId: string?

  @description('Optional. The resource ID of a NAT Gateway.')
  natGatewayResourceId: string?

  @description('Optional. An array of Service Endpoint names.')
  serviceEndpoints: array?
}

