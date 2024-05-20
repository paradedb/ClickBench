#!/bin/bash

# Variables
PARADEDB_VERSION=0.7.0
PG_MAJOR_VERSION=16

# Cleanup function to reset the environment
cleanup() {
    echo ""
    echo "Cleaning up..."
    # Delete all benchmark data
    psql -h localhost -U postgres -d postgres -p 5432 -t -c "DROP EXTENSION IF EXISTS pg_lakehouse CASCADE;"
    # Stop Postgres
    sudo systemctl stop postgresql
    echo "Done, goodbye!"
}

# Register the cleanup function to run when the script exits
trap cleanup EXIT

# Update the system
echo ""
echo "Updating system..."
sudo apt-get update

## Install Postgres
echo ""
echo "Installing Postgres..."
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
sudo apt-get update && sudo apt-get install -y postgresql-$PG_MAJOR_VERSION postgresql-server-dev-$PG_MAJOR_VERSION
sudo chown -R $(whoami) /usr/share/postgresql/$PG_MAJOR_VERSION/extension/ /usr/lib/postgresql/$PG_MAJOR_VERSION/lib/ /var/lib/postgresql/$PG_MAJOR_VERSION/ /usr/lib/postgresql/$PG_MAJOR_VERSION/bin/ /etc/postgresql/$PG_MAJOR_VERSION/main

# Install pg_lakehouse
echo ""
echo "Installing ParadeDB pg_lakehouse..."
curl -L "https://github.com/paradedb/paradedb/releases/download/v$PARADEDB_VERSION/pg_lakehouse-v$PARADEDB_VERSION-pg$PG_MAJOR_VERSION-amd64-ubuntu2204.deb" -o /tmp/pg_lakehouse.deb 
sudo apt-get install -y --no-install-recommends /tmp/*.deb

# Add pg_lakehouse to shared_preload_libraries
echo ""
echo "Adding pg_lakehouse to Postgres' shared_preload_libraries..."
sudo sed -i "s/^#shared_preload_libraries = .*/shared_preload_libraries = 'pg_lakehouse'/" "/etc/postgresql/$PG_MAJOR_VERSION/main/postgresql.conf"

# Start Postgres
echo ""
echo "Starting Postgres..."
sudo systemctl restart postgresql@$PG_MAJOR_VERSION-main
sudo -u postgres pg_isready
# sudo systemctl start postgresql

# Download benchmark target data, single file
echo ""
echo "Downloading ClickBench single Parquet file dataset..."
if [ ! -e hits.parquet ]; then
    wget --no-verbose --continue https://datasets.clickhouse.com/hits_compatible/hits.parquet
else
    echo "ClickBench single Parquet file dataset already downloaded, skipping..."
fi

# TODO: Also download the partitioned data
# mkdir -p partitioned
# seq 0 99 | xargs -P100 -I{} bash -c 'wget --no-verbose --directory-prefix partitioned --continue https://datasets.clickhouse.com/hits_compatible/athena_partitioned/hits_{}.parquet'

# No data to copy, since we process the Parquet file(s) directly 
# COPY 99997497
# Time: 0000000.000 ms (00:00.000)

echo ""
echo "Running queries..."
./run.sh 2>&1 | tee log.txt

echo ""
echo "Disk usage:"
sudo du -bcs "/var/lib/postgresql/$PG_MAJOR_VERSION/main/"

# 15415061091     /var/lib/postgresql/data
# 15415061091     total

cat log.txt | grep -oP 'Time: \d+\.\d+ ms' | sed -r -e 's/Time: ([0-9]+\.[0-9]+) ms/\1/' |
    awk '{ if (i % 3 == 0) { printf "[" }; printf $1 / 1000; if (i % 3 != 2) { printf "," } else { print "]," }; ++i; }'
