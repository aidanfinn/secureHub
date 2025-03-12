metadata name = 'Hub Networking'
metadata description = 'This module will deploy a hub for a zero-trust hub & spoke network.'

targetScope = 'subscription'

// ============== //
// Parameters     //
// ============== //

@description('Optional. The Workload name.')
param name string = replace(subscription().displayName, ' ', '-')

@description('Optional. Location for all Resources.')
param location string = deployment().location

@description('Optional. Enable/Disable usage telemetry for module.')
param enableTelemetry bool = false

@description('Optional: Select which resources will be deployed.')
param selectResource selectResourceType = {
  azureBastion: false
  azureFirewall: false
  azureRouteServer: false
  vpnVirtualNetworkGateway: false
  expressRouteVirtualNetworkGateway: false
  nvaFirewall: false
  nvaRouter: false
  monitoring: false
  budget: false
}

@description('Optional. The resource ID of the Log Analytics Workspace.')
param workspaceResourceId string = ''

@description('Optional. Tags for the hub.')
param tags object = {}

@description('Optional. The reserved IP prefix for the entire hub & spoke deployment.')
param dataCentrePrefix string = '10/0.0.0/16'

param firewallUserDefinedRoutes routesDefinitionType = [
  {
    name: 'Everywhere'
    properties: {
      addressPrefix: '0.0.0.0/0'
      nextHopType: 'Internet'
    }
  }
]

@description('Optional. Resource ID(s) of storage systems that are used for diagnostics monitoring. Defaults to empty.')
param diagnosticsStorage diagnosticsStorageType = {}

param bastionDefinition bastionDefinitionType = {}

@description('Optional. What availability zones are preferred')
param zones array = [
  1
  2
  3
]

@description('Mandatory. Configure the Azure Route Server.')
param routeServerDefintion routeServerDefintionType

// ============== //
// Variables      //
// ============== //

var namingUniqueString = take(uniqueString(subscription().id, location), 8)

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

// ============== //
// Resources      //
// ============== //

// Network Watcher Resource Group

resource networkWatcherRg 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: 'NetworkWatcherRG'
  location: location
  tags: union(tags, {
    Purpose: 'Network Watcher resource group'
  })
}

// Network Watcher

module networkWatcher 'br/public:avm/res/network/network-watcher:0.4.0' = {
  scope: networkWatcherRg
  name: take('networkWatcherRg-nw-${uniqueString(deployment().name, location)}', 64)
  params: {
    name: 'NetworkWatcher_${location}'
    location: location
    tags: union(tags, {
      Purpose: 'Network Watcher'
    })
    enableTelemetry: enableTelemetry
  }
}

// Network Watcher Storage

module networkWatcherStorage 'br/public:avm/res/storage/storage-account:0.18.2' = {
  scope: networkWatcherRg
  name: take('networkWatcherRg-sa-${uniqueString(deployment().name, location)}', 64)
  params: {
    name: take('networkwatcherrgmon${namingUniqueString}', 24)
    location: location
    tags: union(tags, {
      Purpose: 'Network Watcher monitoring storage'
    })
    enableTelemetry: enableTelemetry
  }
}

// Network resource group

resource networkRg 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: '${name}-net'
  location: location
  tags: union(tags, {
    Purpose: 'Networking resource group'
  })
}

// GatewaySubnet Route Table

module gatewaySubnetRouteTable 'br/public:avm/res/network/route-table:0.4.0' = if (selectResource.?vpnVirtualNetworkGateway! || selectResource.?expressRouteVirtualNetworkGateway!) {
  scope: networkRg
  name: take('netRg-rt-gw-${uniqueString(deployment().name, location)}', 64)
  params: {
    name: '${networkRg.name}-vnet-GatewaySubnet-rt'
    tags: union(tags, {
      Purpose: 'A Route Table for the GatewaySubnet sunet'
    })
    enableTelemetry: enableTelemetry
  }
}

// NvaRouterSubnet Route Table

module nvaRouterSubnetRouteTable 'br/public:avm/res/network/route-table:0.4.0' = if (selectResource.?nvaRouter!) {
  scope: networkRg
  name: take('netRg-rt-nvar-${uniqueString(deployment().name, location)}', 64)
  params: {
    name: '${networkRg.name}-vnet-NvaRouterSubnet-rt'
    tags: union(tags, {
      Purpose: 'A Route Table for the NVA router'
    })
    enableTelemetry: enableTelemetry
  }
}

// AzureFirewallSubnet Route Table

module azureFirewallSubnetRouteTable 'br/public:avm/res/network/route-table:0.4.0' = if (selectResource.?azureFirewall!) {
  scope: networkRg
  name: take('netRg-rt-af-${uniqueString(deployment().name, location)}', 64)
  params: {
    name: '${networkRg.name}-vnet-AzureFirewallSubnet-rt'
    tags: union(tags, {
      Purpose: 'A Route Table for the Azure Firewall'
    })
    routes: firewallUserDefinedRoutes
    enableTelemetry: enableTelemetry
  }
}

