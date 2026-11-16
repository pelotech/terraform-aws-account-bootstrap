# Sends AWS Health RISK events (for example exposed access keys) to an SNS
# topic with email subscriptions and to chat webhooks. Applied in the
# organization's AWS Health delegated administrator or management account, the
# rule sees every account's events; anywhere else, only this account's.
#
# AWS Health sends events that aren't tied to a region, such as exposed keys,
# to us-east-1 (us-gov-west-1 in GovCloud), so everything is created there
# whatever region the provider uses.

locals {
  risk_alerts_name   = "health-risk-alerts"
  risk_alerts_region = local.partition == "aws-us-gov" ? "us-gov-west-1" : "us-east-1"

  # Only the names: the URLs are secrets, and for_each keys show up in plans.
  risk_alerts_webhooks = toset(try(nonsensitive(keys(var.risk_alerts.webhook_urls)), []))
}

resource "aws_cloudwatch_event_rule" "risk_alerts" {
  count = var.risk_alerts == null ? 0 : 1

  region      = local.risk_alerts_region
  name        = local.risk_alerts_name
  description = "AWS Health RISK events (e.g. exposed access keys) to the incident channel"
  event_pattern = jsonencode({
    source        = ["aws.health"]
    "detail-type" = ["AWS Health Event"]
    detail = {
      service = ["RISK"]
    }
  })
  tags = var.tags

  lifecycle {
    precondition {
      condition     = local.partition != "aws-us-gov" || length(local.risk_alerts_webhooks) == 0
      error_message = "risk_alerts.webhook_urls isn't supported in GovCloud, which has no EventBridge API destinations. Leave it empty and subscribe a forwarder (for example terraform-aws-modules/notify-slack) to the risk_alerts_topic_arn output; see the README."
    }
  }
}

# No server-side encryption: EventBridge can't publish through the AWS managed
# SNS key, and these messages carry event metadata, not secrets.
module "risk_alerts_topic" {
  count   = var.risk_alerts == null ? 0 : 1
  source  = "terraform-aws-modules/sns/aws"
  version = "7.1.0"

  region = local.risk_alerts_region
  name   = local.risk_alerts_name
  tags   = var.tags

  topic_policy_statements = {
    events = {
      sid     = "AllowHealthRiskRule"
      actions = ["sns:Publish"]
      principals = [{
        type        = "Service"
        identifiers = ["events.amazonaws.com"]
      }]
      condition = [{
        test     = "ArnEquals"
        variable = "aws:SourceArn"
        values   = [aws_cloudwatch_event_rule.risk_alerts[0].arn]
      }]
    }
  }

  subscriptions = {
    for email in var.risk_alerts.email_endpoints : email => {
      protocol = "email"
      endpoint = email
    }
  }
}

resource "aws_cloudwatch_event_target" "risk_alerts_topic" {
  count = var.risk_alerts == null ? 0 : 1

  region = local.risk_alerts_region
  rule   = aws_cloudwatch_event_rule.risk_alerts[0].name
  arn    = module.risk_alerts_topic[0].topic_arn
}

# Chat webhooks. Slack and Google Chat both accept {"text": "..."}, so one
# API destination per webhook covers either.
#
# An API destination needs a connection, and a connection needs some auth. The
# webhook URL is the real credential, so this header is only a placeholder.
resource "aws_cloudwatch_event_connection" "risk_alerts_webhook" {
  count = length(local.risk_alerts_webhooks) == 0 ? 0 : 1

  region             = local.risk_alerts_region
  name               = local.risk_alerts_name
  authorization_type = "API_KEY"

  auth_parameters {
    api_key {
      key   = "X-Source"
      value = local.risk_alerts_name
    }
  }
}

resource "aws_cloudwatch_event_api_destination" "risk_alerts_webhook" {
  for_each = local.risk_alerts_webhooks

  region              = local.risk_alerts_region
  name                = "${local.risk_alerts_name}-${each.key}"
  connection_arn      = aws_cloudwatch_event_connection.risk_alerts_webhook[0].arn
  invocation_endpoint = var.risk_alerts.webhook_urls[each.key]
  http_method         = "POST"
}

resource "aws_iam_role" "risk_alerts_webhook" {
  count = length(local.risk_alerts_webhooks) == 0 ? 0 : 1

  name = local.risk_alerts_name
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "events.amazonaws.com" }
      Condition = { ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.risk_alerts[0].arn } }
    }]
  })
}

resource "aws_iam_role_policy" "risk_alerts_webhook" {
  count = length(local.risk_alerts_webhooks) == 0 ? 0 : 1

  name = "invoke-webhooks"
  role = aws_iam_role.risk_alerts_webhook[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "events:InvokeApiDestination"
      Resource = [for name in local.risk_alerts_webhooks : aws_cloudwatch_event_api_destination.risk_alerts_webhook[name].arn]
    }]
  })
}

resource "aws_cloudwatch_event_target" "risk_alerts_webhook" {
  for_each = local.risk_alerts_webhooks

  region    = local.risk_alerts_region
  rule      = aws_cloudwatch_event_rule.risk_alerts[0].name
  target_id = "webhook-${each.key}"
  arn       = aws_cloudwatch_event_api_destination.risk_alerts_webhook[each.key].arn
  role_arn  = aws_iam_role.risk_alerts_webhook[0].arn

  input_transformer {
    input_paths = {
      type    = "$.detail.eventTypeCode"
      account = "$.detail.affectedAccount"
      region  = "$.detail.eventRegion"
    }
    # Written by hand: jsonencode would escape the <placeholders>.
    input_template = "{\"text\": \"AWS Health risk alert: <type> in account <account> (<region>). Open AWS Health in that account for details.\"}"
  }
}
