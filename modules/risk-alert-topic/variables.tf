variable "name" {
  type        = string
  default     = "health-risk-alerts"
  description = "Topic name."
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "Topic region: us-east-1, or us-gov-west-1 in GovCloud, where AWS Health sends exposed-key and other RISK events."

  validation {
    condition     = contains(["us-east-1", "us-gov-west-1"], var.region)
    error_message = "region must be us-east-1 or us-gov-west-1."
  }
}

variable "publisher_account_ids" {
  type        = list(string)
  description = "Accounts whose risk-alert role may publish, i.e. every account that sets risk_alerts to this topic."

  validation {
    condition     = length(var.publisher_account_ids) > 0 && alltrue([for id in var.publisher_account_ids : can(regex("^[0-9]{12}$", id))])
    error_message = "publisher_account_ids must list at least one 12-digit AWS account ID."
  }
}

variable "publisher_role_name" {
  type        = string
  default     = "health-risk-alerts"
  description = "Name of the risk-alert role in each publisher account; matches risk_alerts.name in the root module."
}

variable "email_endpoints" {
  type        = list(string)
  default     = []
  description = "Email addresses to notify, for example a Slack channel's email address. Each one must confirm the subscription from the email AWS sends."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to the resources this module creates."
}
