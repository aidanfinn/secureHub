metadata name = 'Hub Networking'
metadata description = 'This module will deploy a hub for a zero-trust hub & spoke network.'

// ============== //
// Parameters     //
// ============== //

@description('Optional. Location for all Resources.')
param location string = resourceGroup().location

@description('Optional. Enable/Disable usage telemetry for module.')
param enableTelemetry bool = false

@description('Optional: Select which resources will be deployed.')
param selectResources object = {
  monitoring: true

}

// ============== //
// Variables      //
// ============== //

// ============== //
// Resources      //
// ============== //

// Network Watcher

// VNet Flow Logs

// Virtual Network

// VPN Virtual Network Gateway

// ExpressRoute Virtual Network Gateway

// Azure Route Server

// Azure Firewall Policy

// Azure Firewall

// Azure Bastion

// Budget

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
