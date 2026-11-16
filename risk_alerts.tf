# Forwards AWS Health RISK events (for example exposed access keys) from this
# account to an incident SNS topic, usually a shared topic in another account
# created with modules/risk-alert-topic. EventBridge delivers to the topic
# directly, using a role in this account that may only publish to it.
#
# The rule is created in the topic's region. AWS Health sends account-wide
# events such as exposed keys to us-east-1 (us-gov-west-1 in GovCloud), so the
# topic has to live there.

data "aws_caller_identity" "current" {
  count = var.risk_alerts == null ? 0 : 1
}

locals {
  risk_alerts_region = try(split(":", var.risk_alerts.sns_topic_arn)[3], null)
}

resource "aws_cloudwatch_event_rule" "health_risk" {
  count = var.risk_alerts == null ? 0 : 1

  region      = local.risk_alerts_region
  name        = var.risk_alerts.name
  description = "AWS Health RISK events (e.g. exposed access keys) to the incident topic"
  event_pattern = jsonencode({
    source        = ["aws.health"]
    "detail-type" = ["AWS Health Event"]
    detail = {
      service = ["RISK"]
    }
  })
  tags = var.tags
}

data "aws_iam_policy_document" "health_risk_trust" {
  count = var.risk_alerts == null ? 0 : 1

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current[0].account_id]
    }
  }
}

data "aws_iam_policy_document" "health_risk_publish" {
  count = var.risk_alerts == null ? 0 : 1

  statement {
    actions   = ["sns:Publish"]
    resources = [var.risk_alerts.sns_topic_arn]
  }
}

resource "aws_iam_role" "health_risk" {
  count = var.risk_alerts == null ? 0 : 1

  name               = var.risk_alerts.name
  assume_role_policy = data.aws_iam_policy_document.health_risk_trust[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy" "health_risk" {
  count = var.risk_alerts == null ? 0 : 1

  name   = "publish-to-incident-topic"
  role   = aws_iam_role.health_risk[0].id
  policy = data.aws_iam_policy_document.health_risk_publish[0].json
}

resource "aws_cloudwatch_event_target" "health_risk" {
  count = var.risk_alerts == null ? 0 : 1

  region   = local.risk_alerts_region
  rule     = aws_cloudwatch_event_rule.health_risk[0].name
  arn      = var.risk_alerts.sns_topic_arn
  role_arn = aws_iam_role.health_risk[0].arn
}
