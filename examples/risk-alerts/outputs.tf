output "risk_alerts_topic_arn" {
  value       = module.secops.risk_alerts_topic_arn
  description = "Topic to subscribe other destinations to."
}
