
// ============== //
// Parameters     //
// ============== //

@description('Optional. The location to deploy resources to.')
param location string = resourceGroup().location

@description('Optional. The naming standard.')
param name string = subscription().displayName

@description('Mandatory. Configure the Azure Route Server.')
param routeServerDefintion routeServerDefintionType

@description('Optional. Resource ID(s) of storage systems that are used for diagnostics monitoring. Defaults to empty.')
param diagnosticsStorage diagnosticsStorageType = {}

@description('Optional. Tags for the hub.')
param tags object = {}

@description('Optional. What availability zones are preferred')
param zones array = [
  1
  2
  3
]

@description('Optional. Enable/Disable usage telemetry for module.')
param enableTelemetry bool = false

// ============== //
// Variables      //
// ============== //

var monitoringSettings = length(diagnosticsStorage) > 0
  ? [
      {
        eventHubAuthorizationRuleResourceId: diagnosticsStorage.?eventHubAuthorizationRuleId ?? null
        eventHubName: diagnosticsStorage.?eventHubName ?? null
        name: 'monitoringSettings'
        storageAccountResourceId: diagnosticsStorage.?storageAccountResourceId ?? null
        workspaceResourceId: diagnosticsStorage.?workspaceResourceId ?? null
      }
    ]
  : null
  
var namingUniqueString = take(uniqueString(subscription().id, location), 8)

// ============== //
// Resources      //
// ============== //

// Public IP Address

module publicIp 'br/public:avm/res/network/public-ip-address:0.8.0' = {
  name: take('netRg-bas-pip-${uniqueString(deployment().name, location)}', 64)
  params: {
    name: '${name}-net-bas-pip'
    location: location
    tags: union(tags, {
      Purpose: 'Public IP Address for the Azure Bastion'
    })
    diagnosticSettings: monitoringSettings
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    skuName: 'Standard'
    skuTier: 'Regional'
    zones: zones ?? (length(zones) > 0 ? zones : null)
    enableTelemetry: enableTelemetry
  }
}

// Azure Route Server

resource azureRouteServer 'Microsoft.Network/virtualHubs@2024-05-01' = {
  name: name
  location: location
  tags: union(tags, {
    Purpose: 'Azure Bastion for secure RDP and SSH access'
  })
  properties: {
    sku: routeServerDefintion.?sku ?? 'Basic'
    virtualRouterAutoScaleConfiguration: {
      minCapacity: routeServerDefintion.?minCapacity ?? 1
    }
    allowBranchToBranchTraffic: routeServerDefintion.?allowBranchToBranchTraffic ?? false
    virtualRouterAsn: routeServerDefintion.?virtualRouterAsn ?? 65515
    hubRoutingPreference: routeServerDefintion.?hubRoutingPreference ?? 'ExpressRoute'
    azureFirewall: !empty(routeServerDefintion.?azureFirewallResourceId)
      ? {
          id: routeServerDefintion.?azureFirewallResourceId
        }
      : null
  }
}

// Existing Virtual Network

resource azureRouteServerSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  name: '${last(split(routeServerDefintion.?vNetResourceId, '/'))}/RouteServerSubnet'
}

// Bing Azure Route Server With Public IP Address

resource ipconfig 'Microsoft.Network/virtualHubs/ipConfigurations@2024-05-01' = {
  name: azureRouteServer.name
  parent: azureRouteServer
  properties: {
    subnet: {
      id: azureRouteServerSubnet.id
    }
    publicIPAddress: {
      id: publicIp.outputs.resourceId
    }
  }
}

// =============== //
// Outputs         //
// =============== //


@description('The resource group the virtual network peering was deployed into.')
output resourceGroupName string = resourceGroup().name

@description('The name of the virtual network peering.')
output name string = azureRouteServer.name

@description('The resource ID of the virtual network peering.')
output resourceId string = azureRouteServer.id

// ================ //
// Definitions      //
// ================ //

type routeServerDefintionType = {
  @description('Mandatory. The resource ID of the Virtual Network.')
  vNetResourceId: string

  @description('Optional. What availability zones will be used. Default = 1,2,3.')
  zones: array?

  @description('Optional. The SKU of Azure Bastion. Default = Basic')
  sku: string?

  @description('Optional. The minimum number of Azure Bastion instances. Default = 1')
  minCapacity: int?

  @description('Optional. Should branch-to-branch traffic be routed. Default = false')
  allowBranchToBranchTraffic: bool?

  @description('Optional. The ASN for Azure Route Server. Default = 65515')
  virtualRouterAsn: int?

  @description('Optional. Which site-to-site connection type is preferred. Default = ExpressRoute')
  hubRoutingPreference: routeServerHubRoutingPreferenceType?

  @description('Optional. The resource ID of the Azure Firewall.')
  azureFirewallResourceId: string
}

type routeServerHubRoutingPreferenceType =   'ASPath' | 'ExpressRoute' | 'VpnGateway'

type diagnosticsStorageType = {
  @description('Optional. The resource ID of a Log Analytics Workspace.')
  workspaceResourceId: string?

  @description('Optional. The resource ID of a Storage Account.')
  storageAccountResourceId: string?

  @description('Optional. The name of an Event Hub.')
  eventHubName: string?

  @description('Optional. The Authorisation Rule ID for an Event Hub.')
  eventHubAuthorizationRuleId: string?

  @description('Optional. The Partner ID for a third-party monitoring solution.')
  marketplacePartnerId: string?
}
