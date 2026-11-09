variable "github_repository" {
  type        = string
  description = "GitHub repository (owner/name) that manages this account's infrastructure. main_branch can assume the apply role, every ref the plan role."
}

variable "main_branch" {
  type        = string
  default     = "main"
  description = "Branch of github_repository allowed to assume the apply role."
}

variable "apply_role_name" {
  type        = string
  default     = "gh-apply"
  description = "Name of the admin role CI assumes to apply, from main_branch only."
}

variable "plan_role_name" {
  type        = string
  default     = "gh-plan"
  description = "Name of the read-only role CI assumes to plan, from any ref."
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

variable "management_account_id" {
  type        = string
  default     = null
  description = "Organization management account ID trusted by the AWSControlTowerExecution role and, when create_organization_access_role is true, the OrganizationAccountAccessRole. Null skips both roles (use null for the management account itself)."
}

variable "create_organization_access_role" {
  type        = bool
  default     = false
  description = "Create OrganizationAccountAccessRole, trusting management_account_id. Needed for accounts invited into the organization (Organizations only creates it for accounts it creates). Requires management_account_id."
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
