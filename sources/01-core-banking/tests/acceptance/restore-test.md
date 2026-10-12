   sudo -u postgres pgbackrest --stanza=core-banking \
     --link-map=pg_wal=/pgwal/17/main \
     --type=immediate --target-action=promote restore
   
