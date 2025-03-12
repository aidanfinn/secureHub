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

// ============== //
// Variables      //
// ============== //

var namingUniqueString = take(uniqueString(subscription().id, location), 8)


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

resource networkResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: '${name}-net'
  location: location
  tags: union(tags, {
    Purpose: 'Networking resource group'
  })
}

// GatewaySubnet Route Table

module gatewaySubnetRouteTable 'br/public:avm/res/network/route-table:0.4.0' = {
  scope: networkResourceGroup
  name: take('netRg-vnet-gatewaysubnet-${uniqueString(deployment().name, location)}', 64)
  params: {
    name: '${networkResourceGroup.name}-vnet-GatewaySubnet-rt'
    tags: union(tags, {
      Purpose: 'GatewaySubnet route table'
    })
  }
}

// RouterSubnet Route Table

// AzureFirewallManagementSubnet Route Table

// AzureBastionSubnet NSG

// Virtual Network

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.5.1' = {
  scope: networkResourceGroup
  name: take('netRg-vnet-${uniqueString(deployment().name, location)}', 64)
  params: {
    name: '${networkResourceGroup.name}-vnet'
    tags: union(tags, {
      Purpose: 'Hub virtual network'
    })
    addressPrefixes: [
      cidrSubnet(dataCentrePrefix, 22, 0)
    ]
    // subnets: [
    //   {
    //     name: 'GatewaySubnet'
    //     addressPrefix: cidrSubnet(dataCentrePrefix, 26, 0)
    //     routeTableResourceId: gatewaySubnetRouteTable.outputs.resourceId
    //   }
    //   {
    //     name: 'RouterSubnet'
    //     addressPrefix: cidrSubnet(dataCentrePrefix, 26, 1)
    //     routeTableResourceId: routerFrontendSubnetRouteTable.outputs.resourceId
    //   }

    //   {
    //     name: 'RouteServerSubnet'
    //     addressPrefix: cidrSubnet(dataCentrePrefix, 26, 14)
    //   }
    //   {
    //     name: 'AzureFirewallSubnet'
    //     addressPrefix: cidrSubnet(dataCentrePrefix, 24, 1)
    //     routeTableResourceId: azureFirewallSubnetRouteTable.outputs.resourceId
    //     serviceEndpoints: [
    //       'Microsoft.Storage'
    //       'Microsoft.Sql'
    //       'Microsoft.AzureCosmosDB'
    //       'Microsoft.KeyVault'
    //       'Microsoft.ServiceBus'
    //       'Microsoft.EventHub'
    //       'Microsoft.Web'
    //       'Microsoft.CognitiveServices'
    //     ]
    //   }
    //   {
    //     name: 'AzureFirewallManagementSubnet'
    //     addressPrefix: cidrSubnet(dataCentrePrefix, 24, 2)
    //     routeTableResourceId: azureFirewallmanagementSubnetRouteTable.outputs.resourceId
    //   }
    //   {
    //     name: 'AzureBastionSubnet'
    //     addressPrefix: cidrSubnet(dataCentrePrefix, 26, 15)
    //     networkSecurityGroupResourceId: azureBastionSubnetNsg.outputs.resourceId
    //   }
    // ]
    diagnosticSettings: diagnosticSettings
    enableTelemetry: enableTelemetry
  }
  dependsOn: [
    networkWatcher
  ]
}

// Subnets

module GatewaySubnet 'modules/subnet.bicep' = {
  scope: networkResourceGroup
  name: take('netRg-vnet-gatewaysubnet-${uniqueString(deployment().name, location)}', 64)
  params: {
    subnetConfig: {
      name: 'GatewaySubnet'
      addressPrefix: cidrSubnet(dataCentrePrefix, 26, 0)
      virtualNetworkName: virtualNetwork.outputs.name
      routeTableResourceId: gatewaySubnetRouteTable.outputs.resourceId
    }
  }
}

// VNet Flow Logs

module flowLogs 'br/public:avm/res/network/network-watcher:0.4.0' = if(selectResource.?monitoring!) {
  scope: networkWatcherRg
  name: take('networkWatcherRg-fl-${uniqueString(deployment().name, location)}', 64)
  params: {
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

// Azure Firewall Policy

// Azure Firewall

// Azure Bastion

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
