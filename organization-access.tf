# OrganizationAccountAccessRole, the role the organization management account
# assumes to administer a member account. Organizations creates it only for
# accounts it creates; accounts invited into the organization (all GovCloud
# members) don't get it, so this opts in to creating it by hand. Trusts only
# the organization management account, plus organization_access_extra_trusted_account_ids
# while an account transferred from another organization is being migrated.
# https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_accounts_access.html

locals {
  # compact() drops a null management_account_id; var validation requires it when the role is on.
  organization_access_trusted_arns = [
    for id in compact(concat([var.management_account_id], var.organization_access_extra_trusted_account_ids)) :
    "arn:${local.partition}:iam::${id}:root"
  ]
}

data "aws_iam_policy_document" "organization_access_trust" {
  count = var.create_organization_access_role ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = local.organization_access_trusted_arns
    }
  }
}

resource "aws_iam_role" "organization_access" {
  count              = var.create_organization_access_role ? 1 : 0
  name               = "OrganizationAccountAccessRole"
  assume_role_policy = data.aws_iam_policy_document.organization_access_trust[0].json
  tags               = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "organization_access" {
  count      = var.create_organization_access_role ? 1 : 0
  role       = aws_iam_role.organization_access[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AdministratorAccess"
}
