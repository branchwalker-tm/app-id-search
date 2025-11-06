#!/bin/bash

# --- Configuration ---
FIREWALL_IP="<YOUR_FIREWALL_IP_OR_HOSTNAME>" # Use the IP provided
API_KEY="<YOUR_API_KEY>"          # Use the key placeholder provided
# ---------------------

# Check if a search term was provided
if [ -z "$1" ]; then
    echo "🚨 Error: Please provide a word to search for."
    echo "Usage: $0 <search_word>"
    exit 1
fi

SEARCH_WORD="$1"

echo "🔍 Running API command and searching for applications matching: **$SEARCH_WORD**"
echo "----------------------------------------------------------------------"

# 1. Execute the curl command directly.
# 2. Pipe the output immediately to the search.
SEARCH_RESULT=$(
    curl -s -k "https://${FIREWALL_IP}/api/?type=op&cmd=<show><running><application><statistics/></application></running></show>&key=${API_KEY}" | \
    grep -i "$SEARCH_WORD"
)

APPLICATION_NAME=$(echo "$SEARCH_RESULT" | awk '{print $1}')

# Output the result
if [ -n "$APPLICATION_NAME" ]; then
    echo "✅ Found Match(es):"
    echo "---"
    # Show the matching line(s)
    echo "$APPLICATION_NAME"
else
    echo "❌ No matching string found in the API response for '$SEARCH_WORD'."
fi

echo "----------------------------------------------------------------------"
