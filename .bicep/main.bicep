metadata name = 'Hub Networking'
metadata description = 'This module will deploy a hub for a zero-trust hub & spoke network.'

targetScope = 'subscription'

// ============== //
// Parameters     //
// ============== //

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

// ============== //
// Variables      //
// ============== //

// ============== //
// Resources      //
// ============== //

// Network Watcher Resource Group

resource networkWatcherRg 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: 'NetworkWatcherRG'
  location: location
}

// Network Watcher

module networkWatcher 'br/public:avm/res/network/network-watcher:0.4.0' = {
  scope: networkWatcherRg
  name: '${uniqueString(deployment().name, location)}-nw'
  params: {
    name: 'NetworkWatcher_${location}'
    location: location
  }
}

// VNet Flow Logs

// Network resource group

// Virtual Network

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
//
// Add your User-defined-types here, if any
//


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
