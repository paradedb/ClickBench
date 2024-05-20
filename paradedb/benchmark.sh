#!/bin/bash

# Variables
PG_MAJOR_VERSION=16
PGRX_VERSION=0.11.3

# Cleanup function to reset the environment
cleanup() {
    echo ""
    echo "Cleaning up..."
    # TODO: Make sure the tables are dropped
    cargo pgrx stop
    echo "Done, goodbye!"
}

# Register the cleanup function to run when the script exits
trap cleanup EXIT

# Update the system
sudo apt-get update

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env

## Install Postgres
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
sudo apt-get update && sudo apt-get install -y postgresql-$PG_MAJOR_VERSION postgresql-server-dev-$PG_MAJOR_VERSION
sudo chown -R $(whoami) /usr/share/postgresql/$PG_MAJOR_VERSION/extension/ /usr/lib/postgresql/$PG_MAJOR_VERSION/lib/ /var/lib/postgresql/$PG_MAJOR_VERSION/ /usr/lib/postgresql/$PG_MAJOR_VERSION/bin/

## Install pgrx
cargo install -j $(nproc) --locked cargo-pgrx --version $PGRX_VERSION

# Install ParadeDB
git clone https://github.com/paradedb/paradedb
cd paradedb/
git checkout neil/lakehouse-benchmarks
cd pg_lakehouse/
cargo pgrx init --pg$PG_MAJOR_VERSION=/usr/lib/postgresql/$PG_MAJOR_VERSION/bin/pg_config
cargo pgrx install --release

# Add pg_lakehouse to shared_preload_libraries
# TODO: Need to find proper dir
sed -i "s/^#shared_preload_libraries = .*/shared_preload_libraries = 'pg_lakehouse'/" postgresql.conf

# Install the ParadeDB benchmark tool
cd ../cargo-paradedb/
cargo run install

# Start Postgres
cargo pgrx start

# Run the benchmarks
cargo paradedb bench hits run -w single --url postgresql://localhost:288$PG_MAJOR_VERSION/postgres

# Run the 
cargo paradedb bench hits run -w partitioned --url postgresql://localhost:288$PG_MAJOR_VERSION/postgres

# COPY 99997497
# Time: 1268695.244 ms (21:08.695)

# echo ""
# echo "Running queries..."
# ./run.sh 2>&1 | tee log.txt

# sudo docker exec -it paradedb du -bcs /var/lib/postgresql/data

# 15415061091     /var/lib/postgresql/data
# 15415061091     total

# cat log.txt | grep -oP 'Time: \d+\.\d+ ms' | sed -r -e 's/Time: ([0-9]+\.[0-9]+) ms/\1/' |
#     awk '{ if (i % 3 == 0) { printf "[" }; printf $1 / 1000; if (i % 3 != 2) { printf "," } else { print "]," }; ++i; }'
