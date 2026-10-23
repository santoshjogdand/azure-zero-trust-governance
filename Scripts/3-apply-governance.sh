#!/bin/bash

SUB_ID=$(az account show --query id -o tsv)
DOMAIN=$(az rest --method get --uri "https://graph.microsoft.com/v1.0/domains" \
  --query "value[?isDefault].id" -o tsv)
DEV_UPN="devuser-test@${DOMAIN}"

# 1. Create a custom role definition for the DevUser with limited permissions on the Subscription
echo "==> Configuring Hierarchical Additive RBAC..."

az role assignment create \
--assignee "DevUser-Test@${DOMAIN}" \
--role reader \
--scope "/subscriptions/${SUB_ID}"

# 2. Create a Contributer role assignment for the DevUser on the Development Resource Group
echo "==> Assigning Contributor role to DevUser on Development Resource Group..."
az role assignment create \
--assignee "DevUser-Test@${DOMAIN}" \
--role contributor \
--scope "/subscriptions/${SUB_ID}/resourceGroups/rg-app-dev"

# 3. Assign Built-in Azure Policy: Require tag on Resource Groups
echo "==> Assigning Tag Governance Policy at Subscription level..."

POLICY_DEF_ID=$(az policy definition list \
  --query "[?displayName=='Require a tag on resource groups'].id" \
  --output tsv)

  echo "==> Assigning Require Tag Policy at Subscription level..."

az policy assignment create \
--display-name "Enforce Environment Tag on Resource Groups" \
--name "enforce-env-tag" \
--scope "/subscriptions/757c95dd-78a8-46c1-ae58-451950eac026" \
--policy "96670d01-0a4d-4649-9c89-2d3abc0a5025" \
--params '{"tagName": {"value": "Environment"}}' \
--description "Must give environment tag to resource groups"

 POLICY_DEF_ID=$(az policy definition list \
  --query "[?displayName=='Inherit a tag from the resource group if missing'].id" \
  --output tsv)

echo "==> Assigning Inherit Tag Policy at Subscription level..."

az policy assignment create \
--display-name "Inherit environment tag" \
--name "inherit-ENV-tag" \
--scope "/subscriptions/757c95dd-78a8-46c1-ae58-451950eac026" \
--policy "ea3f2387-9b95-492a-a190-fcdc54f7b070" \
--params '{"tagName": {"value": "Environment"}}' \
--description "Inherit env tag on resources from parent resource group" \
--assign-identity true \
--location "centralindia"

echo "==> Creating Remediation Task for Inherit Tag Policy Assignment..."
az policy remediation create \
--name "remediate-inherit-tag"  \
--policy-assignment "/subscriptions/757c95dd-78a8-46c1-ae58-451950eac026/providers/Microsoft.Authorization/policyAssignments/inherit-ENV-tag" \
--resource-discovery-mode ReEvaluateCompliance

echo "==> Remediation Task created successfully."