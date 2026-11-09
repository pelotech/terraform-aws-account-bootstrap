variable "github" {
  type = object({
    repository                = string
    apply_subjects            = list(string)
    plan_subjects             = list(string)
    apply_role_name           = optional(string, "ci-apply")
    plan_role_name            = optional(string, "ci-plan")
    plan_policy_arns          = optional(list(string), [])
    sso_admin_permission_sets = optional(list(string), [])
  })
  default     = null
  description = <<-EOT
    GitHub Actions access to this account: an OIDC provider plus an apply role (AdministratorAccess) and a plan role (ReadOnlyAccess). Null creates none of them.
      - repository: owner/name, as it appears in the OIDC sub claim. If the organization or repository customizes the sub claim to include IDs, use owner@owner_id/name@repo_id.
      - apply_subjects / plan_subjects: OIDC subject claims each role trusts, without the repo:<repository>: prefix, e.g. ["environment:prod"], ["ref:refs/heads/main"], ["pull_request"].
      - apply_role_name / plan_role_name: role names (default ci-apply / ci-plan).
      - plan_policy_arns: extra policy ARNs for the plan role.
      - sso_admin_permission_sets: Identity Center permission sets (e.g. ["AdministratorAccess"]) whose roles in this account may assume the apply role, to reach what only the apply role can (EKS cluster-creator admin, KMS keys it administers).
  EOT

  validation {
    condition     = var.github == null || try(can(regex("^[A-Za-z0-9_.-]+(@[0-9]+)?/[A-Za-z0-9_.-]+(@[0-9]+)?$", var.github.repository)), false)
    error_message = "github.repository must be owner/name or owner@owner_id/name@repo_id."
  }

  validation {
    condition     = var.github == null || try(length(var.github.apply_subjects) > 0 && length(var.github.plan_subjects) > 0, false)
    error_message = "github.apply_subjects and github.plan_subjects must each list at least one subject."
  }

  validation {
    condition     = var.github == null || try(var.github.apply_role_name != var.github.plan_role_name, false)
    error_message = "github.apply_role_name and github.plan_role_name must differ."
  }
}

variable "state_bucket" {
  type = object({
    name                    = string
    noncurrent_version_days = optional(number)
  })
  default     = null
  description = <<-EOT
    S3 bucket for this account's Terraform state. Null creates no bucket.
      - name: bucket name.
      - noncurrent_version_days: expire old state versions after this many days. Null keeps every version.
  EOT

  validation {
    condition     = try(var.state_bucket.noncurrent_version_days == null || var.state_bucket.noncurrent_version_days >= 1, true)
    error_message = "state_bucket.noncurrent_version_days must be at least 1."
  }
}

variable "management_account" {
  type = object({
    id                                 = string
    create_organization_access_role    = optional(bool, false)
    create_controltower_execution_role = optional(bool, false)
    previous_management_account_ids    = optional(list(string), [])
  })
  default     = null
  description = <<-EOT
    Roles the organization management account uses to reach this account, each AdministratorAccess and trusting only the management account. Null (e.g. in the management account itself) creates none.
      - id: management account ID.
      - create_organization_access_role: OrganizationAccountAccessRole. Organizations creates it only for accounts it creates, so set this for accounts invited into the organization.
      - create_controltower_execution_role: AWSControlTowerExecution, which Control Tower needs to enroll an existing account.
      - previous_management_account_ids: also trusted by OrganizationAccountAccessRole while migrating an account transferred from another organization; set back to [] at cutover.
  EOT

  validation {
    condition = var.management_account == null || try(alltrue([
      for id in concat([var.management_account.id], var.management_account.previous_management_account_ids) : can(regex("^[0-9]{12}$", id))
    ]), false)
    error_message = "management_account.id and previous_management_account_ids must be 12-digit AWS account IDs."
  }

  validation {
    condition     = var.management_account == null || try(var.management_account.create_organization_access_role || var.management_account.create_controltower_execution_role, false)
    error_message = "management_account creates nothing: set create_organization_access_role and/or create_controltower_execution_role, or leave management_account null."
  }

  validation {
    condition     = var.management_account == null || try(length(var.management_account.previous_management_account_ids) == 0 || var.management_account.create_organization_access_role, false)
    error_message = "management_account.previous_management_account_ids needs create_organization_access_role."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to the resources this module creates."
}
