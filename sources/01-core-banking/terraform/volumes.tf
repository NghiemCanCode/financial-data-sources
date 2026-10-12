locals {
  volumes = {
    data = {
      device = "/dev/sdf",
      size   = local.data_volume_gb
    }
    wal = {
      device = "/dev/sdg",
      size   = local.wal_volume_gb
    }
  }
}

resource "aws_ebs_volume" "this" {
  for_each          = local.volumes
  availability_zone = var.az
  size              = each.value.size
  type              = "gp3"
  encrypted         = true
  tags              = { Name = "fds-${local.source_name}-${each.key}" }
}

resource "aws_volume_attachment" "this" {
  for_each                       = local.volumes
  device_name                    = each.value.device
  volume_id                      = aws_ebs_volume.this[each.key].id
  instance_id                    = aws_instance.pg.id
  stop_instance_before_detaching = true
}

