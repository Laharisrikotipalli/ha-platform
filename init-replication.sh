#!/bin/bash
set -e
[[ `hostname` =~ -([0-9]+)$ ]] || exit 1
ordinal=${BASH_REMATCH[1]}
echo "==> Hostname: $(hostname), Ordinal: $ordinal"

if [[ $ordinal -eq 0 ]]; then
  echo "==> Configuring as PRIMARY"

  if [ -f "$PGDATA/PG_VERSION" ]; then
    echo "Already initialized, skipping initdb."
  else
    echo "Initializing primary data directory..."
    chmod 777 /var/lib/postgresql/data
    mkdir -p "$PGDATA"
    chown -R postgres:postgres /var/lib/postgresql/data
    chmod 700 "$PGDATA"
    su -m postgres -c "initdb -D $PGDATA"
  fi

  printf 'local all all trust\nhost all all 0.0.0.0/0 trust\nhost replication all 0.0.0.0/0 trust\nlocal replication all trust\n' > "$PGDATA/pg_hba.conf"
  echo "pg_hba.conf updated."

  grep -qxF "listen_addresses='*'" "$PGDATA/postgresql.conf" \
    || echo "listen_addresses='*'" >> "$PGDATA/postgresql.conf"
  grep -qxF "wal_level = replica" "$PGDATA/postgresql.conf" \
    || echo "wal_level = replica" >> "$PGDATA/postgresql.conf"
  grep -qxF "max_wal_senders = 10" "$PGDATA/postgresql.conf" \
    || echo "max_wal_senders = 10" >> "$PGDATA/postgresql.conf"
  grep -qxF "wal_keep_size = 64" "$PGDATA/postgresql.conf" \
    || echo "wal_keep_size = 64" >> "$PGDATA/postgresql.conf"
  grep -qxF "hot_standby = on" "$PGDATA/postgresql.conf" \
    || echo "hot_standby = on" >> "$PGDATA/postgresql.conf"

  echo "Primary configuration complete."

else
  echo "==> Configuring as STANDBY $ordinal"

  if [ -f "$PGDATA/PG_VERSION" ]; then
    echo "Already initialized, skipping pg_basebackup."
    exit 0
  fi

  echo "Waiting for primary to be ready..."
  until pg_isready -h postgres-0.postgres.ha-platform.svc.cluster.local -U postgres; do
    echo "  Primary not ready, retrying in 3s..."
    sleep 3
  done

  echo "Primary is ready. Cloning via pg_basebackup..."
  chmod 777 /var/lib/postgresql/data
  mkdir -p "$PGDATA"
  chown -R postgres:postgres /var/lib/postgresql/data

  su -m postgres -c "PGPASSWORD=$POSTGRES_PASSWORD pg_basebackup \
    -h postgres-0.postgres.ha-platform.svc.cluster.local \
    -D $PGDATA \
    -U postgres \
    -vP -R \
    --wal-method=stream"

  echo "Standby clone complete."
fi