set -euo pipefail

# Usage: sudo bash 091-fetch-and-convert.sh <seed_bucket>
SEED_BUCKET=${1:?missing seed bucket name}
install -d -o postgres -g postgres -m 0750 /pgdata/seed /pgdata/seed/replay
sudo -u postgres aws s3 cp s3://$SEED_BUCKET/core-banking/ /pgdata/seed/ --recursive

cd /pgdata/seed
sudo -u postgres sh -c "jq -r '.target | to_entries[] | [.key, .value] | @csv' train_fraud_labels.json > fraud_labels.csv"
sudo -u postgres sh -c "jq -r 'to_entries[] | [.key, .value] | @csv' mcc_codes.json > mcc_codes.csv"
for f in *.csv; do echo "== $f"; head -2 "$f"; done
