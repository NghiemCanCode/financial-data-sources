#!/usr/bin/env bash
# Step 12.3: install the CloudWatch agent and ship only pgaudit lines to CloudWatch Logs.
# Usage: sudo bash 123-cloudwatch-agent.sh      (safe to re-run)
set -euo pipefail
CFG=/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

if [ ! -x /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl ]; then
  curl -sSL https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/arm64/latest/amazon-cloudwatch-agent.deb \
    -o /tmp/cwagent.deb
  dpkg -i /tmp/cwagent.deb
  rm -f /tmp/cwagent.deb
fi

# The agent runs as user cwagent: grant read access to PostgreSQL logs via group
usermod -aG postgres cwagent

install -o root -g root -m 0644 /opt/fds/core-banking/host/etc/amazon-cloudwatch-agent.json "$CFG"
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c "file:$CFG"
systemctl enable amazon-cloudwatch-agent
systemctl is-active amazon-cloudwatch-agent
