resource "aws_sns_topic" "alerts" {
  name = "fds-${local.source_name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_log_group" "pgaudit" {
  name              = "/fds/${local.source_name}/pgaudit"
  retention_in_days = 14
}

locals {
  alarms = {
    wal-disk        = { metric = "WalDiskUsedPercent", threshold = 80, periods = 3 }
    slot-retained   = { metric = "SlotRetainedWalBytes", threshold = local.alarm_slot_retained_bytes, periods = 5 }
    slot-lost       = { metric = "SlotsLost", threshold = 0, periods = 1 }
    archive-failing = { metric = "ArchiveFailing", threshold = 0, periods = 5 }
    connections     = { metric = "ClientConnections", threshold = local.alarm_connections, periods = 3 }
  }
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each            = local.alarms
  alarm_name          = "${local.source_name}-${each.key}"
  namespace           = local.metric_namespace
  metric_name         = each.value.metric
  dimensions          = { Source = local.source_name }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = each.value.periods
  threshold           = each.value.threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}
