# Offline tests: mocked AWS provider, no credentials needed.
#   terraform init -backend=false && terraform test

mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws-us-gov"
    }
  }
  # The state bucket module combines policy documents; mocks need valid JSON.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}"
    }
  }
  mock_data "aws_iam_roles" {
    defaults = {
      arns = [
        "arn:aws-us-gov:iam::222222222222:role/aws-reserved/sso.amazonaws.com/us-gov-west-1/AWSReservedSSO_AdministratorAccess_abc123",
        "arn:aws-us-gov:iam::222222222222:role/aws-reserved/sso.amazonaws.com/us-gov-west-1/AWSReservedSSO_Read_Only.v2_def456",
      ]
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
    github = {
      repository       = "my-org/infrastructure"
      apply_subjects   = ["ref:refs/heads/main"]
      plan_subjects    = ["pull_request"]
      plan_policy_arns = ["arn:aws-us-gov:iam::222222222222:policy/extra"]
    }
  }

  assert {
    condition     = jsonencode(local.ci_roles["ci-apply"].subject_repos) == jsonencode(["repo:my-org/infrastructure:ref:refs/heads/main"])
    error_message = "apply role should trust exactly github.apply_subjects (default name ci-apply)"
  }

  assert {
    condition     = jsonencode(local.ci_roles["ci-plan"].subject_repos) == jsonencode(["repo:my-org/infrastructure:pull_request"])
    error_message = "plan role should trust exactly github.plan_subjects (default name ci-plan)"
  }

  assert {
    condition     = length(local.ci_roles["ci-apply"].assume_role_names) == 0 && length(data.aws_iam_roles.sso) == 0
    error_message = "no SSO lookup or extra principals on the apply role unless asked for"
  }

  assert {
    condition     = jsonencode(local.ci_roles["ci-plan"].policy_arns) == jsonencode(["arn:aws-us-gov:iam::aws:policy/ReadOnlyAccess", "arn:aws-us-gov:iam::222222222222:policy/extra"])
    error_message = "plan role should get ReadOnlyAccess plus plan_policy_arns"
  }
}

run "custom_role_names" {
  command = plan

  variables {
    github = {
      repository      = "my-org/infrastructure"
      apply_subjects  = ["ref:refs/heads/main"]
      plan_subjects   = ["pull_request"]
      apply_role_name = "gh-main"
      plan_role_name  = "gh-pr-plan"
    }
  }

  assert {
    condition     = toset(keys(local.ci_roles)) == toset(["gh-main", "gh-pr-plan"])
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
    condition     = output.apply_role_arn == null && output.plan_role_arn == null && output.oidc_provider_arn == null
    error_message = "CI outputs should be null when github is null"
  }
}

run "sso_admins_can_assume_apply" {
  command = plan

  variables {
    github = {
      repository                = "my-org/infrastructure"
      apply_subjects            = ["ref:refs/heads/main"]
      plan_subjects             = ["pull_request"]
      sso_admin_permission_sets = ["AdministratorAccess", "Read_Only.v2"]
    }
  }

  assert {
    condition = jsonencode(local.ci_roles["ci-apply"].assume_role_names) == jsonencode([
      "aws-reserved/sso.amazonaws.com/us-gov-west-1/AWSReservedSSO_AdministratorAccess_abc123",
      "aws-reserved/sso.amazonaws.com/us-gov-west-1/AWSReservedSSO_Read_Only.v2_def456",
    ])
    error_message = "SSO roles should be trusted by path/name, matched on the exact permission set name"
  }

  assert {
    condition     = length(local.ci_roles["ci-plan"].assume_role_names) == 0
    error_message = "SSO roles should only be trusted by the apply role"
  }
}

