#!/bin/bash

set -uo pipefail

DOMAINS_FILE="domains.txt"
RESULTS_FILE="results.jsonl"
HOSTNAME=$(hostname)

# iterate over each domain in the file and save time taken for DNS resolution to array, show avg, min, max, and percentiles at the end
declare -a times

FIRST_N=5
# first test first N domains, don't save results, just print times to console, wait 10 seconds between tests
echo "Testing first $FIRST_N domains with 10 seconds interval:"
count=0
while IFS= read -r domain && [ $count -lt $FIRST_N ]; do
    output=$(dig "$domain" +time=2 +tries=1)
    query_time=$(echo "$output" | grep "Query time:" | awk '{print $4}')
    echo "Domain: $domain, Query time: ${query_time} ms"
    count=$((count + 1))
    sleep 10
done < "$DOMAINS_FILE"

# test all domains in the file, skip first N already tested, save times to array
echo "Testing all domains and recording query times:"
count=0
while IFS= read -r domain; do
    count=$((count + 1))
    if [ $count -le $FIRST_N ]; then
        continue
    fi
    # perform DNS lookup and capture output
    output=$(dig "$domain" +time=2 +tries=1)
    
    # extract query time using grep and awk
    query_time=$(echo "$output" | grep "Query time:" | awk '{print $4}')
    
    if [[ -n "$query_time" ]]; then
        times+=("$query_time")
    fi
done < "$DOMAINS_FILE"

# calculate stats
num_times=${#times[@]}
if [ $num_times -gt 0 ]; then
    # Sort the array numerically
    sorted_times=($(printf '%s\n' "${times[@]}" | sort -n))
    
    total=0
    for time in "${sorted_times[@]}"; do
        total=$((total + time))
    done
    
    min=${sorted_times[0]}
    max=${sorted_times[$((num_times - 1))]}
    avg=$((total / num_times))
    
    # Calculate percentiles
    idx_50=$(( (50 * num_times) / 100 )); [ $idx_50 -ge $num_times ] && idx_50=$((num_times - 1))
    idx_75=$(( (75 * num_times) / 100 )); [ $idx_75 -ge $num_times ] && idx_75=$((num_times - 1))
    idx_90=$(( (90 * num_times) / 100 )); [ $idx_90 -ge $num_times ] && idx_90=$((num_times - 1))
    idx_95=$(( (95 * num_times) / 100 )); [ $idx_95 -ge $num_times ] && idx_95=$((num_times - 1))
    idx_99=$(( (99 * num_times) / 100 )); [ $idx_99 -ge $num_times ] && idx_99=$((num_times - 1))
    
    p50=${sorted_times[$idx_50]}
    p75=${sorted_times[$idx_75]}
    p90=${sorted_times[$idx_90]}
    p95=${sorted_times[$idx_95]}
    p99=${sorted_times[$idx_99]}

    echo "Total queries: $num_times"
    echo "Average query time: ${avg} ms"
    echo "Minimum query time: ${min} ms"
    echo "Maximum query time: ${max} ms"
    echo "p50 query time: ${p50} ms"
    echo "p75 query time: ${p75} ms"
    echo "p90 query time: ${p90} ms"
    echo "p95 query time: ${p95} ms"
    echo "p99 query time: ${p99} ms"
    
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    JSON_STRING="{\"timestamp\":\"${TIMESTAMP}\",\"hostname\":\"${HOSTNAME}\",\"total_requests\":${num_times},\"min\":${min},\"max\":${max},\"avg\":${avg},\"p50\":${p50},\"p75\":${p75},\"p90\":${p90},\"p95\":${p95},\"p99\":${p99}}"
    
    echo "$JSON_STRING" >> "$RESULTS_FILE"
    echo "Results successfully appended to $RESULTS_FILE"
else
    echo "No valid query times recorded."
fi
