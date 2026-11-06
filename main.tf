# Baseline for one AWS account: GitHub OIDC provider with CI roles, a
# tfstate bucket, and the Control Tower execution role. The caller passes the
# provider for the target account.

data "aws_partition" "current" {}

# Identity Center roles live under /aws-reserved/sso.amazonaws.com/<region>/.
data "aws_iam_roles" "sso_admin" {
  count       = length(var.sso_admin_permission_sets) == 0 ? 0 : 1
  name_regex  = "^AWSReservedSSO_(${join("|", var.sso_admin_permission_sets)})_[0-9a-f]+$"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

locals {
  partition = data.aws_partition.current.partition

  # "path/name" from each role ARN, as pelotech/oidc-github expects.
  sso_admin_role_names = [
    for arn in try(data.aws_iam_roles.sso_admin[0].arns, []) : split(":role/", arn)[1]
  ]

  base_roles = {
    (var.apply_role_name) = {
      subject_repos     = ["repo:${var.github_repository}:ref:refs/heads/${var.main_branch}"]
      policy_arns       = ["arn:${local.partition}:iam::aws:policy/AdministratorAccess"]
      assume_role_names = sort(local.sso_admin_role_names)
    }
    (var.plan_role_name) = {
      subject_repos     = ["repo:${var.github_repository}:*"]
      policy_arns       = concat(["arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"], var.plan_policy_arns)
      assume_role_names = null
    }
  }
}

module "oidc" {
  source  = "pelotech/oidc-github/aws"
  version = "1.2.0"

  roles = merge(local.base_roles, var.additional_roles)
  tags  = var.tags
}
