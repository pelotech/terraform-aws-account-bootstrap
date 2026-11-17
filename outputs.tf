output "oidc_provider_arn" {
  value       = try(module.oidc[0].github_oidc_provider_arn, null)
  description = "ARN of the GitHub Actions OIDC provider in this account, or null when github is null."
}

output "apply_role_arn" {
  value       = try(module.oidc[0].iam_role_arns_map[var.github.apply_role_name], null)
  description = "ARN of the CI apply role (role-to-assume for apply workflows), or null when github is null."
}

output "plan_role_arn" {
  value       = try(module.oidc[0].iam_role_arns_map[var.github.plan_role_name], null)
  description = "ARN of the CI plan role (role-to-assume for plan workflows), or null when github is null."
}

output "state_bucket_name" {
  value       = try(module.state_bucket[0].s3_bucket_id, null)
  description = "Name of the Terraform state bucket, or null when state_bucket is null."
}

output "organization_access_role_arn" {
  value       = try(aws_iam_role.management["OrganizationAccountAccessRole"].arn, null)
  description = "ARN of OrganizationAccountAccessRole, or null when it was not created."
}

output "controltower_execution_role_arn" {
  value       = try(aws_iam_role.management["AWSControlTowerExecution"].arn, null)
  description = "ARN of AWSControlTowerExecution, or null when it was not created."
}
