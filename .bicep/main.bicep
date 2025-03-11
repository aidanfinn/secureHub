metadata name = 'Hub Networking'
metadata description = 'This module will deploy a hub for a zero-trust hub & spoke network.'

// ============== //
// Parameters     //
// ============== //

@description('Optional. Location for all Resources.')
param location string = resourceGroup().location

@description('Optional. Enable/Disable usage telemetry for module.')
param enableTelemetry bool = false

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
