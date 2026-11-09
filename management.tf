# Roles the organization management account assumes to administer this
# account. Both are AdministratorAccess and trust only the management account
# (plus, for OrganizationAccountAccessRole, any previous management account
# while a transferred account is migrated).
#
# OrganizationAccountAccessRole: Organizations creates it only for accounts it
# creates; invited accounts (all GovCloud members) need it created by hand.
# https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_accounts_access.html
#
# AWSControlTowerExecution: required before Control Tower can enroll an existing
# account (or adopt it as Audit / Log Archive). Inert until Control Tower uses it.
# https://docs.aws.amazon.com/controltower/latest/userguide/enroll-manually.html

locals {
  # Role name => account IDs it trusts.
  management_roles = merge(
    try(var.management_account.create_organization_access_role, false) ? {
      OrganizationAccountAccessRole = concat([var.management_account.id], var.management_account.previous_management_account_ids)
    } : {},
    try(var.management_account.create_controltower_execution_role, false) ? {
      AWSControlTowerExecution = [var.management_account.id]
    } : {},
  )
}

resource "aws_iam_role" "management" {
  for_each = local.management_roles
  name     = each.key
  tags     = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = [for id in each.value : "arn:${local.partition}:iam::${id}:root"] }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "management" {
  for_each   = aws_iam_role.management
  role       = each.value.name
  policy_arn = local.admin_arn
}

# TODO: remove once existing deployments have applied v0.1.0.
moved {
  from = aws_iam_role.organization_access[0]
  to   = aws_iam_role.management["OrganizationAccountAccessRole"]
}

moved {
  from = aws_iam_role_policy_attachment.organization_access[0]
  to   = aws_iam_role_policy_attachment.management["OrganizationAccountAccessRole"]
}

moved {
  from = aws_iam_role.controltower_execution[0]
  to   = aws_iam_role.management["AWSControlTowerExecution"]
}

moved {
  from = aws_iam_role_policy_attachment.controltower_execution[0]
  to   = aws_iam_role_policy_attachment.management["AWSControlTowerExecution"]
}
