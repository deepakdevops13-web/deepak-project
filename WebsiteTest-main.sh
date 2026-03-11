#!/bin/bash

while true; do
    duration=$((RANDOM % 120 + 60))   # 1–3 minutes
    delay=$(awk -v min=0.1 -v max=1 'BEGIN{srand(); print min+rand()*(max-min)}')

    echo "High load for $duration sec (delay $delay)"
    end=$((SECONDS+duration))
    while [ $SECONDS -lt $end ]; do
        curl -s http://MentionWebServerIPHere:5000/ > /dev/null &
        sleep $delay
    done

    duration=$((RANDOM % 180 + 60))   # 1–4 minutes
    delay=$(awk -v min=1 -v max=3 'BEGIN{srand(); print min+rand()*(max-min)}')

    echo "Low load for $duration sec (delay $delay)"
    end=$((SECONDS+duration))
    while [ $SECONDS -lt $end ]; do
        curl -s http://MentionWebServerIPHere:5000/ > /dev/null &
        sleep $delay
    done
done
