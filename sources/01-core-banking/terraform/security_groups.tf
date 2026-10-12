resource "aws_security_group" "pg" {
  name        = "fds-${local.source_name}-pg"
  description = "PostgreSQL ${local.source_name}"
  vpc_id      = aws_vpc.this.id

  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_ingress_rule" "pg_from_simulator" {
  security_group_id            = aws_security_group.pg.id
  referenced_security_group_id = aws_security_group.simulator.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_ingress_rule" "pg_from_cdc" {
  count             = var.cdc_consumer == null ? 0 : 1
  security_group_id = aws_security_group.pg.id
  cidr_ipv4         = var.cdc_consumer.cidr
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
}

resource "aws_vpc_security_group_egress_rule" "pg_web" {
  for_each          = toset(["80", "443"])
  security_group_id = aws_security_group.pg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = tonumber(each.key)
  to_port           = tonumber(each.key)
}

resource "aws_security_group" "simulator" {
  name        = "fds-${local.source_name}-simulator"
  description = "Simulator ${local.source_name}"
  vpc_id      = aws_vpc.this.id

  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_egress_rule" "simulator_all" {
  security_group_id = aws_security_group.simulator.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}