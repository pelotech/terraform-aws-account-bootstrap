output "apply_role_arn" {
  value       = module.workloads.apply_role_arn
  description = "role-to-assume for apply workflows."
}

output "plan_role_arn" {
  value       = module.workloads.plan_role_arn
  description = "role-to-assume for plan workflows."
}
