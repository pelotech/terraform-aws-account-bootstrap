variable "secops_account_id" {
  type        = string
  description = "Account that receives the organization's AWS Health events."
}

variable "chat_webhook_url" {
  type        = string
  sensitive   = true
  description = "Incoming webhook URL of the Slack channel or Google Chat space to alert."
}
