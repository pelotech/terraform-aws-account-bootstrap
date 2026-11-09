provider "aws" {
  region = "us-west-2"
}

module "account_bootstrap" {
  source = "../.."

  github = {
    repository     = "my-org/infrastructure"
    apply_subjects = ["ref:refs/heads/main"]
    plan_subjects  = ["pull_request"]
  }
  state_bucket_name     = "my-org-workloads-tfstate"
  management_account_id = "111111111111"
}
