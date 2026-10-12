locals {
  parameters = merge(
    { for r in local.db_roles : "pg/${r}" => "SecureString" },
    {
      "pgbackrest/cipher-pass" = "SecureString"
      "tls/server-key"         = "SecureString"
      "tls/server-crt"         = "String"
      "tls/ca-crt"             = "String"
      "admin/tls/ca-key"       = "SecureString"
    }
  )
}

resource "aws_ssm_parameter" "this" {
  for_each = local.parameters
  name     = "/fds/${local.source_name}/${each.key}"
  type     = each.value
  value    = "set-by-script"
  lifecycle {
    ignore_changes = [value]
  }
}