#!/bin/bash

TRIES=3

cat queries.sql | while read query; do
    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches

    echo "$query";
    for i in $(seq 1 $TRIES); do
        PGPASSWORD='postgres' psql -h localhost -U postgres -d postgres -t -c '\timing' -c "$query" | grep 'Time'
    done;
done;
