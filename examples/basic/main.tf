provider "aws" {
  region = "us-west-2"
}

module "account_baseline" {
  source = "../.."

  github_repository     = "my-org/infrastructure"
  state_bucket_name     = "my-org-workloads-tfstate"
  management_account_id = "111111111111"
}
