resource "aws_security_group" "nat" {
  name        = "fds-${local.source_name}-nat"
  description = "NAT instance ${local.source_name}"
  vpc_id      = aws_vpc.this.id

  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_ingress_rule" "nat_from_vpc" {
  security_group_id = aws_security_group.nat.id
  ip_protocol       = "-1"
  cidr_ipv4         = local.vpc_cidr
}

resource "aws_vpc_security_group_egress_rule" "nat_all" {
  security_group_id = aws_security_group.nat.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_iam_role" "nat" {
  name               = "fds-${local.source_name}-nat"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "nat" {
  for_each = {
    ssm          = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    session_logs = aws_iam_policy.session_logs.arn
  }
  role       = aws_iam_role.nat.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "nat" {
  name = "fds-${local.source_name}-nat"
  role = aws_iam_role.nat.name
}

data "aws_ami" "fck_nat" {
  owners      = [var.fck_nat_ami_owner]
  most_recent = true
  filter {
    name   = "name"
    values = ["fck-nat-al2023-*arm64*"]
  }
}

resource "aws_instance" "nat" {
  ami                                  = data.aws_ami.fck_nat.id
  instance_type                        = "t4g.nano"
  subnet_id                            = aws_subnet.this["public"].id
  associate_public_ip_address          = true
  vpc_security_group_ids               = [aws_security_group.nat.id]
  iam_instance_profile                 = aws_iam_instance_profile.nat.name
  source_dest_check                    = false
  instance_initiated_shutdown_behavior = "stop"
  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    auto_stop_after = local.auto_stop_after
    disable_ssh     = true
  })

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = { Name = "fds-${local.source_name}-nat" }

  lifecycle { ignore_changes = [ami, user_data] }
}