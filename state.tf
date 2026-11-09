module "state_bucket" {
  count   = var.state_bucket == null ? 0 : 1
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.17.0"

  bucket = var.state_bucket.name
  tags   = var.tags

  # Public access is blocked by the module's defaults.
  versioning = {
    enabled = true
  }
  lifecycle_rule = var.state_bucket.noncurrent_version_days == null ? [] : [{
    id                            = "expire-noncurrent-state"
    enabled                       = true
    filter                        = {} # whole bucket
    noncurrent_version_expiration = { days = var.state_bucket.noncurrent_version_days }
  }]

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }
}
