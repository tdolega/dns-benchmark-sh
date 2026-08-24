#!/bin/bash

set -euo pipefail

show_help() {
    echo "Usage: $0 [INPUT_CSV] [OUTPUT_TXT] [NUM_DOMAINS]"
    echo ""
    echo "Extracts a random sample of domains from a CSV file."
    echo ""
    echo "Arguments:"
    echo "  INPUT_CSV     Path to the full domains CSV (default: top-1m.csv)"
    echo "  OUTPUT_TXT    Path to save the extracted domains (default: domains.txt)"
    echo "  NUM_DOMAINS   Number of domains to extract (default: 1000)"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message and exit"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

FULL_DOMAINS_FILE="${1:-top-1m.csv}"
OUTPUT_DOMAINS_FILE="${2:-domains.txt}"
NUM_DOMAINS="${3:-1000}"

if [ ! -f "$FULL_DOMAINS_FILE" ]; then
    echo "Error: Input file '$FULL_DOMAINS_FILE' not found!" >&2
    exit 1
fi

echo "Extracting $NUM_DOMAINS random domains from $FULL_DOMAINS_FILE into $OUTPUT_DOMAINS_FILE..."
shuf -n "$NUM_DOMAINS" "$FULL_DOMAINS_FILE" | cut -d',' -f2 > "$OUTPUT_DOMAINS_FILE"
echo "Done."
