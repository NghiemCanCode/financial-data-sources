data "aws_iam_policy_document" "sim" {
  statement {
    sid     = "Params"
    actions = ["ssm:GetParameter"]
    resources = [
      "arn:aws:ssm:${local.region}:${local.account_id}:parameter/fds/${local.source_name}/pg/app_simulator",
      "arn:aws:ssm:${local.region}:${local.account_id}:parameter/fds/${local.source_name}/tls/ca-crt"
    ]
  }
  statement {
    sid       = "DeployRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.backup.arn}/deploy/simulator/*"]
  }
  statement {
    sid       = "DeployList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.backup.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["deploy/simulator", "deploy/simulator/*"]
    }
  }
}

resource "aws_iam_role" "sim" {
  name               = "fds-${local.source_name}-sim"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "sim" {
  for_each = {
    ssm          = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    session_logs = aws_iam_policy.session_logs.arn
  }
  role       = aws_iam_role.sim.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "sim" {
  name   = "fds-${local.source_name}-sim"
  role   = aws_iam_role.sim.id
  policy = data.aws_iam_policy_document.sim.json
}

resource "aws_iam_instance_profile" "sim" {
  name = "fds-${local.source_name}-sim"
  role = aws_iam_role.sim.name
}

resource "aws_instance" "sim" {
  ami                                  = data.aws_ssm_parameter.ubuntu.insecure_value
  instance_type                        = var.sim_instance_type
  subnet_id                            = aws_subnet.this["sim"].id
  private_ip                           = local.sim_private_ip
  vpc_security_group_ids               = [aws_security_group.simulator.id]
  iam_instance_profile                 = aws_iam_instance_profile.sim.name
  instance_initiated_shutdown_behavior = "stop"
  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    auto_stop_after = local.auto_stop_after
    disable_ssh     = true
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size           = local.root_volume_gb
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = { Name = "fds-${local.source_name}-sim" }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

