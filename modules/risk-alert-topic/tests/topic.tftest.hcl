# Offline tests: mocked AWS provider, no credentials needed.
#   terraform init -backend=false && terraform test

mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}"
    }
  }
  mock_resource "aws_sns_topic" {
    defaults = {
      arn = "arn:aws:sns:us-east-1:333333333333:health-risk-alerts"
    }
  }
}

variables {
  publisher_account_ids = ["111111111111", "222222222222"]
}

run "topic_in_health_region" {
  command = plan

  variables {
    email_endpoints = ["incidents@example.com"]
  }

  assert {
    condition     = aws_sns_topic.this.region == "us-east-1" && aws_sns_topic.this.name == "health-risk-alerts"
    error_message = "topic should default to health-risk-alerts in us-east-1"
  }

  assert {
    condition     = length(aws_sns_topic_subscription.email) == 1
    error_message = "one email subscription per endpoint"
  }

  assert {
    condition = jsonencode(local.publisher_role_arns) == jsonencode([
      "arn:aws:iam::111111111111:role/health-risk-alerts",
      "arn:aws:iam::222222222222:role/health-risk-alerts",
    ])
    error_message = "only the risk-alert role in each publisher account may publish"
  }
}

run "rejects_other_regions" {
  command = plan

  variables {
    region = "us-west-2"
  }

  expect_failures = [var.region]
}

run "needs_a_publisher" {
  command = plan

  variables {
    publisher_account_ids = []
  }

  expect_failures = [var.publisher_account_ids]
}
