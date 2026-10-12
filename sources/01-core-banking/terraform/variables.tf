variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "az" {
  type    = string
  default = "ap-southeast-1a"
}

variable "alert_email" {
  type = string
}

variable "seed_bucket" {
  type = string
}

variable "fck_nat_ami_owner" {
  type = string
}

variable "cpu_credits" {
  type    = string
  default = "unlimited"
}

variable "session_log_group" {
  type    = string
  default = "/fds/ssm-sessions"
}

variable "cdc_consumer" {
  type = object({
    vpc_id     = string
    cidr       = string
    account_id = string
  })
  default = null
}

variable "instance_type" {
  type    = string
  default = "t4g.large"
}

variable "sim_instance_type" {
  type    = string
  default = "t4g.micro"
}

locals {
  source_name      = "core-banking"
  metric_namespace = "FDS/CoreBanking"
  account_id       = data.aws_caller_identity.me.account_id
  region           = data.aws_region.this.region

  vpc_cidr = "10.101.0.0/16"
  subnets = {
    public = "10.101.0.0/24"
    db     = "10.101.10.0/24"
    sim    = "10.101.20.0/24"
  }
  pg_private_ip  = "10.101.10.10"
  sim_private_ip = "10.101.20.10"

  root_volume_gb = 8
  data_volume_gb = 30
  wal_volume_gb  = 15

  db_roles                  = ["app_simulator", "cdc_airbyte", "ro_analyst"]
  alarm_slot_retained_bytes = 4294967296
  alarm_connections         = 80
  auto_stop_after           = "12h"
}
