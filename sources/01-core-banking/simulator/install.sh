!/usr/bin/env bash
# Usage: sudo bash /opt/fds/core-banking/simulator/install.sh   (safe to re-run)

set -euo pipefail
S=/opt/fds/core-banking/simulator
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y python3-venv postgresql-client

id fds-sim >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin fds-sim

python3 -m venv /opt/fds/venv-simulator
/opt/fds/venv-simulator/bin/pip install --quiet --upgrade pip
/opt/fds/venv-simulator/bin/pip install --quiet -r $S/requirements.txt

install -m 0644 $S/fds-simulator.env     /etc/fds-simulator.env
install -m 0644 $S/fds-simulator.service /etc/systemd/system/fds-simulator.service
systemctl daemon-reload
systemctl enable fds-simulator