// AzureFirewallManagementSubnet Route Table

module azureFirewallManagementSubnetRouteTable 'br/public:avm/res/network/route-table:0.4.0' = if (selectResource.?azureFirewall!) {
  scope: networkRg
  name: take('netRg-rt-afm-${uniqueString(deployment().name, location)}', 64)
  params: {
    name: '${networkRg.name}-vnet-AzureFirewallManagementSubnet-rt'
    tags: union(tags, {
      Purpose: 'A Route Table for the Azure Firewall management feature'
    })
    routes: [
      {
        name: 'Everywhere'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'Internet'
        }
      }
    ]
    enableTelemetry: enableTelemetry
  }
}

// NvaFirewallSubnet Route Table

module nvaFirewallSubnetRouteTable 'br/public:avm/res/network/route-table:0.4.0' = if (selectResource.?nvaFirewall!) {
  scope: networkRg
  name: take('netRg-rt-nvaf-${uniqueString(deployment().name, location)}', 64)
  params: {
    name: '${networkRg.name}-vnet-NvaFirewallSubnet-rt'
    tags: union(tags, {
      Purpose: 'A Route Table for the NVA Firewall'
    })
    routes: firewallUserDefinedRoutes
    enableTelemetry: enableTelemetry
  }
}

// AzureBastionSubnet NSG

