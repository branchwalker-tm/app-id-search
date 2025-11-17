#!/bin/bash

# --- Configuration ---
FIREWALL_IP="<YOUR_FIREWALL_IP>"
API_KEY="<YOUR_API_KEY>"
# ---------------------

# --- Constants ---
OUTPUT_HEADER="App_Name,Sessions,Packets,Bytes,App_Changed,Threats"
# Note: STATS_PATTERN is no longer used for the initial search, but is kept for reference.
# STATS_PATTERN="\s*[0-9]+\s*[0-9]+\s*[0-9]+\s*[0-9]+\s*[0-9]+"

# --- Argument Check ---
if [ -z "$2" ]; then
    echo "Error: Please provide both input and output file paths."
    echo "Usage: $0 <input_app_list.csv> <output_stats.csv>"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' not found."
    exit 1
fi

echo "Batch processing application statistics..."
echo "----------------------------------------------------------------------"

# 1. FETCH RAW DATA FROM FIREWALL
echo "1. Fetching application statistics from firewall..."

# Execute the command, redirecting stderr to dev/null to suppress the curl progress meter.
FULL_RESPONSE=$(
    curl -k "https://${FIREWALL_IP}/api/?type=op&cmd=<show><running><application><statistics/></application></running></show>&key=${API_KEY}" 2>/dev/null
)

# --- DIAGNOSTIC STEP ---
if [ -z "$FULL_RESPONSE" ]; then
    echo "**DIAGNOSTIC FAILURE:** curl command returned an empty string."
    echo "   Action: Check network connectivity/firewall access."
    exit 1
fi
echo "--- RAW RESPONSE RECEIVED (Check for 'success' status or explicit error messages) ---"
# We only print the first few lines of the response to keep the output clean
echo "$FULL_RESPONSE" | head -n 10 
echo "(... output truncated for space)"
echo "-----------------------------------------------------------------------------------"
# --- END DIAGNOSTIC STEP ---


# FIX: Extract individual application records into a clean, line-by-line format.
RAW_DATA_RECORDS=$(
    echo "$FULL_RESPONSE" | \
    # 1. Extract everything between <result> and </result>
    sed -n '/<result>/,/<\/result>/p' | \
    # 2. Remove XML tags and header/footer lines that don't contain data
    grep -vE 'Vsys|Number of apps|App \(report-as\)|---|Total|</result>|^$|<response|status=' | \
    # 3. Remove the opening <result> tag
    sed 's/<result>//' | \
    # 4. Remove leading/trailing spaces from each line
    sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
)


if [ -z "$RAW_DATA_RECORDS" ]; then
    echo "Failed to retrieve or parse application records."
    echo "   Action: The full response was received. Check the RAW RESPONSE for malformed XML or an API error message."
    exit 1
fi

# 2. INITIALIZE OUTPUT FILE
echo "2. Initializing output file: $OUTPUT_FILE"
echo "$OUTPUT_HEADER" > "$OUTPUT_FILE"

TOTAL_PROCESSED=0
TOTAL_MATCHED=0

# 3. PROCESS INPUT CSV AND SEARCH CACHE
echo "3. Processing input applications from: $INPUT_FILE"
echo "---"

# Read the CSV file line by line.
while IFS=',' read -r APP_NAME
do
    APP_NAME=$(echo "$APP_NAME" | xargs)
    
    # Skip empty lines or headers in the input file
    if [ -z "$APP_NAME" ] || [[ "$APP_NAME" =~ ^App-ID ]]; then
        continue
    fi
    
    # 4. SEARCH THE CACHED DATA FOR FUZZY MATCHES (Substring Search)
    # The search is now simple: find any line where the APP_NAME is a case-insensitive substring.
    MATCHES=$(
        echo "$RAW_DATA_RECORDS" | \
        grep -iE "$APP_NAME" | \
        # Ensure we only keep lines that look like app stats (start with word, end with numbers)
        grep -E '^[a-zA-Z0-9-].*[0-9]$'
    )
    
    if [ -n "$MATCHES" ]; then
        # 5. REFORMAT MATCH AND WRITE TO OUTPUT
        # Loop through all found matches
        echo "$MATCHES" | while read -r MATCH_LINE
        do
            # Replace all sequences of spaces (tr -s) with a single comma (sed)
            CSV_LINE=$(echo "$MATCH_LINE" | tr -s ' ' | sed 's/ /,/g')
            
            # Extract the actual found app name for logging
            ACTUAL_APP_NAME=$(echo "$CSV_LINE" | cut -d',' -f1)
            
            echo "FOUND: Input '$APP_NAME' matched '$ACTUAL_APP_NAME' -> $CSV_LINE"
            echo "$CSV_LINE" >> "$OUTPUT_FILE"
            TOTAL_MATCHED=$((TOTAL_MATCHED + 1))
        done
    else
        echo "   SKIP: $APP_NAME (No close match found)"
    fi

    TOTAL_PROCESSED=$((TOTAL_PROCESSED + 1))
    
done < "$INPUT_FILE"

# 6. SUMMARY REPORT
echo "---"
echo "Summary Report:"
echo "Processed unique inputs: $TOTAL_PROCESSED"
echo "Matched records written: $TOTAL_MATCHED"
echo "Output file generated: $OUTPUT_FILE"
echo "----------------------------------------------------------------------"
