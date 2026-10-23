#!/bin/bash

LOCATION=centralindia

# Create Resource Groups
echo "==> Creating Resource Groups for the application..."
az group create \
--name "rg-core-infra" \
--location "$LOCATION" \
--tags Environment=Production
echo "==> Creating Development Resource Group..."
az group create \
--name "rg-app-dev" \
--location "$LOCATION" \
--tags Environment=Development
echo "==> Creating Test Resource Group..."
az network vnet create --name "dev-vnet-1" \
  --resource-group "rg-app-dev" \
  --location "centralindia" \
  --address-prefixes 10.0.0.0/16 \
  --subnet-name "snet-default" \
  --subnet-prefixes 10.0.0.0/24

# Create a resource lock on the production resource group to prevent accidental deletion
echo "==> Applying Resource Lock on Production Resource Group..."
az lock create \
--name "lock-prevent-deletion" \
--lock-type CanNotDelete \
--resource-group "rg-core-infra" \
--notes "This lock is applied to prevent accidental deletion of critical resources in the production environment."
echo "==> Applying Resource Lock on Development Resource Group..."s
az lock create \
--name "lock-app-deletion" \
--lock-type CanNotDelete \
--resource-group "rg-app-dev" \
--notes "This lock is applied to prevent accidental deletion of critical resources in the development environment."

