systemctl enable --now postgresql@17-main
pg_lsclusters
tail -n 30 /var/log/postgresql/postgresql-$(date +%a).log
sudo -u postgres psql -XAtc "SHOW data_checksums; SHOW wal_level; SHOW huge_pages_status; SHOW ssl;"