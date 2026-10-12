output "instance_id" {
  value = aws_instance.pg.id
}

output "nat_instance_id" {
  value = aws_instance.nat.id
}

output "sim_instance_id" {
  value = aws_instance.sim.id
}

output "private_ip" {
  value = aws_instance.pg.private_ip
}

output "private_dns" {
  value = aws_instance.pg.private_dns
}

output "instance_profile" {
  value = aws_iam_instance_profile.pg.name
}

output "backup_bucket" {
  value = aws_s3_bucket.backup.bucket
}

output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "sim_subnet_id" {
  value = aws_subnet.this["sim"].id
}

output "simulator_sg_id" {
  value = aws_security_group.simulator.id
}

output "peering_id" {
  value = one(aws_vpc_peering_connection.cdc[*].id)
}

output "data_volume_serial" { value = replace(aws_ebs_volume.this["data"].id, "-", "") }
output "wal_volume_serial" { value = replace(aws_ebs_volume.this["wal"].id, "-", "") }

