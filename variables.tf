variable "github" {
  type = object({
    repository     = string
    apply_subjects = list(string)
    plan_subjects  = list(string)
  })
  default     = null
  description = "GitHub Actions access to this account: an OIDC provider plus the apply and plan roles. repository: owner/name. apply_subjects / plan_subjects: the OIDC subject claims each role trusts, without the repo:<repository>: prefix, e.g. [\"ref:refs/heads/main\"], [\"pull_request\"], [\"environment:prod\"] or [\"*\"]. Null creates no OIDC provider or CI roles."

  validation {
    condition     = var.github == null || try(length(var.github.apply_subjects) > 0 && length(var.github.plan_subjects) > 0, false)
    error_message = "github.apply_subjects and github.plan_subjects must each list at least one subject."
  }
}

variable "apply_role_name" {
  type        = string
  default     = "ci-apply"
  description = "Name of the admin role CI assumes to apply, trusted for github.apply_subjects."
}

variable "plan_role_name" {
  type        = string
  default     = "ci-plan"
  description = "Name of the read-only role CI assumes to plan, trusted for github.plan_subjects."
}

variable "sso_admin_permission_sets" {
  type        = list(string)
  default     = []
  description = "IAM Identity Center permission sets (e.g. [\"AdministratorAccess\"]) whose roles in this account may also assume the apply role, to debug with CI's exact permissions."
}

variable "plan_policy_arns" {
  type        = list(string)
  default     = []
  description = "Extra policy ARNs for the plan role, on top of ReadOnlyAccess."
}

variable "additional_roles" {
  type = map(object({
    subject_repos        = list(string)
    policy_arns          = list(string)
    role_path            = optional(string, "/")
    assume_role_names    = optional(list(string))
    max_session_duration = optional(number)
    inline_policies      = optional(map(string), {})
  }))
  default     = {}
  description = "Extra GitHub OIDC roles to create next to the apply and plan roles, keyed by role name. Same shape as pelotech/oidc-github's roles input."
}

variable "state_bucket_name" {
  type        = string
  default     = null
  description = "Name of the S3 bucket for this account's OpenTofu state. Null skips the bucket."
}

variable "state_noncurrent_version_days" {
  type        = number
  default     = null
  description = "Expire noncurrent (old) state object versions after this many days. Null keeps every version."

  validation {
    condition     = var.state_noncurrent_version_days == null || try(var.state_noncurrent_version_days >= 1, false)
    error_message = "state_noncurrent_version_days must be at least 1."
  }
}

variable "management_account_id" {
  type        = string
  default     = null
  description = "Organization management account ID, trusted by the roles enabled with create_controltower_execution_role and create_organization_access_role. Leave null for the management account itself."
}

variable "create_controltower_execution_role" {
  type        = bool
  default     = false
  description = "Create AWSControlTowerExecution (AdministratorAccess, trusting management_account_id), which Control Tower needs to enroll an existing account. Requires management_account_id."

  validation {
    condition     = !var.create_controltower_execution_role || var.management_account_id != null
    error_message = "create_controltower_execution_role needs management_account_id."
  }
}

variable "create_organization_access_role" {
  type        = bool
  default     = false
  description = "Create OrganizationAccountAccessRole, trusting management_account_id. Needed for accounts invited into the organization (Organizations only creates it for accounts it creates). Requires management_account_id."

  validation {
    condition     = !var.create_organization_access_role || var.management_account_id != null
    error_message = "create_organization_access_role needs management_account_id."
  }
}

variable "organization_access_extra_trusted_account_ids" {
  type        = list(string)
  default     = []
  description = "Extra account IDs (e.g. the previous organization's management account) that OrganizationAccountAccessRole also trusts. Transitional: use only while migrating an account transferred from another organization, then set back to []."

  validation {
    condition     = alltrue([for id in var.organization_access_extra_trusted_account_ids : can(regex("^[0-9]{12}$", id))])
    error_message = "organization_access_extra_trusted_account_ids must be 12-digit AWS account IDs."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to the resources this module creates."
}
