# The incident topic that accounts using the root module's risk_alerts input
# publish to. Create one per incident channel (for example one per customer),
# in us-east-1 (us-gov-west-1 in GovCloud), where AWS Health sends exposed-key
# and other RISK events.
#
# Only the risk-alert role in each listed account may publish. The role does
# not need to exist yet, so this topic can be created before those accounts
# are bootstrapped.

data "aws_partition" "current" {}

locals {
  publisher_role_arns = [for id in var.publisher_account_ids : "arn:${data.aws_partition.current.partition}:iam::${id}:role/${var.publisher_role_name}"]
}

data "aws_iam_policy_document" "topic" {
  statement {
    sid       = "AllowRiskAlertRoles"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.this.arn]
    principals {
      type        = "AWS"
      identifiers = [for id in var.publisher_account_ids : "arn:${data.aws_partition.current.partition}:iam::${id}:root"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:PrincipalArn"
      values   = local.publisher_role_arns
    }
  }
}

# No server-side encryption: the AWS managed SNS key can't be used across
# accounts, and these messages carry event metadata, not secrets.
resource "aws_sns_topic" "this" {
  region = var.region
  name   = var.name
  tags   = var.tags
}

resource "aws_sns_topic_policy" "this" {
  region = var.region
  arn    = aws_sns_topic.this.arn
  policy = data.aws_iam_policy_document.topic.json
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.email_endpoints)

  region    = var.region
  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = each.value
}
