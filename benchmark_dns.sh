#!/bin/bash

set -uo pipefail

show_help() {
    echo "Usage: $0 [DOMAINS_FILE] [RESULTS_FILE] [DNS_SERVER]"
    echo ""
    echo "Runs DNS benchmarks for a list of domains."
    echo ""
    echo "Arguments:"
    echo "  DOMAINS_FILE  Path to the text file containing domain names (default: domains.txt)"
    echo "  RESULTS_FILE  Path to save the JSONL results (default: results.jsonl)"
    echo "  DNS_SERVER    DNS server to use for queries (default: system default)"
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
DNS_SERVER="${3:-}"
HOSTNAME=$(hostname)

DIG_ARGS=("+time=2" "+tries=1")
if [ -n "$DNS_SERVER" ]; then
    DIG_ARGS=("@$DNS_SERVER" "${DIG_ARGS[@]}")
fi

if [ ! -f "$DOMAINS_FILE" ]; then
    echo "Error: Domains file '$DOMAINS_FILE' not found!" >&2
    exit 1
fi

if ! command -v dig &> /dev/null; then
    echo "Error: 'dig' command not found. Please install dnsutils/bind-utils." >&2
    exit 1
fi

INPUT_HASH=$(md5sum "$DOMAINS_FILE" | awk '{print $1}')

# iterate over each domain in the file and save time taken for DNS resolution to array, show avg, min, max, etc. at the end
declare -a times

# example of dig output:
# ╰─❯ dig gbn.pl
# 
# ; <<>> DiG 9.20.15 <<>> gbn.pl
# ;; global options: +cmd
# ;; Got answer:
# ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 26471
# ;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
# 
# ;; OPT PSEUDOSECTION:
# ; EDNS: version: 0, flags:; udp: 512
# ;; QUESTION SECTION:
# ;gbn.pl.                                IN      A
# 
# ;; ANSWER SECTION:
# gbn.pl.                 2595    IN      A       193.143.18.18
# 
# ;; Query time: 0 msec
# ;; SERVER: 127.0.0.1#53(127.0.0.1) (UDP)
# ;; WHEN: Wed Oct 29 23:10:27 CET 2025
# ;; MSG SIZE  rcvd: 51

FIRST_N=5
# first test first N domains, don't save results, just print times to console, wait 10 seconds between tests
echo "=== WARMUP PHASE ==="
echo "Testing first $FIRST_N domains with 10 seconds interval:"
count=0
while IFS= read -r domain && [ $count -lt $FIRST_N ]; do
    domain="${domain//$'\r'/}"
    count=$((count + 1))
    output=$(dig "$domain" "${DIG_ARGS[@]}")
    query_time=$(echo "$output" | grep "Query time:" | awk '{print $4}')
    
    printf "[Warmup %d/%d] %-30s : %s ms\n" "$count" "$FIRST_N" "$domain" "${query_time:-N/A}"
    
    if [ $count -lt $FIRST_N ]; then
        sleep 10
    fi
done < "$DOMAINS_FILE"

# test all domains in the file, skip first N already tested, save times to array
echo ""
echo "=== BENCHMARK PHASE ==="
echo "Testing all remaining domains and recording query times..."
count=0
while IFS= read -r domain; do
    domain="${domain//$'\r'/}"
    count=$((count + 1))
    if [ $count -le $FIRST_N ]; then
        continue
    fi
    # perform DNS lookup and capture output
    output=$(dig "$domain" "${DIG_ARGS[@]}")
    
    # extract query time using grep and awk
    query_time=$(echo "$output" | grep "Query time:" | awk '{print $4}')
    
    if [[ -n "$query_time" ]]; then
        times+=("$query_time")
    fi
done < "$DOMAINS_FILE"

echo "Done."
echo ""

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
    idx_90=$(( (90 * num_times) / 100 )); [ $idx_90 -ge $num_times ] && idx_90=$((num_times - 1))
    idx_99=$(( (99 * num_times) / 100 )); [ $idx_99 -ge $num_times ] && idx_99=$((num_times - 1))
    
    p50=${sorted_times[$idx_50]}
    p90=${sorted_times[$idx_90]}
    p99=${sorted_times[$idx_99]}

    echo "+------------------------+-------------------+"
    echo "| Metric                 | Value             |"
    echo "+------------------------+-------------------+"
    printf "| %-22s | %-17s |\n" "Total queries" "$num_times"
    printf "| %-22s | %-17s |\n" "Average query time" "${avg} ms"
    printf "| %-22s | %-17s |\n" "Minimum query time" "${min} ms"
    printf "| %-22s | %-17s |\n" "Maximum query time" "${max} ms"
    printf "| %-22s | %-17s |\n" "p50 query time" "${p50} ms"
    printf "| %-22s | %-17s |\n" "p90 query time" "${p90} ms"
    printf "| %-22s | %-17s |\n" "p99 query time" "${p99} ms"
    echo "+------------------------+-------------------+"
    
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    JSON_STRING="{\"timestamp\":\"${TIMESTAMP}\",\"hostname\":\"${HOSTNAME}\",\"dns_server\":\"${DNS_SERVER:-default}\",\"input_hash\":\"${INPUT_HASH}\",\"total_requests\":${num_times},\"min\":${min},\"max\":${max},\"avg\":${avg},\"p50\":${p50},\"p90\":${p90},\"p99\":${p99}}"
    
    echo "$JSON_STRING" >> "$RESULTS_FILE"
    echo ""
    echo "Results successfully appended to $RESULTS_FILE"
else
    echo "No valid query times recorded."
fi