run "sso_permission_set_not_found_warns" {
  command = plan

  variables {
    github = {
      repository                = "my-org/infrastructure"
      apply_subjects            = ["ref:refs/heads/main"]
      plan_subjects             = ["pull_request"]
      sso_admin_permission_sets = ["Admin"]
    }
  }

  assert {
    condition     = length(local.ci_roles["ci-apply"].assume_role_names) == 0
    error_message = "a permission set name should match exactly, not as a prefix"
  }

  expect_failures = [check.sso_admin_permission_sets_found]
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

run "github_repository_must_be_owner_name" {
  command = plan

  variables {
    github = {
      repository     = "infrastructure"
      apply_subjects = ["ref:refs/heads/main"]
      plan_subjects  = ["pull_request"]
    }
  }

  expect_failures = [var.github]
}

run "github_repository_with_ids" {
  command = plan

  variables {
    github = {
      repository     = "my-org@226711865/infrastructure@1419144170"
      apply_subjects = ["ref:refs/heads/main"]
      plan_subjects  = ["pull_request"]
    }
  }

  assert {
    condition     = jsonencode(local.ci_roles["ci-plan"].subject_repos) == jsonencode(["repo:my-org@226711865/infrastructure@1419144170:pull_request"])
    error_message = "repository with owner and repo IDs should be used verbatim in the subject"
  }
}

run "github_repository_ids_must_be_numeric" {
  command = plan

  variables {
    github = {
      repository     = "my-org@abc/infrastructure"
      apply_subjects = ["ref:refs/heads/main"]
      plan_subjects  = ["pull_request"]
    }
  }

  expect_failures = [var.github]
}

run "github_role_names_must_differ" {
  command = plan

  variables {
    github = {
      repository      = "my-org/infrastructure"
      apply_subjects  = ["ref:refs/heads/main"]
      plan_subjects   = ["pull_request"]
      apply_role_name = "ci"
      plan_role_name  = "ci"
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
    state_bucket = {
      name = "my-org-sor-tfstate"
    }
  }

  assert {
    condition     = length(module.state_bucket) == 1
    error_message = "state bucket should be created when state_bucket is set"
  }
}

run "no_state_bucket" {
  command = plan

  assert {
    condition     = length(module.state_bucket) == 0 && output.state_bucket_name == null
    error_message = "no state bucket when state_bucket is null"
  }
}

run "state_noncurrent_version_days_positive" {
  command = plan

  variables {
    state_bucket = {
      name                    = "my-org-sor-tfstate"
      noncurrent_version_days = 0
    }
  }

  expect_failures = [var.state_bucket]
}

################################################################################
# Management account access roles
################################################################################

run "no_management_roles_by_default" {
  command = plan

  assert {
    condition     = length(aws_iam_role.management) == 0
    error_message = "no management roles when management_account is null"
  }
}

run "management_account_must_create_something" {
  command = plan

  variables {
    management_account = {
      id = "111111111111"
    }
  }

  expect_failures = [var.management_account]
}

run "management_account_id_validated" {
  command = plan

  variables {
    management_account = {
      id                              = "1111"
      create_organization_access_role = true
    }
  }

  expect_failures = [var.management_account]
}

run "controltower_execution_role" {
  command = plan

  variables {
    management_account = {
      id                                 = "111111111111"
      create_controltower_execution_role = true
    }
  }

  assert {
    condition     = keys(aws_iam_role.management) == ["AWSControlTowerExecution"]
    error_message = "only AWSControlTowerExecution should be created"
  }

  assert {
    condition     = aws_iam_role_policy_attachment.management["AWSControlTowerExecution"].policy_arn == "arn:aws-us-gov:iam::aws:policy/AdministratorAccess"
    error_message = "Control Tower role should use the account's partition"
  }

  assert {
    condition     = jsondecode(aws_iam_role.management["AWSControlTowerExecution"].assume_role_policy).Statement[0].Principal.AWS == ["arn:aws-us-gov:iam::111111111111:root"]
    error_message = "Control Tower role should trust only the management account"
  }
}

run "invited_member_account" {
  command = plan

  variables {
    management_account = {
      id                              = "111111111111"
      create_organization_access_role = true
    }
  }

  assert {
    condition     = keys(aws_iam_role.management) == ["OrganizationAccountAccessRole"]
    error_message = "invited accounts should get only OrganizationAccountAccessRole"
  }

  assert {
    condition     = jsondecode(aws_iam_role.management["OrganizationAccountAccessRole"].assume_role_policy).Statement[0].Principal.AWS == ["arn:aws-us-gov:iam::111111111111:root"]
    error_message = "organization access role should trust only the management account by default"
  }
}

run "transferred_account_dual_trust" {
  command = plan

  variables {
    management_account = {
      id                              = "111111111111"
      create_organization_access_role = true
      previous_management_account_ids = ["333333333333"]
    }
  }

  assert {
    condition     = jsondecode(aws_iam_role.management["OrganizationAccountAccessRole"].assume_role_policy).Statement[0].Principal.AWS == ["arn:aws-us-gov:iam::111111111111:root", "arn:aws-us-gov:iam::333333333333:root"]
    error_message = "during a transfer the role should trust the management account and the old one"
  }
}

run "previous_management_ids_must_be_account_ids" {
  command = plan

  variables {
    management_account = {
      id                              = "111111111111"
      create_organization_access_role = true
      previous_management_account_ids = ["not-an-id"]
    }
  }

  expect_failures = [var.management_account]
}

run "previous_management_ids_need_organization_access_role" {
  command = plan

  variables {
    management_account = {
      id                                 = "111111111111"
      create_controltower_execution_role = true
      previous_management_account_ids    = ["333333333333"]
    }
  }

  expect_failures = [var.management_account]
}
