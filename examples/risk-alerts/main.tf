# Organization-wide risk alerts, received in a security account that is the
# AWS Health delegated administrator.
#
# Before applying, turn on AWS Health organizational view in the management
# account (AWS Health console > Your organization health > Configurations).
#
# Without a delegated administrator: delete the resource below and pass
# aws.management to the module instead of aws.secops.

provider "aws" {
  alias   = "management"
  region  = "us-west-2"
  profile = "management-admin"
}

provider "aws" {
  alias   = "secops"
  region  = "us-west-2"
  profile = "secops-admin"
}

# Registered from the management account. Organizational view has to be on
# first.
resource "aws_organizations_delegated_administrator" "health" {
  provider = aws.management

  account_id        = var.secops_account_id
  service_principal = "health.amazonaws.com"
}

module "secops" {
  source = "../.."
  providers = {
    aws = aws.secops
  }

  risk_alerts = {
    email_endpoints = ["incidents@example.com"]
    webhook_urls = {
      secops-chat = var.chat_webhook_url
    }
  }
}
