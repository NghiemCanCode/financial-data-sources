set -euo pipefail
timedatectl set-timezone UTC
export DEBIAN_FRONTEND=noninteractive

apt-get update && apt-get -y full-upgrade
apt-get install -y xfsprogs jq unzip nvme-cli

command -v aws >/dev/null || {
    echo "Have not install AWS CLI.";
    exit 1;
    }

grep -q '^AWS_DEFAULT_REGION=' /etc/environment || echo 'AWS_DEFAULT_REGION=ap-southeast-1' >> /etc/environment

cloud-init status --wait
systemctl is-enabled ssh.socket
systemctl list-timers auto-stop.timer --no-pager

chronyc sources

if [ -f /var/run/reboot-required ]; then echo "Reboot..."; reboot; fi
