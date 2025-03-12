
// ============== //
// Parameters     //
// ============== //

param routeServerDefintion routeServerDefintionType

// ============== //
// Variables      //
// ============== //

// ============== //
// Resources      //
// ============== //

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: routeServerDefintion.virtualNetworkName
}

// =============== //
// Outputs         //
// =============== //

// ================ //
// Definitions      //
// ================ //

type routeServerDefintionType = {
  @description('Mandatory. The name of the Virtual Network.')
  virtualNetworkName: string
}
