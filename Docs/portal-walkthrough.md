# Azure Portal & Microsoft Entra Admin Center GUI Walkthrough

This document records the interactive configuration, auditing, and boundary-verification workflows executed across the **Microsoft Entra Admin Center** and the **Azure Portal** for the **Azure Zero-Trust Governance & Delegated Access Framework**.

---

## Prerequisite: Microsoft Entra ID P2 Trial Activation

Administrative Units (scoped role assignments), Privileged Identity Management (PIM), and Access Reviews require a Microsoft Entra ID P2 license.

1. Open the [Microsoft Entra Admin Center](https://entra.microsoft.com/).
2. Navigate to **Identity** $\rightarrow$ **Billing** $\rightarrow$ **Licenses** $\rightarrow$ **Overview**.
3. Select **+ Try / Buy** $\rightarrow$ locate **Microsoft Entra ID P2** $\rightarrow$ select **Free trial** $\rightarrow$ **Activate**.
4. Go to **Licenses** $\rightarrow$ **All products** $\rightarrow$ select **Microsoft Entra ID P2** $\rightarrow$ click **+ Assign**.
5. Assign licenses to the primary administrator account and `SecLead-Test`.

---

## Phase 1: Identity Plane Delegation & Escalation Guardrails

### 1.1 Scoped Administration via Administrative Units (AU)
**Objective:** Allow `SecLead-Test` to manage developer accounts (`DevUser-Test`) without granting tenant-wide user management rights over sensitive accounts (`Auditor-Test`).

**Portal Configuration:**
1. Navigate to **Identity** $\rightarrow$ **Roles & admins** $\rightarrow$ **Administrative units** $\rightarrow$ **+ Add**.
2. Set **Name** to `AU-ApplicationTeam` and click **Review + create** $\rightarrow$ **Create**.
3. Open `AU-ApplicationTeam` $\rightarrow$ **Users** $\rightarrow$ **+ Add member** $\rightarrow$ select `DevUser-Test`.
4. Select **Roles and administrators** inside the AU $\rightarrow$ click **User Administrator** $\rightarrow$ **+ Add assignments** $\rightarrow$ select `SecLead-Test`.

**GUI Verification Test:**
1. Open an InPrivate/Incognito browser session and sign in as `seclead-test@<domain>`.
2. Go to **Users** $\rightarrow$ select `DevUser-Test` $\rightarrow$ click **Reset password**.
   * **Result:** Password reset succeeds (`DevUser-Test` is a member of `AU-ApplicationTeam`).
3. Go back to **Users** $\rightarrow$ select `Auditor-Test` $\rightarrow$ click **Reset password**.
   * **Result:** Operation is blocked with an **Insufficient privileges / Access Denied** banner because `Auditor-Test` sits outside the AU boundary.
* **Evidence Captured:** `screenshots/01-au-scoped-admin.png`

---

### 1.2 Privilege Escalation Defense (`isRoleAssignable = true`)
**Objective:** Prevent standard User or Groups Administrators from adding themselves or others into high-privilege security groups.

**Portal Configuration:**
1. Navigate to **Identity** $\rightarrow$ **Groups** $\rightarrow$ **All groups** $\rightarrow$ **New group**.
2. Set:
   * **Group type:** `Security`
   * **Group name:** `sg-cloud-privileged`
   * **Membership type:** `Assigned`
   * **Microsoft Entra roles can be assigned to the group:** `Yes` *(Immutable after creation)*
3. Click **Create**.

**GUI Verification Test:**
1. In the **All groups** view, verify the column **Assignable to role** displays `Yes` for `sg-cloud-privileged`.
2. Using the `SecLead-Test` session (or a tenant-level User Administrator account), open `sg-cloud-privileged` $\rightarrow$ **Members** $\rightarrow$ note that **+ Add members** is disabled or returns an `Authorization_RequestDenied` error. Only *Global Administrators*, *Privileged Role Administrators*, or explicit group Owners can modify membership.
* **Evidence Captured:** `screenshots/02-role-assignable-group.png`

---

## Phase 2: Hierarchical Additive RBAC Verification

**Objective:** Verify that assigning `Reader` at the Subscription level and `Contributor` at the `rg-app-dev` Resource Group level results in elevated permissions strictly within the target child scope.

**Portal Configuration & Audit:**
1. In the [Azure Portal](https://portal.azure.com/), open **Subscriptions** $\rightarrow$ select the Trial Subscription $\rightarrow$ **Access control (IAM)**.
2. Verify `DevUser-Test` holds the **Reader** role scoped to `This resource` (Subscription).
3. Navigate to **Resource groups** $\rightarrow$ open `rg-core-infra` $\rightarrow$ **Access control (IAM)** $\rightarrow$ click **Check access**.
   * Search for `DevUser-Test`.
   * **Effective Access:** `Reader` (Inherited from Subscription).
4. Navigate to **Resource groups** $\rightarrow$ open `rg-app-dev` $\rightarrow$ **Access control (IAM)** $\rightarrow$ click **Check access**.
   * Search for `DevUser-Test`.
   * **Effective Access:** Displays **both** `Reader` (Inherited from Subscription) and `Contributor` (Assigned directly to this resource group). Because Azure RBAC is strictly additive, `DevUser-Test` operates with full `Contributor` rights inside `rg-app-dev`.
* **Evidence Captured:** `screenshots/03-rbac-check-access.png`

---

## Phase 3: ARM Resource Locks vs. RBAC Contributor Rights

**Objective:** Prove that Azure Resource Manager (ARM) `CanNotDelete` locks intercept and block deletion requests before RBAC permissions are honored.

**Portal Configuration:**
1. Open Resource Group `rg-app-dev` $\rightarrow$ under **Settings**, select **Locks** $\rightarrow$ **+ Add**.
2. Set **Lock name** to `lock-prevent-deletion` and **Lock type** to `Delete` (`CanNotDelete`). Click **OK**.

**GUI Verification Test:**
1. Sign in to the Azure Portal as `DevUser-Test` (who holds `Contributor` on `rg-app-dev`).
2. Open `rg-app-dev` $\rightarrow$ select the Virtual Network `vnet-test-01` $\rightarrow$ click **Delete** and confirm.
   * **Result:** Deployment deletion fails with error code **`ScopeLocked`**: *"The scope '.../vnet-test-01' cannot perform delete operation because following scope(s) are locked: '.../resourceGroups/rg-app-dev'."*
3. Navigate to `rg-app-dev` $\rightarrow$ **Locks** $\rightarrow$ attempt to delete `lock-prevent-deletion` as `DevUser-Test`.
   * **Result:** Blocked. The `Contributor` role includes `NotActions: Microsoft.Authorization/*`, preventing non-Owners from removing locks.
* **Evidence Captured:** `screenshots/04-lock-delete-blocked.png`

---

## Phase 4: Azure Policy Tag Enforcement & Exemptions

**Objective:** Enforce mandatory FinOps tagging (`Environment=Production`) across the subscription while carving out an approved audit waiver for `rg-audit-exempt`.

**Portal Configuration:**
1. Search for **Policy** in the Azure Portal $\rightarrow$ **Authoring** $\rightarrow$ **Assignments** $\rightarrow$ **Assign policy**.
2. Configure the assignment:
   * **Scope:** Trial Subscription
   * **Policy definition:** `Require a tag and its value on resource groups`
   * **Parameters:** Tag Name = `Environment`, Tag Value = `Production`
3. Navigate to **Policy** $\rightarrow$ **Authoring** $\rightarrow$ **Exemptions** $\rightarrow$ **+ Add exemption**.
4. Configure the exemption:
   * **Exemption scope:** `rg-audit-exempt`
   * **Policy assignment:** `Enforce Environment Tag on Resource Groups`
   * **Exemption category:** `Waiver`

**GUI Verification Test:**
1. Go to **Resource groups** $\rightarrow$ click **+ Create**.
2. Enter name `rg-policy-violation`, leave the **Tags** tab empty, and click **Review + create**.
   * **Result:** Validation fails with a red banner. Clicking the error details reveals **`RequestDisallowedByPolicy`** triggered by `enforce-env-tag`.
3. Open **Policy** $\rightarrow$ **Compliance** $\rightarrow$ verify `rg-audit-exempt` is listed under the **Exempt** state rather than Non-compliant.
* **Evidence Captured:** `screenshots/05-policy-waiver-exemption.png`

---

## Phase 5: Privileged Identity Management (PIM) & Access Reviews

### 5.1 Just-In-Time (JIT) Role Activation in PIM
1. Open **Microsoft Entra Privileged Identity Management** $\rightarrow$ **Manage** $\rightarrow$ **Azure resources** $\rightarrow$ select the Trial Subscription.
2. Under **Manage** $\rightarrow$ **Roles**, select **Owner** $\rightarrow$ **Settings** $\rightarrow$ **Edit**:
   * Set **Activation maximum duration (hours):** `4`
   * Enable **Require justification on activation** and **Require Azure Multi-Factor Authentication on activation**.
3. Sign in as `SecLead-Test` $\rightarrow$ go to **PIM** $\rightarrow$ **My roles** $\rightarrow$ **Azure resources** $\rightarrow$ **Eligible assignments**.
4. Click **Activate** next to `Owner`, provide a ticket number/justification, and verify the time-bound elevation becomes active.

### 5.2 Automated Guest Lifecycle Access Review
1. Navigate to **Identity governance** $\rightarrow$ **Access reviews** $\rightarrow$ **+ New access review**.
2. Configure:
   * **Select what to review:** `Teams + Groups` $\rightarrow$ select `sg-external-collab`
   * **Scope:** `Guest users only`
   * **Reviewers:** `Group owner(s)` (with `SecLead-Test` as fallback reviewer)
   * **Recurrence:** `Quarterly`, Duration: `14 days`
   * **Upon completion settings:** Enable `Auto apply results to resource`; set **If reviewers don't respond** to `Remove access`.
3. Click **Create** and verify the review status transitions to **Active**.