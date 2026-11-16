output "topic_arn" {
  value       = aws_sns_topic.this.arn
  description = "ARN of the incident topic; pass it as risk_alerts.sns_topic_arn in each publisher account."
}
