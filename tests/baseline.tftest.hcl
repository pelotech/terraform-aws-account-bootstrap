# Offline tests: mocked AWS provider, no credentials needed.
#   tofu -chdir=aws/modules/account-baseline init
#   tofu -chdir=aws/modules/account-baseline test

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
  github_repository = "my-org/infrastructure"
}

run "member_account" {
  command = plan

  variables {
    state_bucket_name     = "my-org-sor-tfstate"
    management_account_id = "111111111111"
    plan_policy_arns      = ["arn:aws-us-gov:iam::222222222222:policy/extra"]
  }

  assert {
    condition     = length(module.state_bucket) == 1
    error_message = "state bucket should be created when state_bucket_name is set"
  }

  assert {
    condition     = length(aws_iam_role.controltower_execution) == 1
    error_message = "Control Tower role should be created for member accounts"
  }

  assert {
    condition     = aws_iam_role_policy_attachment.controltower_execution[0].policy_arn == "arn:aws-us-gov:iam::aws:policy/AdministratorAccess"
    error_message = "Control Tower role should use the account's partition"
  }

  assert {
    condition     = jsonencode(local.base_roles["gh-apply"].subject_repos) == jsonencode(["repo:my-org/infrastructure:ref:refs/heads/main"])
    error_message = "apply role should trust only the main branch"
  }

  assert {
    condition     = length(local.base_roles["gh-apply"].assume_role_names) == 0
    error_message = "no extra principals on the apply role unless asked for"
  }

  assert {
    condition     = jsonencode(local.base_roles["gh-plan"].policy_arns) == jsonencode(["arn:aws-us-gov:iam::aws:policy/ReadOnlyAccess", "arn:aws-us-gov:iam::222222222222:policy/extra"])
    error_message = "plan role should get ReadOnlyAccess plus plan_policy_arns"
  }
}

run "management_account_without_bucket" {
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
    condition     = length(module.state_bucket) == 0
    error_message = "no state bucket when state_bucket_name is null"
  }

  assert {
    condition     = length(aws_iam_role.controltower_execution) == 0
    error_message = "no Control Tower role when management_account_id is null"
  }

  assert {
    condition     = length(module.oidc.iam_role_names) == 3
    error_message = "additional_roles should be created next to the apply and plan roles"
  }
}

run "sso_admins_can_assume_apply" {
  command = plan

  variables {
    sso_admin_permission_sets = ["AdministratorAccess"]
  }

  assert {
    condition     = jsonencode(local.base_roles["gh-apply"].assume_role_names) == jsonencode(["aws-reserved/sso.amazonaws.com/us-gov-west-1/AWSReservedSSO_AdministratorAccess_abc123"])
    error_message = "SSO admin roles should be trusted by path/name"
  }
}
