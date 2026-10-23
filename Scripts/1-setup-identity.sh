DOMAIN=$(az rest --method get --uri "https://graph.microsoft.com/v1.0/domains" \
  --query "value[?isDefault].id" -o tsv)

echo "==> Creating user accounts in Azure AD for testing purposes..."

# Create test users
echo "==> Creating SecLead Test user..."
az ad user create --display-name "SecLead Test" \
--password "TempPassword@12345!" \
--user-principal-name "SecLead-Test@${DOMAIN}" \
--force-change-password-next-sign-in false
echo "==> Creating DevUser Test user..."
az ad user create --display-name "DevUser Test" \
--password "TempPassword@12345!" \
--user-principal-name "DevUser-Test@${DOMAIN}" \
--force-change-password-next-sign-in false
echo "==> Creating Auditor Test user..."
az ad user create --display-name "Auditor Test" \
--password "TempPassword@12345!" \
--user-principal-name "Auditor-Test@${DOMAIN}" \
--force-change-password-next-sign-in false

echo "==> User accounts created successfully."


# 2. Create Administrative Unit (AU)
echo "==> Creating Administrative Unit: AU-ApplicationTeam..."
AU_ID=$(az rest --method post \
  --uri "https://graph.microsoft.com/v1.0/directory/administrativeUnits" \
  --headers "Content-Type=application/json" \
  --body '{"displayName": "AU-ApplicationTeam", "description": "Scoped management for app team"}' \
  --query id -o tsv)

echo "==> Administrative Unit created with ID: ${AU_ID}"
DEV_ID=$(az ad user show --id "devuser-test@${DOMAIN}" --query id -o tsv)
SEC_ID=$(az ad user show --id "seclead-test@${DOMAIN}" --query id -o tsv)

# Add DevUser to AU
echo "==> Adding DevUser to Administrative Unit..."
az rest --method post \
  --uri "https://graph.microsoft.com/v1.0/directory/administrativeUnits/${AU_ID}/members/\$ref" \
  --headers "Content-Type=application/json" \
  --body "{\"@odata.id\": \"https://graph.microsoft.com/v1.0/directoryObjects/${DEV_ID}\"}"

# Assign "User Administrator" role scoped to the AU
USER_ADMIN_ROLE_ID="fe930be7-5e62-47db-91af-98c304fb37e2"

echo "==> Scoping User Administrator role to SecLead over AU..."
az rest --method post \
  --uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments" \
  --headers "Content-Type=application/json" \
  --body "{
    \"roleDefinitionId\": \"${USER_ADMIN_ROLE_ID}\",
    \"principalId\": \"${SEC_ID}\",
    \"directoryScopeId\": \"/administrativeUnits/${AU_ID}\"
  }"


# Using Azure CLI to create a security group that is not role assignable

#  az ad group create \
#  --display-name "sg-cloud-privileged-non-role-assinable" \
#  --mail-nickname "sg-cloud-privileged-non-role-assinable" \
#  --description "Security Group for Privileged Users (Non-Role Assignable)" 



# Using Microsoft Graph API to create a security group that is role assignable

# az rest --method post \
# --uri "https://graph.microsoft.com/v1.0/groups" \
# --headers "Content-Type=application/json" \
# --body '{
#         "displayName": "sg-cloud-privileged-role-assignable",
#         "mailNickname": "sg-cloud-privileged-role-assignable",
#         "description": "Security Group for Privileged Users (Role Assignable)",
#         "securityEnabled": true,
#         "isAssignableToRole": true,
#         "mailEnabled": false
#     }'
echo "==> Creating a role-assignable security group for privileged users..."
az rest --method post \
  --uri "https://graph.microsoft.com/v1.0/groups" \
  --headers "Content-Type=application/json" \
  --body '{
    "displayName": "sg-cloud-privileged",
    "description": "Privileged security group for role assignments",
    "mailNickname": "sg-cloud-privileged",
    "mailEnabled": false,
    "securityEnabled": true,
    "isAssignableToRole": true
  }'
    echo "==> Role-assignable security group created successfully."