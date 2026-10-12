resource "aws_vpc_peering_connection" "cdc" {
  count         = var.cdc_consumer == null ? 0 : 1
  vpc_id        = aws_vpc.this.id
  peer_vpc_id   = var.cdc_consumer.vpc_id
  peer_owner_id = var.cdc_consumer.account_id
  tags          = { Name = "fds-${local.source_name}-to-cdc" }
}

resource "aws_route" "to_cdc" {
  count                     = var.cdc_consumer == null ? 0 : 1
  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = var.cdc_consumer.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.cdc[0].id
}