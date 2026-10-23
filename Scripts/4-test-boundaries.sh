#!/usr/bin/env bash
# 04-test-boundaries.sh - Automated security boundary verification

set -u

echo "=========================================================="
echo "TEST 1: Attempt to delete locked VNet inside rg-app-dev"
echo "=========================================================="
az network vnet delete \
  --resource-group "rg-app-dev" \
  --name "vnet-test-01" 2>&1 | tee /tmp/lock-test.log || true

if grep -q "ScopeLocked" /tmp/lock-test.log; then
  echo -e "\n[PASS] Deletion blocked by Resource Lock as expected!\n"
else
  echo -e "\n[CHECK] Expected ScopeLocked error.\n"
fi

echo "=========================================================="
echo "TEST 2: Attempt to create untagged Resource Group"
echo "=========================================================="
az group create \
  --name "rg-policy-violation" \
  --location "eastus" 2>&1 | tee /tmp/policy-test.log || true

if grep -q "RequestDisallowedByPolicy" /tmp/policy-test.log; then
  echo -e "\n[PASS] Creation blocked by Azure Policy as expected!\n"
else
  echo -e "\n[CHECK] Expected RequestDisallowedByPolicy error.\n"
fi