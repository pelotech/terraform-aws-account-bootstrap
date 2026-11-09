# Offline tests: mocked AWS provider, no credentials needed.
#   terraform init -backend=false && terraform test

mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws-us-gov"
    }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}"
    }
  }
  mock_data "aws_iam_roles" {
    defaults = {
      arns = ["arn:aws-us-gov:iam::222222222222:role/aws-reserved/sso.amazonaws.com/us-gov-west-1/AWSReservedSSO_AdministratorAccess_abc123"]
    }
  }
}

variables {
  github = {
    repository     = "my-org/infrastructure"
    apply_subjects = ["ref:refs/heads/main"]
    plan_subjects  = ["pull_request"]
  }
}

################################################################################
# CI access (GitHub OIDC)
################################################################################

run "ci_roles_from_subjects" {
  command = plan

  variables {
    plan_policy_arns = ["arn:aws-us-gov:iam::222222222222:policy/extra"]
  }

  assert {
    condition     = jsonencode(local.base_roles["ci-apply"].subject_repos) == jsonencode(["repo:my-org/infrastructure:ref:refs/heads/main"])
    error_message = "apply role should trust exactly github.apply_subjects (default name ci-apply)"
  }

  assert {
    condition     = jsonencode(local.base_roles["ci-plan"].subject_repos) == jsonencode(["repo:my-org/infrastructure:pull_request"])
    error_message = "plan role should trust exactly github.plan_subjects (default name ci-plan)"
  }

  assert {
    condition     = length(local.base_roles["ci-apply"].assume_role_names) == 0
    error_message = "no extra principals on the apply role unless asked for"
  }

  assert {
    condition     = jsonencode(local.base_roles["ci-plan"].policy_arns) == jsonencode(["arn:aws-us-gov:iam::aws:policy/ReadOnlyAccess", "arn:aws-us-gov:iam::222222222222:policy/extra"])
    error_message = "plan role should get ReadOnlyAccess plus plan_policy_arns"
  }
}

run "custom_role_names" {
  command = plan

  variables {
    apply_role_name = "gh-main"
    plan_role_name  = "gh-pr-plan"
  }

  assert {
    condition     = toset(keys(local.base_roles)) == toset(["gh-main", "gh-pr-plan"])
    error_message = "apply_role_name and plan_role_name should name the CI roles"
  }
}

run "no_ci_access" {
  command = plan

  variables {
    github = null
  }

  assert {
    condition     = length(module.oidc) == 0
    error_message = "no OIDC provider or CI roles when github is null"
  }

  assert {
    condition     = length(output.role_arns) == 0 && output.oidc_provider_arn == null
    error_message = "CI outputs should be empty when github is null"
  }
}

run "additional_roles" {
  command = plan

  variables {
    additional_roles = {
      packer = {
        subject_repos = ["repo:my-org/images:ref:refs/heads/main"]
        policy_arns   = ["arn:aws-us-gov:iam::222222222222:policy/packer"]
      }
    }
  }

  assert {
    condition     = length(module.oidc[0].iam_role_names) == 3
    error_message = "additional_roles should be created next to the apply and plan roles"
  }
}

run "sso_admins_can_assume_apply" {
  command = plan

  variables {
    sso_admin_permission_sets = ["AdministratorAccess"]
  }

  assert {
    condition     = jsonencode(local.base_roles["ci-apply"].assume_role_names) == jsonencode(["aws-reserved/sso.amazonaws.com/us-gov-west-1/AWSReservedSSO_AdministratorAccess_abc123"])
    error_message = "SSO admin roles should be trusted by path/name"
  }
}

run "github_subjects_required" {
  command = plan

  variables {
    github = {
      repository     = "my-org/infrastructure"
      apply_subjects = ["ref:refs/heads/main"]
      plan_subjects  = []
    }
  }

  expect_failures = [var.github]
}

################################################################################
# State bucket
################################################################################

run "state_bucket" {
  command = plan

  variables {
    state_bucket_name = "my-org-sor-tfstate"
  }

  assert {
    condition     = length(module.state_bucket) == 1
    error_message = "state bucket should be created when state_bucket_name is set"
  }

  assert {
    condition     = length(local.state_lifecycle_rules) == 0
    error_message = "noncurrent state versions are kept unless state_noncurrent_version_days is set"
  }
}

run "state_noncurrent_versions_expire" {
  command = plan

  variables {
    state_bucket_name             = "my-org-sor-tfstate"
    state_noncurrent_version_days = 90
  }

  assert {
    condition     = local.state_lifecycle_rules[0].noncurrent_version_expiration.days == 90
    error_message = "state_noncurrent_version_days should expire noncurrent state versions"
  }
}

run "no_state_bucket" {
  command = plan

  assert {
    condition     = length(module.state_bucket) == 0
    error_message = "no state bucket when state_bucket_name is null"
  }
}

################################################################################
# Management account access roles
################################################################################

run "management_roles_off_by_default" {
  command = plan

  variables {
    management_account_id = "111111111111"
  }

  assert {
    condition     = length(aws_iam_role.controltower_execution) == 0 && length(aws_iam_role.organization_access) == 0
    error_message = "management_account_id alone should create no roles"
  }
}

run "controltower_execution_role" {
  command = plan

  variables {
    management_account_id              = "111111111111"
    create_controltower_execution_role = true
  }

  assert {
    condition     = aws_iam_role_policy_attachment.controltower_execution[0].policy_arn == "arn:aws-us-gov:iam::aws:policy/AdministratorAccess"
    error_message = "Control Tower role should use the account's partition"
  }
}

run "controltower_needs_management_account" {
  command = plan

  variables {
    create_controltower_execution_role = true
  }

  expect_failures = [var.create_controltower_execution_role]
}

run "invited_member_account" {
  command = plan

  variables {
    management_account_id           = "111111111111"
    create_organization_access_role = true
  }

  assert {
    condition     = aws_iam_role.organization_access[0].name == "OrganizationAccountAccessRole"
    error_message = "invited accounts should get OrganizationAccountAccessRole"
  }

  assert {
    condition     = aws_iam_role_policy_attachment.organization_access[0].policy_arn == "arn:aws-us-gov:iam::aws:policy/AdministratorAccess"
    error_message = "organization access role should use the account's partition"
  }

  assert {
    condition     = jsonencode(local.organization_access_trusted_arns) == jsonencode(["arn:aws-us-gov:iam::111111111111:root"])
    error_message = "organization access role should trust only the management account by default"
  }
}

run "transferred_account_dual_trust" {
  command = plan

  variables {
    management_account_id                         = "111111111111"
    create_organization_access_role               = true
    organization_access_extra_trusted_account_ids = ["333333333333"]
  }

  assert {
    condition     = jsonencode(local.organization_access_trusted_arns) == jsonencode(["arn:aws-us-gov:iam::111111111111:root", "arn:aws-us-gov:iam::333333333333:root"])
    error_message = "during a transfer the role should trust the management account and the old one"
  }
}

run "extra_trusted_ids_must_be_account_ids" {
  command = plan

  variables {
    management_account_id                         = "111111111111"
    create_organization_access_role               = true
    organization_access_extra_trusted_account_ids = ["not-an-id"]
  }

  expect_failures = [var.organization_access_extra_trusted_account_ids]
}

run "org_access_needs_management_account" {
  command = plan

  variables {
    create_organization_access_role = true
  }

  expect_failures = [var.create_organization_access_role]
}
