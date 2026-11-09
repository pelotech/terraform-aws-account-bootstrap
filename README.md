# terraform-aws-account-bootstrap

What one AWS account needs before CI can manage it. Apply it once per account, locally with admin credentials, from a bootstrap root that holds a provider per account. Every part is optional:

- **CI access** (`github`): a GitHub Actions OIDC provider and two roles, via [`pelotech/oidc-github`](https://registry.terraform.io/modules/pelotech/oidc-github/aws):
  - apply role (`apply_role_name`, default `ci-apply`): `AdministratorAccess`, trusted for `github.apply_subjects`. `sso_admin_permission_sets` lets those Identity Center roles assume it too, to debug with CI's exact permissions.
  - plan role (`plan_role_name`, default `ci-plan`): `ReadOnlyAccess` plus `plan_policy_arns`, trusted for `github.plan_subjects`.
  - anything in `additional_roles`.

  Subjects are the OIDC `sub` claim after `repo:<repository>:`, e.g. `ref:refs/heads/main`, `pull_request`, `environment:prod` or `*`. Both lists are required, so plan access is as deliberate as apply access.
- **State bucket** (`state_bucket_name`): versioned, AES256, TLS-only, public access blocked; use it with the S3 backend's `use_lockfile = true` (no DynamoDB table). `state_noncurrent_version_days` expires old state versions; by default every version is kept.
- **Management account access** (`management_account_id` plus a flag per role):
  - `create_organization_access_role`: `OrganizationAccountAccessRole` (`AdministratorAccess`, trusting the management account). Organizations creates it only for accounts it creates, so set this for accounts **invited** into the organization (including all GovCloud members and accounts transferred from another organization). It has `prevent_destroy`. To decommission such an account, remove its other resources first (or use that account's own SSO admin profile): deleting the whole module call also detaches `AdministratorAccess` from the role the provider is using.
  - `organization_access_extra_trusted_account_ids`: while migrating an account transferred from another organization, also trust the old management account; set it back to `[]` at cutover.
  - `create_controltower_execution_role`: `AWSControlTowerExecution`, which Control Tower needs to enroll an existing account.

Partition-aware: the same module works in commercial and GovCloud. It manages one account and declares no provider blocks; pass the target account's provider.

## Usage

```hcl
module "workloads" {
  source = "git::https://github.com/pelotech/terraform-aws-account-bootstrap.git?ref=v0.1.0"
  providers = {
    aws = aws.workloads
  }

  github = {
    repository     = "my-org/infrastructure"
    apply_subjects = ["ref:refs/heads/main"]
    plan_subjects  = ["pull_request"]
  }
  state_bucket_name               = "my-org-workloads-tfstate"
  state_noncurrent_version_days   = 90
  management_account_id           = "111111111111"
  create_organization_access_role = true # only for invited accounts
}
```

For the management account itself, leave `management_account_id` null.

## Tests

Offline, with a mocked provider (the nix dev shell pins Terraform to the `required_version` floor):

```bash
terraform init -backend=false
terraform test
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
| <a name="module_oidc"></a> [oidc](#module\_oidc) | pelotech/oidc-github/aws | 1.2.1 |
| <a name="module_state_bucket"></a> [state\_bucket](#module\_state\_bucket) | terraform-aws-modules/s3-bucket/aws | 5.17.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_role.controltower_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.organization_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.controltower_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.organization_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.controltower_execution_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.organization_access_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_roles.sso_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_roles) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_additional_roles"></a> [additional\_roles](#input\_additional\_roles) | Extra GitHub OIDC roles to create next to the apply and plan roles, keyed by role name. Same shape as pelotech/oidc-github's roles input. | <pre>map(object({<br/>    subject_repos        = list(string)<br/>    policy_arns          = list(string)<br/>    role_path            = optional(string, "/")<br/>    assume_role_names    = optional(list(string))<br/>    max_session_duration = optional(number)<br/>    inline_policies      = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_apply_role_name"></a> [apply\_role\_name](#input\_apply\_role\_name) | Name of the admin role CI assumes to apply, trusted for github.apply\_subjects. | `string` | `"ci-apply"` | no |
| <a name="input_create_controltower_execution_role"></a> [create\_controltower\_execution\_role](#input\_create\_controltower\_execution\_role) | Create AWSControlTowerExecution (AdministratorAccess, trusting management\_account\_id), which Control Tower needs to enroll an existing account. Requires management\_account\_id. | `bool` | `false` | no |
| <a name="input_create_organization_access_role"></a> [create\_organization\_access\_role](#input\_create\_organization\_access\_role) | Create OrganizationAccountAccessRole, trusting management\_account\_id. Needed for accounts invited into the organization (Organizations only creates it for accounts it creates). Requires management\_account\_id. | `bool` | `false` | no |
| <a name="input_github"></a> [github](#input\_github) | GitHub Actions access to this account: an OIDC provider plus the apply and plan roles. repository: owner/name. apply\_subjects / plan\_subjects: the OIDC subject claims each role trusts, without the repo:<repository>: prefix, e.g. ["ref:refs/heads/main"], ["pull\_request"], ["environment:prod"] or ["*"]. Null creates no OIDC provider or CI roles. | <pre>object({<br/>    repository     = string<br/>    apply_subjects = list(string)<br/>    plan_subjects  = list(string)<br/>  })</pre> | `null` | no |
| <a name="input_management_account_id"></a> [management\_account\_id](#input\_management\_account\_id) | Organization management account ID, trusted by the roles enabled with create\_controltower\_execution\_role and create\_organization\_access\_role. Leave null for the management account itself. | `string` | `null` | no |
| <a name="input_organization_access_extra_trusted_account_ids"></a> [organization\_access\_extra\_trusted\_account\_ids](#input\_organization\_access\_extra\_trusted\_account\_ids) | Extra account IDs (e.g. the previous organization's management account) that OrganizationAccountAccessRole also trusts. Transitional: use only while migrating an account transferred from another organization, then set back to []. | `list(string)` | `[]` | no |
| <a name="input_plan_policy_arns"></a> [plan\_policy\_arns](#input\_plan\_policy\_arns) | Extra policy ARNs for the plan role, on top of ReadOnlyAccess. | `list(string)` | `[]` | no |
| <a name="input_plan_role_name"></a> [plan\_role\_name](#input\_plan\_role\_name) | Name of the read-only role CI assumes to plan, trusted for github.plan\_subjects. | `string` | `"ci-plan"` | no |
| <a name="input_sso_admin_permission_sets"></a> [sso\_admin\_permission\_sets](#input\_sso\_admin\_permission\_sets) | IAM Identity Center permission sets (e.g. ["AdministratorAccess"]) whose roles in this account may also assume the apply role, to debug with CI's exact permissions. | `list(string)` | `[]` | no |
| <a name="input_state_bucket_name"></a> [state\_bucket\_name](#input\_state\_bucket\_name) | Name of the S3 bucket for this account's OpenTofu state. Null skips the bucket. | `string` | `null` | no |
| <a name="input_state_noncurrent_version_days"></a> [state\_noncurrent\_version\_days](#input\_state\_noncurrent\_version\_days) | Expire noncurrent (old) state object versions after this many days. Null keeps every version. | `number` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the resources this module creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_controltower_execution_role_arn"></a> [controltower\_execution\_role\_arn](#output\_controltower\_execution\_role\_arn) | ARN of the AWSControlTowerExecution role, or null when none was created. |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of the GitHub Actions OIDC provider in this account, or null when github is null. |
| <a name="output_organization_access_role_arn"></a> [organization\_access\_role\_arn](#output\_organization\_access\_role\_arn) | ARN of the OrganizationAccountAccessRole, or null when none was created. |
| <a name="output_role_arns"></a> [role\_arns](#output\_role\_arns) | Map of CI role name to ARN (apply, plan and additional roles); empty when github is null. |
| <a name="output_state_bucket_name"></a> [state\_bucket\_name](#output\_state\_bucket\_name) | Name of the tfstate bucket, or null when none was created. |
<!-- END_TF_DOCS -->
