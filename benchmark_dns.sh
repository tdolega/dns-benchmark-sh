#!/bin/bash

set -uo pipefail

show_help() {
    echo "Usage: $0 [DOMAINS_FILE] [RESULTS_FILE]"
    echo ""
    echo "Runs DNS benchmarks for a list of domains."
    echo ""
    echo "Arguments:"
    echo "  DOMAINS_FILE  Path to the text file containing domain names (default: domains.txt)"
    echo "  RESULTS_FILE  Path to save the JSONL results (default: results.jsonl)"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message and exit"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

DOMAINS_FILE="${1:-domains.txt}"
RESULTS_FILE="${2:-results.jsonl}"
HOSTNAME=$(hostname)

if [ ! -f "$DOMAINS_FILE" ]; then
    echo "Error: Domains file '$DOMAINS_FILE' not found!" >&2
    exit 1
fi

if ! command -v dig &> /dev/null; then
    echo "Error: 'dig' command not found. Please install dnsutils/bind-utils." >&2
    exit 1
fi

declare -a times

FIRST_N=5
echo "Testing first $FIRST_N domains with 10 seconds interval:"
count=0
while IFS= read -r domain && [ $count -lt $FIRST_N ]; do
    output=$(dig "$domain" +time=2 +tries=1)
    query_time=$(echo "$output" | grep "Query time:" | awk '{print $4}')
    echo "Domain: $domain, Query time: ${query_time} ms"
    count=$((count + 1))
    sleep 10
done < "$DOMAINS_FILE"

echo "Testing all domains and recording query times:"
count=0
while IFS= read -r domain; do
    count=$((count + 1))
    if [ $count -le $FIRST_N ]; then
        continue
    fi
    output=$(dig "$domain" +time=2 +tries=1)
    
    query_time=$(echo "$output" | grep "Query time:" | awk '{print $4}')
    
    if [[ -n "$query_time" ]]; then
        times+=("$query_time")
    fi
done < "$DOMAINS_FILE"

num_times=${#times[@]}
if [ $num_times -gt 0 ]; then
    sorted_times=($(printf '%s\n' "${times[@]}" | sort -n))
    
    total=0
    for time in "${sorted_times[@]}"; do
        total=$((total + time))
    done
    
    min=${sorted_times[0]}
    max=${sorted_times[$((num_times - 1))]}
    avg=$((total / num_times))
    
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
