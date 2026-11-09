# AWSControlTowerExecution role, required before Control Tower can enroll an
# existing account (or adopt it as Audit / Log Archive). Trusts only the
# organization management account. Inert until Control Tower uses it.
# https://docs.aws.amazon.com/controltower/latest/userguide/enroll-manually.html

data "aws_iam_policy_document" "controltower_execution_trust" {
  count = var.management_account_id == null ? 0 : 1
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${var.management_account_id}:root"]
    }
  }
}

resource "aws_iam_role" "controltower_execution" {
  count              = var.management_account_id == null ? 0 : 1
  name               = "AWSControlTowerExecution"
  assume_role_policy = data.aws_iam_policy_document.controltower_execution_trust[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "controltower_execution" {
  count      = var.management_account_id == null ? 0 : 1
  role       = aws_iam_role.controltower_execution[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AdministratorAccess"
}
