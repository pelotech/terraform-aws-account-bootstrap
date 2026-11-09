# What one AWS account needs before CI can manage it: CI access (GitHub OIDC
# provider plus apply and plan roles), a Terraform state bucket, and the roles
# the organization management account uses to reach it. Every part is optional.
# The caller passes the provider for the target account.

data "aws_partition" "current" {}

locals {
  partition                 = data.aws_partition.current.partition
  admin_arn                 = "arn:${local.partition}:iam::aws:policy/AdministratorAccess"
  sso_admin_permission_sets = try(var.github.sso_admin_permission_sets, [])
}

# Identity Center roles live under /aws-reserved/sso.amazonaws.com/<region>/ and
# are named AWSReservedSSO_<permission set>_<random suffix>.
data "aws_iam_roles" "sso" {
  count       = length(local.sso_admin_permission_sets) == 0 ? 0 : 1
  name_regex  = "^AWSReservedSSO_"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

locals {
  # Permission set name and "path/name" (as pelotech/oidc-github expects) of
  # every Identity Center role in the account. Comparing parsed names avoids
  # building a regex out of permission set names.
  sso_roles = [
    for arn in try(data.aws_iam_roles.sso[0].arns, []) : {
      permission_set = join("_", slice(split("_", basename(arn)), 1, length(split("_", basename(arn))) - 1))
      path_name      = split(":role/", arn)[1]
    }
  ]
  sso_admin_role_names = sort([
    for r in local.sso_roles : r.path_name if contains(local.sso_admin_permission_sets, r.permission_set)
  ])
  sso_admin_unmatched = [
    for ps in local.sso_admin_permission_sets : ps if !contains(local.sso_roles[*].permission_set, ps)
  ]

  ci_roles = var.github == null ? {} : {
    (var.github.apply_role_name) = {
      subject_repos     = [for s in var.github.apply_subjects : "repo:${var.github.repository}:${s}"]
      policy_arns       = [local.admin_arn]
      assume_role_names = local.sso_admin_role_names
    }
    (var.github.plan_role_name) = {
      subject_repos     = [for s in var.github.plan_subjects : "repo:${var.github.repository}:${s}"]
      policy_arns       = concat(["arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"], var.github.plan_policy_arns)
      assume_role_names = []
    }
  }
}

# The Identity Center role only exists once the permission set is assigned to
# this account, so warn rather than fail; re-apply after assigning it.
check "sso_admin_permission_sets_found" {
  assert {
    condition     = length(local.sso_admin_unmatched) == 0
    error_message = "No Identity Center role in this account for github.sso_admin_permission_sets: ${join(", ", local.sso_admin_unmatched)}. Assign the permission set to this account, then re-apply."
  }
}

module "oidc" {
  count   = var.github == null ? 0 : 1
  source  = "pelotech/oidc-github/aws"
  version = "1.2.1"

  roles = local.ci_roles
  tags  = var.tags
}

# TODO: remove once existing deployments have applied v0.1.0.
moved {
  from = module.oidc
  to   = module.oidc[0]
}
