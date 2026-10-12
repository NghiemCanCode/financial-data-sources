data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "session_logs" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
    resources = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:${var.session_log_group}:*"]
  }
  statement {
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "session_logs" {
  name   = "fds-${local.source_name}-ssm-session-logs"
  policy = data.aws_iam_policy_document.session_logs.json
}

data "aws_iam_policy_document" "pg" {
  statement {
    sid       = "SeedRead"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.seed_bucket}/${local.source_name}/*"]
  }
  statement {
    sid       = "SeedList"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.seed_bucket}"]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${local.source_name}/*"]
    }
  }
  statement {
    sid       = "BackupRW"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.backup.arn}/pgbackrest/*"]
  }
  statement {
    sid       = "BackupList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.backup.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["pgbackrest", "pgbackrest/*", "deploy", "deploy/*"]
    }
  }

  statement {
    sid       = "DeployRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.backup.arn}/deploy/*"]
  }

  statement {
    sid     = "Params"
    actions = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [
      "arn:aws:ssm:${local.region}:${local.account_id}:parameter/fds/${local.source_name}/tls/*",
      "arn:aws:ssm:${local.region}:${local.account_id}:parameter/fds/${local.source_name}/pgbackrest/*"
    ]
  }
  statement {
    sid       = "Metrics"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = [local.metric_namespace]
    }
  }
  statement {
    sid       = "AuditLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
    resources = ["${aws_cloudwatch_log_group.pgaudit.arn}:*"]
  }
}

resource "aws_iam_role" "pg" {
  name               = "fds-${local.source_name}-pg"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "pg" {
  for_each = {
    ssm          = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    session_logs = aws_iam_policy.session_logs.arn
  }
  role       = aws_iam_role.pg.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "pg" {
  name   = "fds-${local.source_name}-pg"
  role   = aws_iam_role.pg.id
  policy = data.aws_iam_policy_document.pg.json
}

resource "aws_iam_instance_profile" "pg" {
  name = "fds-${local.source_name}-pg"
  role = aws_iam_role.pg.name
}