module azureBastionSubnetNsg 'br/public:avm/res/network/network-security-group:0.5.0' = {
  scope: networkRg
  name: take('netRg-nsg-azb-${uniqueString(deployment().name, location)}', 64)
  params: {
    name: '${networkRg.name}-vnet-AzureBackstionSubnet-nsg'
    tags: union(tags, {
      Purpose: 'A Route Table for the NVA Firewall'
    })
    securityRules: [
      {
        name: 'AllowHttpsFromInternet'
        properties: {
          description: 'Allow remote traffic via HTTPS from Internet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'AllowControlFromGatewaymanager'
        properties: {
          description: 'Allow control plane traffic from Azure Gateway Manager'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1100
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'AllowProbeFromAzureLoadBalancer'
        properties: {
          description: 'Allow probe traffic from Azure Load Balancer'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1200
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'AllowBastionHostCommunication'
        properties: {
          description: 'Allow communications from Azure Bastion'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 1300
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'DenyEverythingElse'
        properties: {
          description: 'Deny all other traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'AllowSshRdpFromAzurebastion'
        properties: {
          description: 'Allow RDP and SSH from Azure Bastion'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 1000
          direction: 'Outbound'
          sourcePortRanges: []
          destinationPortRanges: [
            '22'
            '3389'
          ]
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'AllowDiagnosticsFromAzurebastion'
        properties: {
          description: 'Allow diagnostics from Azure Bastion'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 1100
          direction: 'Outbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'AllowDataPlaneFromAzureBastion'
        properties: {
          description: 'Allow data plane communication between the underlying components of Azure Bastion'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 1200
          direction: 'Outbound'
          sourcePortRanges: []
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'AllowGetSessionInformationFromAzurebastion'
        properties: {
          description: 'Allow session management traffic from Azure Bastion'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 1300
          direction: 'Outbound'
          sourcePortRanges: []
          destinationPortRanges: [
            '80'
          ]
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
    ]
    diagnosticSettings: monitoringSettings
    enableTelemetry: enableTelemetry
  }
}

// Virtual Network

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.5.1' = {
  scope: networkRg
  name: take('netRg-vnet-${uniqueString(deployment().name, location)}', 64)
  params: {
    name: '${networkRg.name}-vnet'
    tags: union(tags, {
      Purpose: 'Hub virtual network'
    })
    addressPrefixes: [
      cidrSubnet(dataCentrePrefix, 22, 0)
    ]
    diagnosticSettings: monitoringSettings
    enableTelemetry: enableTelemetry
  }
  dependsOn: [
    networkWatcher
  ]
}

// GatewaySubnet subnet

module gatewaySubnet 'modules/subnet.bicep' = if (selectResource.?vpnVirtualNetworkGateway! || selectResource.?expressRouteVirtualNetworkGateway!) {
  scope: networkRg
  name: take('netRg-vnet-subnet-gw-${uniqueString(deployment().name, location)}', 64)
  params: {
    subnetConfig: {
      name: 'GatewaySubnet'
      addressPrefix: cidrSubnet(dataCentrePrefix, 26, 0)
      virtualNetworkName: virtualNetwork.outputs.name
      routeTableResourceId: gatewaySubnetRouteTable.outputs.resourceId
    }
  }
}

// NvaRouterSubnet subnet

module nvaRouterSubnet 'modules/subnet.bicep' = if (selectResource.?nvaRouter!) {
  scope: networkRg
  name: take('netRg-vnet-subnet-nvar-${uniqueString(deployment().name, location)}', 64)
  params: {
    subnetConfig: {
      name: 'NvaRouterSubnet'
      addressPrefix: cidrSubnet(dataCentrePrefix, 26, 1)
      virtualNetworkName: virtualNetwork.outputs.name
      routeTableResourceId: nvaRouterSubnetRouteTable.outputs.resourceId
    }
  }
}

// RouteServerSubnet subnet

module routeServerSubnet 'modules/subnet.bicep' = if (selectResource.?azureRouteServer!) {
  scope: networkRg
  name: take('netRg-vnet-subnet-ar-${uniqueString(deployment().name, location)}', 64)
  params: {
    subnetConfig: {
      name: 'RouteServerSubnet'
      addressPrefix: cidrSubnet(dataCentrePrefix, 24, 14)
      virtualNetworkName: virtualNetwork.outputs.name
    }
  }
}

// AzureFirewallSubnet subnet

module azureFirewallSubnet 'modules/subnet.bicep' = if (selectResource.?azureFirewall!) {
  scope: networkRg
  name: take('netRg-vnet-subnet-af-${uniqueString(deployment().name, location)}', 64)
  params: {
    subnetConfig: {
      name: 'AzureFirewallSubnet'
      addressPrefix: cidrSubnet(dataCentrePrefix, 24, 2)
      virtualNetworkName: virtualNetwork.outputs.name
      routeTableResourceId: azureFirewallSubnetRouteTable.outputs.resourceId
    }
  }
}

// AzureFirewallManagementSubnet subnet

module azureFirewallManagementSubnet 'modules/subnet.bicep' = if (selectResource.?azureFirewall!) {
  scope: networkRg
  name: take('netRg-vnet-subnet-afm-${uniqueString(deployment().name, location)}', 64)
  params: {
    subnetConfig: {
      name: 'AzureFirewallManagementSubnet'
      addressPrefix: cidrSubnet(dataCentrePrefix, 26, 14)
      virtualNetworkName: virtualNetwork.outputs.name
      routeTableResourceId: azureFirewallManagementSubnetRouteTable.outputs.resourceId
    }
  }
}

// NvaFirewallSubnet subnet

module nvaFirewallSubnet 'modules/subnet.bicep' = if (selectResource.?nvaFirewall!) {
  scope: networkRg
  name: take('netRg-vnet-subnet-nvaf-${uniqueString(deployment().name, location)}', 64)
  params: {
    subnetConfig: {
      name: 'NvaFirewallSubnet'
      addressPrefix: cidrSubnet(dataCentrePrefix, 24, 1)
      virtualNetworkName: virtualNetwork.outputs.name
      routeTableResourceId: nvaFirewallSubnetRouteTable.outputs.resourceId
    }
  }
}

// VNet Flow Logs

module flowLogs 'br/public:avm/res/network/network-watcher:0.4.0' = if (selectResource.?monitoring!) {
  scope: networkWatcherRg
  name: take('networkWatcherRg-fl-${uniqueString(deployment().name, location)}', 64)
  params: {
    location: location
    tags: union(tags, {
      Purpose: 'Enable Virtual Network Flow Logs'
    })
    flowLogs: [
      {
        formatVersion: 2
        name: '${virtualNetwork.outputs.name}-fl'
        retentionInDays: 1
        storageId: networkWatcherStorage.outputs.resourceId
        targetResourceId: virtualNetwork.outputs.resourceId
        trafficAnalyticsInterval: !empty(workspaceResourceId) ? 10 : null
        workspaceResourceId: !empty(workspaceResourceId) ? workspaceResourceId : null
      }
    ]
    enableTelemetry: enableTelemetry
  }
}

// VPN Virtual Network Gateway

// ExpressRoute Virtual Network Gateway

// Azure Route Server

module azureRouteServer 'modules/azureRouteServer.bicep' = if(selectResource.?azureRouteServer!) {
  scope: networkRg
  name: take('netRg-rtserv-${uniqueString(deployment().name, location)}', 64)
  params: {
    name: name
    location: location
    tags: tags
    zones: zones ?? (length(zones) > 0 ? zones : null)
    routeServerDefintion: {
      azureFirewallResourceId: azureFirewall.outputs.resourceId
      vNetResourceId: virtualNetwork.outputs.resourceId
      sku: routeServerDefintion.?sku ?? 'Basic'
      minCapacity: routeServerDefintion.?minCapacity  ?? 1
      allowBranchToBranchTraffic: routeServerDefintion.?allowBranchToBranchTraffic ?? false
      virtualRouterAsn: routeServerDefintion.?virtualRouterAsn ?? 65515
      hubRoutingPreference: routeServerDefintion.?hubRoutingPreference ?? 'ExpressRoute'      
    }
    diagnosticsStorage: diagnosticsStorage
    enableTelemetry: enableTelemetry
  }
}

// Azure Firewall Policy

// Azure Firewall

module azureFirewall 'br/public:avm/res/network/azure-firewall:0.6.0' = if(selectResource.?azureFirewall!) {
  scope: networkRg
  name: take('netRg-afw-${uniqueString(deployment().name, location)}', 64)
  params: {
    name: '${networkRg.name}-afw'
  }
}

// Azure Bastion

module azureBastion 'br/public:avm/res/network/bastion-host:0.6.1' = if(selectResource.?azureBastion!) {
  scope: networkRg
  name: take('netRg-azb-${uniqueString(deployment().name, location)}', 64)
  params: {
    location: location
    name: '${networkRg.name}-bas'
    tags: union(tags, {
      Purpose: 'A shared bastion for RDP/SSH access to virtual machines'
    })
    virtualNetworkResourceId: virtualNetwork.outputs.resourceId
    disableCopyPaste: bastionDefinition.?disableCopyPaste ?? true
    enableFileCopy: bastionDefinition.?enableFileCopy ?? false
    enableIpConnect: bastionDefinition.?enableIpConnect ?? false
    enableShareableLink: bastionDefinition.?enableShareableLink ?? false
    roleAssignments: bastionDefinition.?roleAssignments ?? []
    scaleUnits: bastionDefinition.?bastionHost.?scaleUnits ?? 1
    skuName: bastionDefinition.?bastionHost.?skuName ?? 'Basic'
    enableKerberos: bastionDefinition.?bastionHost.?enableKerberos ?? false
    diagnosticSettings: monitoringSettings
    enableTelemetry: enableTelemetry
  }
}

// Budget

// NVA Router Resource Group

// NVA Firewall Resource Group

// =============== //
// Outputs         //
// =============== //

// ================ //
// Definitions      //
// ================ //

type selectResourceType = {
  @description('Optional. Should monitoring be enabled or not.')
  monitoring: bool?

  @description('Optional. Should the VPN Virtual Network Gateway be deployed or not.')
  vpnVirtualNetworkGateway: bool?

  @description('Optional. Should the ExpressRoute Virtual Network Gateway be deployed or not.')
  expressRouteVirtualNetworkGateway: bool?

  @description('Optional. Should the Azure Route Server be deployed or not.')
  azureRouteServer: bool?

  @description('Optional. Should the Azure Firewall be deployed or not.')
  azureFirewall: bool?

  @description('Optional. Should the Azure Bastion be deployed or not.')
  azureBastion: bool?

  @description('Optional. Should the Resource Group for a third-party router be deployed or not.')
  nvaRouter: bool?

  @description('Optional. Should the Resource Group for a third-party firewall be deployed or not.')
  nvaFirewall: bool?

  @description('Optional. Should the budget be deployed or not.')
  budget: bool?
}

type routesDefinitionType = routeDefinitionType[]

type routeDefinitionType = {
  @description('Mandatory. The name of the User-Defined Route.')
  name: string

  @description('Optional. The properties of the User-Defined Route.')
  properties: routeProperties
}

type routeProperties = {
  @description('Optional. The adddress prefix of the User-Defined Route.')
  addressPrefix: string

  @description('Optional. The next hope of the User-Defined Route.')
  nextHopType: routeNextHopTypeType

  @description('Optional. Used to provide the IP address of a VirtualAppliance next hop type.')
  nextHopIpAddress: string?
}

type routeNextHopTypeType = 'Internet' | 'None' | 'VirtualAppliance' | 'VirtualNetworkGateway' | 'VnetLocal'

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

type bastionDefinitionType = {
  @description('Optional. Is copy/paste disabled. Default = true.')
  disableCopyPaste: bool?

  @description('Optional. Is file copy enabled. Default = false.')
  enableFileCopy: bool?

  @description('Optional. Is IP connect enabled. Default = false.')
  enableIpConnect: bool?

  @description('Optional. Is shareable link enbled. Default = false.')
  enableShareableLink: bool?

  @description('Optional. The number of scale units to deploy. Default = 1.')
  scaleUnits: int?

  @description('Optional. The tier of Azure Bastion to deploy. Default = Basic.')
  skuName: string?

  @description('Optional. Is Kerberos enabled. Default = false.')
  enableKerberos: bool?
}

type  bastionSkuNameType = string

type routeServerDefintionType = {
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
}

type routeServerHubRoutingPreferenceType =   'ASPath' | 'ExpressRoute' | 'VpnGateway'
