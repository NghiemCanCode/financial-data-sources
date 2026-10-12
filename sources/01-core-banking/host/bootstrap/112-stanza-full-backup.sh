# 1) Switch archive_command from /bin/true to pgBackRest
sed -i "s|^archive_command = .*|archive_command = 'pgbackrest --stanza=core-banking archive-push %p'|" \
  /etc/postgresql/17/main/conf.d/10-fds.conf
sudo -u postgres psql -XAtc "SELECT pg_reload_conf();"
sudo -u postgres psql -XAtc "SHOW archive_command;"

# 2) Create the stanza and check it (check forces a WAL switch and confirms archiving to S3 works)
sudo -u postgres pgbackrest --stanza=core-banking stanza-create
sudo -u postgres pgbackrest --stanza=core-banking check

# 3) First full backup, taken after seeding
sudo -u postgres pgbackrest --stanza=core-banking --type=full backup
sudo -u postgres pgbackrest --stanza=core-banking info
