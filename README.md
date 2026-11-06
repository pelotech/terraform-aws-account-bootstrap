# account-baseline

Baseline for a single AWS account managed from a GitHub infrastructure repo:

- **GitHub OIDC provider** with two CI roles, via [`pelotech/oidc-github`](https://registry.terraform.io/modules/pelotech/oidc-github/aws):
  - `gh-apply`: `AdministratorAccess`, trusted only from the repo's main branch (applies).
  - `gh-plan`: `ReadOnlyAccess` (+ `plan_policy_arns`), trusted from any ref (plans).

  Both names are configurable (`apply_role_name`, `plan_role_name`), e.g. to adopt existing roles.
  - Anything in `additional_roles`.
- **tfstate S3 bucket** (optional): versioned, AES256, TLS-only, public access blocked. Use it with the S3 backend's `use_lockfile = true`; no DynamoDB table needed.
- **`AWSControlTowerExecution` role** (optional): `AdministratorAccess`, trusting only the organization management account, so Control Tower can enroll the account.

Partition-aware: the same module works in commercial and GovCloud.

The module manages one account. Pass the target account's provider; it declares no provider blocks.

## Usage

```hcl
module "workloads" {
  source = "../../modules/account-baseline"
  providers = {
    aws = aws.workloads
  }

  github_repository     = "my-org/infrastructure"
  state_bucket_name     = "my-org-workloads-tfstate"
  management_account_id = "111111111111"
}
```

For the management account itself, leave `management_account_id` null.

## Tests

Offline, with a mocked provider:

```bash
tofu -chdir=aws/modules/account-baseline init
tofu -chdir=aws/modules/account-baseline test
```

---

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_oidc"></a> [oidc](#module\_oidc) | pelotech/oidc-github/aws | 1.2.0 |
| <a name="module_state_bucket"></a> [state\_bucket](#module\_state\_bucket) | terraform-aws-modules/s3-bucket/aws | 5.15.4 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_role.controltower_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.controltower_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.controltower_execution_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_roles.sso_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_roles) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_additional_roles"></a> [additional\_roles](#input\_additional\_roles) | Extra GitHub OIDC roles to create next to the apply and plan roles, keyed by role name. Same shape as pelotech/oidc-github's roles input. | <pre>map(object({<br/>    subject_repos        = list(string)<br/>    policy_arns          = list(string)<br/>    role_path            = optional(string, "/")<br/>    assume_role_names    = optional(list(string))<br/>    max_session_duration = optional(number)<br/>    inline_policies      = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_apply_role_name"></a> [apply\_role\_name](#input\_apply\_role\_name) | Name of the admin role CI assumes to apply, from main\_branch only. | `string` | `"gh-apply"` | no |
| <a name="input_github_repository"></a> [github\_repository](#input\_github\_repository) | GitHub repository (owner/name) that manages this account's infrastructure. main\_branch can assume the apply role, every ref the plan role. | `string` | n/a | yes |
| <a name="input_main_branch"></a> [main\_branch](#input\_main\_branch) | Branch of github\_repository allowed to assume the apply role. | `string` | `"main"` | no |
| <a name="input_management_account_id"></a> [management\_account\_id](#input\_management\_account\_id) | Organization management account ID trusted by the AWSControlTowerExecution role. Null skips the role (use null for the management account itself). | `string` | `null` | no |
| <a name="input_plan_policy_arns"></a> [plan\_policy\_arns](#input\_plan\_policy\_arns) | Extra policy ARNs for the plan role, on top of ReadOnlyAccess. | `list(string)` | `[]` | no |
| <a name="input_plan_role_name"></a> [plan\_role\_name](#input\_plan\_role\_name) | Name of the read-only role CI assumes to plan, from any ref. | `string` | `"gh-plan"` | no |
| <a name="input_sso_admin_permission_sets"></a> [sso\_admin\_permission\_sets](#input\_sso\_admin\_permission\_sets) | IAM Identity Center permission sets (e.g. ["AdministratorAccess"]) whose roles in this account may also assume the apply role, to debug with CI's exact permissions. | `list(string)` | `[]` | no |
| <a name="input_state_bucket_name"></a> [state\_bucket\_name](#input\_state\_bucket\_name) | Name of the S3 bucket for this account's OpenTofu state. Null skips the bucket. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the resources this module creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_controltower_execution_role_arn"></a> [controltower\_execution\_role\_arn](#output\_controltower\_execution\_role\_arn) | ARN of the AWSControlTowerExecution role, or null when none was created. |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of the GitHub Actions OIDC provider in this account. |
| <a name="output_role_arns"></a> [role\_arns](#output\_role\_arns) | Map of GitHub OIDC role name to ARN (main, plan and additional roles). |
| <a name="output_state_bucket_name"></a> [state\_bucket\_name](#output\_state\_bucket\_name) | Name of the tfstate bucket, or null when none was created. |
<!-- END_TF_DOCS -->
