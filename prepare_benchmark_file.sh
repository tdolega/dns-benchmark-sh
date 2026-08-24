#!/bin/bash

set -euo pipefail

FULL_DOMAINS_FILE="top-1m.csv"
OUTPUT_DOMAINS_FILE="domains.txt"
NUM_DOMAINS=1000

# take random sample of NUM_DOMAINS from FULL_DOMAINS_FILE, and save second column (domain names) to OUTPUT_DOMAINS_FILE
shuf -n "$NUM_DOMAINS" "$FULL_DOMAINS_FILE" | cut -d',' -f2 > "$OUTPUT_DOMAINS_FILE"
