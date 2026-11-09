output "role_arns" {
  value       = try(module.oidc[0].iam_role_arns_map, {})
  description = "Map of CI role name to ARN (apply, plan and additional roles); empty when github is null."
}

output "oidc_provider_arn" {
  value       = try(module.oidc[0].github_oidc_provider_arn, null)
  description = "ARN of the GitHub Actions OIDC provider in this account, or null when github is null."
}

output "state_bucket_name" {
  value       = try(module.state_bucket[0].s3_bucket_id, null)
  description = "Name of the tfstate bucket, or null when none was created."
}

output "controltower_execution_role_arn" {
  value       = try(aws_iam_role.controltower_execution[0].arn, null)
  description = "ARN of the AWSControlTowerExecution role, or null when none was created."
}

output "organization_access_role_arn" {
  value       = try(aws_iam_role.organization_access[0].arn, null)
  description = "ARN of the OrganizationAccountAccessRole, or null when none was created."
}
