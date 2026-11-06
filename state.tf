module "state_bucket" {
  count   = var.state_bucket_name == null ? 0 : 1
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.15.4"

  bucket = var.state_bucket_name
  tags   = var.tags

  versioning = {
    enabled = true
  }

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true
  block_public_acls                     = true
  block_public_policy                   = true
  ignore_public_acls                    = true
  restrict_public_buckets               = true
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }
}
