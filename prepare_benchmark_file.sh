#!/bin/bash

set -euo pipefail

show_help() {
    echo "Usage: $0 [INPUT_CSV] [OUTPUT_TXT] [NUM_DOMAINS] [SEED] [SKEW]"
    echo ""
    echo "Extracts a random sample of domains from a CSV file."
    echo ""
    echo "Arguments:"
    echo "  INPUT_CSV     Path to the full domains CSV (default: top-1m.csv)"
    echo "  OUTPUT_TXT    Path to save the extracted domains (default: domains.txt)"
    echo "  NUM_DOMAINS   Number of domains to extract (default: 1000)"
    echo "  SEED          Numeric random seed, or 'random' (default: random)"
    echo "  SKEW          Priority for top domains, 0.0=uniform, higher=more top-heavy (default: 1.0)"
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
SEED="${4:-random}"
SKEW="${5:-1.0}"

if [ ! -f "$FULL_DOMAINS_FILE" ]; then
    echo "Error: Input file '$FULL_DOMAINS_FILE' not found!" >&2
    exit 1
fi

echo "Extracting domains from $FULL_DOMAINS_FILE into $OUTPUT_DOMAINS_FILE..."
echo "- Domains to extract: $NUM_DOMAINS"
echo "- Seed: $SEED"
echo "- Skew (priority to top): $SKEW"

# Using awk for weighted random sampling without replacement
awk -v seed="$SEED" -v skew="$SKEW" -F',' '
BEGIN {
    if (seed != "random") {
        srand(seed);
    } else {
        srand();
    }
}
{
    domain = (NF>=2) ? $2 : $1;
    
    # Calculate weight (higher NR -> lower weight if skew > 0)
    weight = 1.0 / (NR ^ skew);
    
    # Generate random score
    r = rand();
    if (r == 0) r = 1e-10;
    
    score = -log(r) / weight;
    
    # Print score and domain separated by tab
    printf "%.10f\t%s\n", score, domain;
}
' "$FULL_DOMAINS_FILE" | sort -n | head -n "$NUM_DOMAINS" | cut -f2 > "$OUTPUT_DOMAINS_FILE"

echo "Done."
