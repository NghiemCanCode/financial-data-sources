variable "alert_email" { type = string}

variable "budget_usd" {
    type = number
    default = 30
}

resource "aws_ebs_encryption_by_default" "this" {
    enabled = true
}

resource "aws_ec2_instance_metadata_defaults" "this" {
    http_tokens = "required"
    http_put_response_hop_limit = 1
}

resource "aws_s3_account_public_access_block" "this" {
    block_public_acls = true
    ignore_public_acls = true
    block_public_policy = true
    restrict_public_buckets = true
}

resource "aws_budgets_budget" "monthly" {
    name = "fds-monthly"
    budget_type = "COST"
    limit_amount = tostring(var.budget_usd)
    limit_unit = "USD"
    time_unit = "MONTHLY"

    dynamic "notification" {
        for_each = [80, 100]
        content {
            comparison_operator = "GREATER_THAN"
            threshold = notification.value
            threshold_type = "PERCENTAGE"
            notification_type = "ACTUAL"
            subscriber_email_addresses = [var.alert_email]
        }
    }
}

resource "aws_cloudwatch_log_group" "ssm_sessions" {
    name = "/fds/ssm-sessions"
    retention_in_days = 7
}

resource "aws_ssm_document" "session_prefs" {
    name = "SSM-SessionManagerRunShell"
    document_type = "Session"
    document_format = "JSON"
    content = jsonencode({
        schemaVersion = "1.0"
        description = "Session Manager preferences"
        sessionType = "Standard_Stream"
        inputs = {
            s3BucketName = ""
            s3KeyPrefix = ""
            s3EncryptionEnabled = true
            cloudWatchLogGroupName = aws_cloudwatch_log_group.ssm_sessions.name
            cloudWatchEncryptionEnabled = false
            cloudWatchStreamingEnabled = true
            idleSessionTimeout = "20"
            runAsEnabled = false
            runAsDefaultUser = ""
            shellProfile = {
                linux = ""
                windows = ""
            }
        }
    })
}