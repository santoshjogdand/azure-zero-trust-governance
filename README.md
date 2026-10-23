# Azure Zero-Trust Governance & Delegated Access Framework

An enterprise-grade Azure governance baseline implemented using **Azure CLI (Bash)**, **Azure / Microsoft Entra Admin Portals** and little bit of **Microsoft Graph REST APIs**. This project enforces least-privilege identity delegation, additive RBAC hierarchies, ARM resource locks, automated Azure Policy guardrails, and Privileged Identity Management (PIM) within a single Azure subscription.

> 📖 **[Click here for the Step-by-Step Azure Portal & Entra GUI Walkthrough](./docs/portal-walkthrough.md)**

---

## Tools & Technologies Used
* **Automation & Provisioning:** Azure CLI (`az`), Bash Shell Scripting, Microsoft Graph REST API (`az rest`)
* **Identity Governance (Entra Admin Center):** Administrative Units (AUs), Role-Assignable Security Groups (`isRoleAssignable = true`), Entra ID P2 Privileged Identity Management (PIM), and Automated Access Reviews
* **Resource Governance (Azure Portal & ARM):** Hierarchical RBAC, `CanNotDelete` Resource Locks, Azure Policy Definitions, and Policy Exemptions (`Waiver`)

---

## Architecture & Security Boundaries Implemented

### 1. Scoped Identity Delegation (Administrative Units)
* Provisioned test personas (`SecLead-Test`, `DevUser-Test`, `Auditor-Test`) and an Administrative Unit (`AU-ApplicationTeam`).
* Delegated the **User Administrator** role to `SecLead-Test` scoped strictly to `AU-ApplicationTeam`.
* **Result:** `SecLead-Test` can manage passwords for developers inside the AU, but receives `HTTP 403 Forbidden` when attempting to modify `Auditor-Test` outside the AU.

### 2. Privilege Escalation Defense (`isRoleAssignable` Guardrail)
* Created `sg-cloud-privileged` with `isRoleAssignable = true` at creation.
* **Result:** Standard *User Administrators* and *Groups Administrators* are explicitly blocked at the API level from adding members to this group, neutralizing horizontal-to-vertical privilege escalation.

### 3. Hierarchical Additive RBAC
* Assigned `DevUser-Test` the **Reader** role at the Subscription root and elevated access to **Contributor** specifically on `rg-app-dev`.
* **Result:** Verified via Portal *Check Access* and CLI that the user retains global visibility across `rg-core-infra` while gaining write/deploy rights exclusively inside `rg-app-dev`.

### 4. ARM Resource Locks vs. RBAC
* Applied a parent-level `CanNotDelete` lock (`lock-prevent-deletion`) on `rg-app-dev`.
* **Result:** Demonstrated that even though `DevUser-Test` holds `Contributor` rights, attempting to delete `vnet-test-01` is intercepted and blocked by the ARM lock engine (`ScopeLocked`), and `Contributor` lacks `Microsoft.Authorization/locks/*` permissions to remove the lock.

### 5. FinOps Tag Policy & Sandbox Exemptions
* Assigned the built-in policy *Require a tag and its value on resource groups* (`Environment=Production`) across the subscription.
* Configured a **Policy Exemption** (`Waiver`) on `rg-audit-exempt`.
* **Result:** Untagged resource group creation is rejected with `RequestDisallowedByPolicy`, while resources inside `rg-audit-exempt` bypass evaluation for audit testing.

### 6. Just-In-Time (JIT) Access & Lifecycle Reviews
* Configured **Entra PIM** eligible assignments for Subscription `Owner` and `Privileged Role Administrator` (requiring ticket justification, MFA, and a 4-hour activation window).
* Deployed a recurring quarterly **Access Review** targeting guest accounts in `sg-external-collab` with 14-day inaction auto-removal.

---

## Verification Matrix

| Security Boundary | Identity Tested | Action Attempted (CLI / GUI) | Outcome | Error / Mechanism |
| :--- | :--- | :--- | :--- | :--- |
| **Administrative Unit** | `SecLead-Test` | Reset password of `Auditor-Test` in Entra Portal | **Blocked** | `Authorization_RequestDenied` |
| **Role-Assignable Group** | Standard User Admin | Add member to `sg-cloud-privileged` | **Blocked** | `Insufficient privileges` (`isRoleAssignable`) |
| **Additive RBAC** | `DevUser-Test` | Deploy resource in `rg-core-infra` vs `rg-app-dev` | **Scoped** | Denied in `rg-core-infra`; Succeeded in `rg-app-dev` |
| **ARM Resource Lock** | `DevUser-Test` | Delete `vnet-test-01` inside `rg-app-dev` | **Blocked** | `ScopeLocked` (Lock overrides RBAC) |
| **Azure Policy** | Subscription Admin | Create untagged Resource Group `rg-policy-violation` | **Blocked** | `RequestDisallowedByPolicy` |

---

## Portal & CLI Verification Evidence

### 1. Administrative Unit Scoped Delegation Block
![AU Scoped Admin](./docs/screenshots/01-au-scoped-admin.png)

### 2. Role-Assignable Security Group Guardrail
![Role Assignable Group](./docs/screenshots/02-role-assignable-group.png)

### 3. Additive RBAC Effective Access Check
![RBAC Check Access](./docs/screenshots/03-rbac-check-access.png)

### 4. ARM `CanNotDelete` Lock Overriding Contributor Role
![Lock Delete Blocked](./docs/screenshots/04-lock-delete-blocked.png)

### 5. Azure Policy Enforcement & Sandbox Waiver Exemption
![Policy Waiver Exemption](./docs/screenshots/05-policy-waiver-exemption.png)

---

## Reproducing the Setup via CLI
```bash
chmod +x scripts/*.sh
./scripts/01-setup-identity.sh
./scripts/02-deploy-infra-and-rbac.sh
./scripts/03-identity-governance.sh
./scripts/04-test-boundaries.sh