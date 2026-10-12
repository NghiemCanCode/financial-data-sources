data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/arm64/hvm/ebs-gp3/ami-id"
}

resource "aws_instance" "pg" {
  ami                                  = data.aws_ssm_parameter.ubuntu.insecure_value
  instance_type                        = var.instance_type
  subnet_id                            = aws_subnet.this["db"].id
  private_ip                           = local.pg_private_ip
  vpc_security_group_ids               = [aws_security_group.pg.id]
  iam_instance_profile                 = aws_iam_instance_profile.pg.name
  disable_api_termination              = false
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

  dynamic "credit_specification" {
    for_each = startswith(var.instance_type, "t") ? [1] : []
    content {
      cpu_credits = var.cpu_credits
    }
  }

  tags = { Name = "fds-${local.source_name}-pg" }
  lifecycle {
    ignore_changes = [ami, user_data]
  }
}
