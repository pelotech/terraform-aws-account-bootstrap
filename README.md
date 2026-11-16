# terraform-aws-account-bootstrap

What one AWS account needs before CI can manage it, plus an optional alert when AWS reports a risk such as an exposed access key. Written for Terraform; it also works with OpenTofu.

Every part is optional. Set an input to turn that part on; leave it `null` to skip it.

| Input | Creates |
| ----- | ------- |
| `github` | A GitHub Actions OIDC provider, plus an **apply** role (`AdministratorAccess`) and a **plan** role (`ReadOnlyAccess`). Built with [`pelotech/oidc-github`](https://registry.terraform.io/modules/pelotech/oidc-github/aws). |
| `state_bucket` | An S3 bucket for Terraform state: versioned, AES256-encrypted, TLS-only, with public access blocked. |
| `management_account` | `OrganizationAccountAccessRole` and/or `AWSControlTowerExecution`. Both are `AdministratorAccess` and trust only the organization management account. |
| `risk_alerts` | An EventBridge rule that sends AWS Health RISK events, such as exposed access keys, to the incident channel by email and by Slack or Google Chat webhook. Set in the organization's AWS Health delegated administrator or management account, it covers the whole organization. |

The module manages one account, declares no provider blocks and is partition-aware, so the same code works in commercial and GovCloud.

## How to run it

Apply it once per account, locally, from a **bootstrap root** that holds one provider per account. Each provider uses admin credentials for its account, for example an Identity Center admin profile.

- Every resource is created in the account of the provider you pass in.
- Pin `ref` to a [release tag](https://github.com/pelotech/terraform-aws-account-bootstrap/releases).
- For an account **invited** into the organization, `OrganizationAccountAccessRole` doesn't exist until this module creates it. Use that account's own admin credentials for the first apply.
- The bootstrap root's own state needs somewhere to live. A common choice is the state bucket this module creates in the management account.

```hcl
provider "aws" {
  alias   = "workloads"
  region  = "us-west-2"
  profile = "workloads-admin"
}

module "workloads" {
  source = "git::https://github.com/pelotech/terraform-aws-account-bootstrap.git?ref=vX.Y.Z"
  providers = {
    aws = aws.workloads
  }

  github = {
    repository     = "my-org/infrastructure"
    apply_subjects = ["environment:workloads"] # protect it with GitHub environment rules
    plan_subjects  = ["pull_request"]
  }
  state_bucket = {
    name                    = "my-org-workloads-tfstate"
    noncurrent_version_days = 90 # omit to keep every state version
  }
  management_account = {
    id                              = "111111111111"
    create_organization_access_role = true # only for invited accounts
  }
}
```

For the management account itself, leave `management_account` out.

## CI access (`github`)

**Subjects.** A subject is the OIDC `sub` claim after `repo:<repository>:`. Common values:
- `environment:prod`
- `ref:refs/heads/main`
- `pull_request`

Both subject lists are required, so plan access is as deliberate as apply access.

**Subjects with IDs.** If the organization or repository customizes the `sub` claim to include owner and repository IDs, the claim looks like `repo:my-org@226711865/infrastructure@1419144170:pull_request`. Set `repository = "my-org@226711865/infrastructure@1419144170"` to match. When a role assumption fails with `Not authorized to perform sts:AssumeRoleWithWebIdentity`, the failed `AssumeRoleWithWebIdentity` event in CloudTrail shows the exact `sub` GitHub sent as its `userName`.

- **Apply role.** It has `AdministratorAccess`, so trust it narrowly. A GitHub environment with protection rules, or `ref:refs/heads/main`, are good choices. Never use `*`, which lets any branch, tag or PR in the repo act as admin.
- **Plan role.** It is read-only for the whole account, including reading S3 objects. With `plan_subjects = ["pull_request"]`, anyone who can open a PR in the repo gets that access. PRs from forks get no OIDC token by default, so they don't.
- **`sso_admin_permission_sets`.** These Identity Center roles (e.g. `["AdministratorAccess"]`) may also assume the apply role. Some access belongs only to the role that created a resource, and this is how people reach it:
  - EKS cluster-creator admin access.
  - KMS keys whose key administrator is the apply role.

  The permission set must already be assigned to the account. If it isn't, plan shows a warning and no trust is added; assign it, then re-apply.
- **Role names and extra policies.** `apply_role_name` and `plan_role_name` default to `ci-apply` and `ci-plan`. `plan_policy_arns` adds policies to the plan role.

**Existing OIDC provider.** An account can have only one GitHub OIDC provider. If one already exists, import it before applying:

```bash
terraform import 'module.workloads.module.oidc[0].aws_iam_openid_connect_provider.github' \
  arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com
```

**Using the roles in a workflow:**

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: ${{ vars.PLAN_ROLE_ARN }} # module output plan_role_arn
      aws-region: us-west-2
  - run: terraform init && terraform plan -lock=false
```

## State bucket (`state_bucket`)

Use the bucket with the S3 backend's native lock file. It needs no DynamoDB table and requires Terraform 1.10+ or OpenTofu 1.10+.

```hcl
terraform {
  backend "s3" {
    bucket       = "my-org-workloads-tfstate"
    key          = "workloads/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
  }
}
```

**Plans don't lock.** The plan role is read-only, so it can't write the `.tflock` object. Run `terraform plan -lock=false` in PR workflows. This is safe:
- A plan only reads state.
- S3 writes are atomic, so a plan never sees half-written state.
- The apply job takes the lock itself.

If you do want plans to lock, pass a policy through `github.plan_policy_arns` that allows `s3:PutObject` and `s3:DeleteObject` on `arn:aws:s3:::<bucket>/*.tflock`.

## Management account access (`management_account`)

`management_account` must enable at least one of these roles:

- **`create_organization_access_role`** creates `OrganizationAccountAccessRole`.
  - Organizations creates this role only for accounts it creates, so set this for accounts **invited** into the organization. That includes all GovCloud members and accounts transferred from another organization.
  - Don't set it for accounts Organizations created, which already have the role. Import the existing role instead.
- **`create_controltower_execution_role`** creates `AWSControlTowerExecution`.
  - Control Tower needs this role before it can enroll an existing account. It is only one of the [enrollment prerequisites](https://docs.aws.amazon.com/controltower/latest/userguide/enroll-manually.html).
  - Accounts created by Account Factory already have it.
- **`previous_management_account_ids`** keeps trust for the old management account while you migrate an account transferred from another organization. It applies to `OrganizationAccountAccessRole` only. Set it back to `[]` at cutover.

**Protect these roles in your own root.** They are how the management account reaches the account, and the module doesn't add `prevent_destroy`. Also note: removing the module call detaches `AdministratorAccess` from these roles. If your provider assumes one of them, remove the account's other resources first, or use the account's own admin credentials.

## Exposed-key and other risk alerts (`risk_alerts`)

AWS Health raises a RISK event when it finds a problem such as an access key exposed in a public repository. Setting `risk_alerts` sends those events to the incident channel. It creates, all in the one account:

- an EventBridge rule that matches AWS Health events whose service is `RISK`;
- an SNS topic that only that rule can publish to, built with [`terraform-aws-modules/sns`](https://registry.terraform.io/modules/terraform-aws-modules/sns/aws), with an email subscription for each address in `email_endpoints`;
- for each entry in `webhook_urls`, an EventBridge API destination that posts a one-line message to that Slack or Google Chat webhook.

Both lists are optional, so each team sets only what it uses.

```hcl
module "secops" {
  source = "git::https://github.com/pelotech/terraform-aws-account-bootstrap.git?ref=vX.Y.Z"
  providers = {
    aws = aws.secops
  }

  risk_alerts = {
    email_endpoints = ["incidents@example.com"]
    webhook_urls = {
      secops-chat  = var.chat_webhook_url  # Google Chat space
      secops-slack = var.slack_webhook_url # Slack channel
    }
  }
}
```

### Where to set it

The code is the same everywhere; the account you apply it in decides what it covers. Set it in one account per organization, because setting it in more than one can send the same alert twice.

| Setup | Apply `risk_alerts` in | Covers | Manual steps |
| ----- | ---------------------- | ------ | ------------ |
| Organization, with a delegated administrator (AWS's recommendation) | The delegated administrator, for example a security account | Every account, including ones added later | 1 and 2 below |
| Organization, without a delegated administrator | The management account | Every account, including ones added later | 1 below |
| No organization, or one account only | That account | That account | None |

A delegated administrator keeps the alerting out of the management account. Skip it if the organization has no separate security or operations account.

1. **Turn on organizational view**, once, signed in to the management account. In the [AWS Health Dashboard](https://health.aws.amazon.com/health/home), go to **Your organization health** > **Configurations** and choose **Enable organizational view**. The organization must have all features enabled.
2. **Register the delegated administrator**, once, from the management account. Either run the command below, or manage it in Terraform as [`examples/risk-alerts`](examples/risk-alerts) does.

   ```bash
   aws organizations register-delegated-administrator \
     --account-id <security-account-id> --service-principal health.amazonaws.com
   ```

If a step is missed, the module still applies cleanly and alerts for its own account only. To check, open **Your organization health** in the Health Dashboard of the account you applied to; it should list other accounts' events. AWS's guide is [Aggregating AWS Health events](https://docs.aws.amazon.com/health/latest/ug/aggregate-events.html).

### Details

- **Region.** Everything is created in `us-east-1` (`us-gov-west-1` in GovCloud), whatever region the provider uses. That is where AWS Health sends events that aren't tied to a region, such as exposed IAM access keys. A RISK event tied to another region is not picked up.
- **Email.** Each address has to confirm the subscription AWS emails it. The email is the raw event JSON: look at `detail.eventTypeCode`, `detail.affectedAccount` and `detail.affectedEntities`. For other destinations, subscribe to the `risk_alerts_topic_arn` output.
- **Webhooks.** Create an incoming webhook in the [Slack channel](https://api.slack.com/messaging/webhooks) or [Google Chat space](https://developers.google.com/workspace/chat/quickstart/webhooks) and pass its URL. Anything else that accepts `{"text": "..."}` works too. The message reads: `AWS Health risk alert: AWS_RISK_CREDENTIALS_EXPOSED in account 111111111111 (us-east-1). Open AWS Health in that account for details.`
- **GovCloud has no webhooks.** GovCloud doesn't offer EventBridge API destinations, so `webhook_urls` fails the plan there. Leave it empty and subscribe a forwarder to the topic in your own root, for example [`terraform-aws-modules/notify-slack`](https://registry.terraform.io/modules/terraform-aws-modules/notify-slack/aws):

  ```hcl
  module "risk_alerts_slack" {
    source  = "terraform-aws-modules/notify-slack/aws"
    version = "x.y.z"

    create_sns_topic     = false
    sns_topic_name       = element(split(":", module.billing.risk_alerts_topic_arn), 5)
    lambda_function_name = "health-risk-alerts-slack"
    slack_webhook_url    = var.slack_webhook_url
    slack_channel        = "incidents"
    slack_username       = "AWS Health"
  }
  ```

- **Webhook URLs are secrets.** Anyone who has one can post to the channel. Pass them from sensitive variables. They are stored in Terraform state and are visible to anyone who can read EventBridge API destinations in the account.
- **Encryption.** The topic isn't encrypted at rest. EventBridge can't publish through the AWS managed SNS key, and the messages carry event metadata, not secrets.
- **Testing.** A real RISK event can't be triggered on demand, so test the two ends: publish a message to the topic, and `curl` a `{"text": "test"}` body to each webhook URL.

## Tests

The tests run offline with a mocked provider. The nix dev shell runs Terraform through tenv, which installs the `required_version` floor (`.terraform-version` is `min-required`).

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
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.44 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.44 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_oidc"></a> [oidc](#module\_oidc) | pelotech/oidc-github/aws | 1.2.1 |
| <a name="module_risk_alerts_topic"></a> [risk\_alerts\_topic](#module\_risk\_alerts\_topic) | terraform-aws-modules/sns/aws | 7.1.0 |
| <a name="module_state_bucket"></a> [state\_bucket](#module\_state\_bucket) | terraform-aws-modules/s3-bucket/aws | 5.17.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_event_api_destination.risk_alerts_webhook](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_api_destination) | resource |
| [aws_cloudwatch_event_connection.risk_alerts_webhook](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_connection) | resource |
| [aws_cloudwatch_event_rule.risk_alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.risk_alerts_topic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.risk_alerts_webhook](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_iam_role.management](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.risk_alerts_webhook](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.risk_alerts_webhook](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.management](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_roles.sso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_roles) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_github"></a> [github](#input\_github) | GitHub Actions access to this account: an OIDC provider plus an apply role (AdministratorAccess) and a plan role (ReadOnlyAccess). Null creates none of them.<br/>  - repository: owner/name, as it appears in the OIDC sub claim. If the organization or repository customizes the sub claim to include IDs, use owner@owner\_id/name@repo\_id.<br/>  - apply\_subjects / plan\_subjects: OIDC subject claims each role trusts, without the repo:<repository>: prefix, e.g. ["environment:prod"], ["ref:refs/heads/main"], ["pull\_request"].<br/>  - apply\_role\_name / plan\_role\_name: role names (default ci-apply / ci-plan).<br/>  - plan\_policy\_arns: extra policy ARNs for the plan role.<br/>  - sso\_admin\_permission\_sets: Identity Center permission sets (e.g. ["AdministratorAccess"]) whose roles in this account may assume the apply role, to reach what only the apply role can (EKS cluster-creator admin, KMS keys it administers). | <pre>object({<br/>    repository                = string<br/>    apply_subjects            = list(string)<br/>    plan_subjects             = list(string)<br/>    apply_role_name           = optional(string, "ci-apply")<br/>    plan_role_name            = optional(string, "ci-plan")<br/>    plan_policy_arns          = optional(list(string), [])<br/>    sso_admin_permission_sets = optional(list(string), [])<br/>  })</pre> | `null` | no |
| <a name="input_management_account"></a> [management\_account](#input\_management\_account) | Roles the organization management account uses to reach this account, each AdministratorAccess and trusting only the management account. Null (e.g. in the management account itself) creates none.<br/>  - id: management account ID.<br/>  - create\_organization\_access\_role: OrganizationAccountAccessRole. Organizations creates it only for accounts it creates, so set this for accounts invited into the organization.<br/>  - create\_controltower\_execution\_role: AWSControlTowerExecution, which Control Tower needs to enroll an existing account.<br/>  - previous\_management\_account\_ids: also trusted by OrganizationAccountAccessRole while migrating an account transferred from another organization; set back to [] at cutover. | <pre>object({<br/>    id                                 = string<br/>    create_organization_access_role    = optional(bool, false)<br/>    create_controltower_execution_role = optional(bool, false)<br/>    previous_management_account_ids    = optional(list(string), [])<br/>  })</pre> | `null` | no |
| <a name="input_risk_alerts"></a> [risk\_alerts](#input\_risk\_alerts) | Send AWS Health RISK events (for example exposed access keys) to the incident channel. Null creates nothing. Set it in the organization's AWS Health delegated administrator or management account to cover every account in the organization; anywhere else it covers this account only.<br/>  - email\_endpoints: addresses to notify. Each must confirm the subscription AWS emails it.<br/>  - webhook\_urls: name => incoming webhook URL of a Slack channel or Google Chat space. The URLs are secrets and are stored in state; pass them from sensitive variables. Not supported in GovCloud (no EventBridge API destinations); subscribe a forwarder to risk\_alerts\_topic\_arn there instead. | <pre>object({<br/>    email_endpoints = optional(list(string), [])<br/>    webhook_urls    = optional(map(string), {})<br/>  })</pre> | `null` | no |
| <a name="input_state_bucket"></a> [state\_bucket](#input\_state\_bucket) | S3 bucket for this account's Terraform state. Null creates no bucket.<br/>  - name: bucket name.<br/>  - noncurrent\_version\_days: expire old state versions after this many days. Null keeps every version. | <pre>object({<br/>    name                    = string<br/>    noncurrent_version_days = optional(number)<br/>  })</pre> | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the resources this module creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_apply_role_arn"></a> [apply\_role\_arn](#output\_apply\_role\_arn) | ARN of the CI apply role (role-to-assume for apply workflows), or null when github is null. |
| <a name="output_controltower_execution_role_arn"></a> [controltower\_execution\_role\_arn](#output\_controltower\_execution\_role\_arn) | ARN of AWSControlTowerExecution, or null when it was not created. |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of the GitHub Actions OIDC provider in this account, or null when github is null. |
| <a name="output_organization_access_role_arn"></a> [organization\_access\_role\_arn](#output\_organization\_access\_role\_arn) | ARN of OrganizationAccountAccessRole, or null when it was not created. |
| <a name="output_plan_role_arn"></a> [plan\_role\_arn](#output\_plan\_role\_arn) | ARN of the CI plan role (role-to-assume for plan workflows), or null when github is null. |
| <a name="output_risk_alerts_topic_arn"></a> [risk\_alerts\_topic\_arn](#output\_risk\_alerts\_topic\_arn) | ARN of the SNS topic that receives AWS Health RISK events, or null when risk\_alerts is null. Subscribe other destinations to it in your own root. |
| <a name="output_state_bucket_name"></a> [state\_bucket\_name](#output\_state\_bucket\_name) | Name of the Terraform state bucket, or null when state\_bucket is null. |
<!-- END_TF_DOCS -->
