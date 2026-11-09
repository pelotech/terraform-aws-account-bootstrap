# A bootstrap root holds one provider per account, using admin credentials
# (e.g. an Identity Center admin profile) for that account.
provider "aws" {
  alias   = "workloads"
  region  = "us-west-2"
  profile = "workloads-admin"
}

# A member account invited into the organization.
module "workloads" {
  source = "../.."
  providers = {
    aws = aws.workloads
  }

  github = {
    repository                = "my-org/infrastructure"
    apply_subjects            = ["environment:workloads"]
    plan_subjects             = ["pull_request"]
    sso_admin_permission_sets = ["AdministratorAccess"]
  }
  state_bucket = {
    name                    = "my-org-workloads-tfstate"
    noncurrent_version_days = 90
  }
  management_account = {
    id                              = "111111111111"
    create_organization_access_role = true
  }
}
