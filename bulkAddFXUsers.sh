#!/bin/bash

# =============================================================================
# CSV to cURL POST Script
# =============================================================================
# Update the URL and field names below before use.
# Expects a CSV file path as the first argument: ./csv_to_curl.sh data.csv
# =============================================================================

# --- Config ------------------------------------------------------------------
API_URL="https://your-api-endpoint.com/api/resource"
CSV_FILE="${1:-data.csv}"
SKIP_HEADER=true   # Set to false if your CSV has no header row
# -----------------------------------------------------------------------------

# Validate file exists
if [[ ! -f "$CSV_FILE" ]]; then
  echo "Error: CSV file '$CSV_FILE' not found."
  exit 1
fi

LINE_NUM=0
SUCCESS=0
FAIL=0

while IFS=',' read -r col1 col2 col3 col4 col5 col6 col7 col8; do
  LINE_NUM=$((LINE_NUM + 1))

  # Skip header row if enabled
  if [[ "$SKIP_HEADER" == true && "$LINE_NUM" -eq 1 ]]; then
    echo "Skipping header row..."
    continue
  fi

  # ----- Map CSV columns to meaningful variable names -----------------------
  # TODO: Replace these placeholder names with your actual field names
  value1="$col1"   # e.g. firstname
  value2="$col2"   # e.g. lastname
  value3="$col3"   # e.g. email
  value4="$col4"   # e.g. username
  value5="$col5"   # e.g. password
  value6="$col6"   # e.g. agencyid
  value7="$col7"   # e.g. organisationOfficeID
  value8="$col8"   # e.g. roles
  value9="$col9"   # e.g. primaryroleid
  value10="$col10"  # e.g.  mediatypes
  value11="$col11"  # e.g.  primaryBuyingWorkflowID
  value12="$col12"  # e.g.  teams
  value13="$col13"  # e.g.  memberSInce
  value14="$col14"  # e.g.  MemberTo
  # --------------------------------------------------------------------------

  # Strip any trailing carriage returns (Windows line endings)
  value8="${value8//$'\r'/}"

  # Build JSON payload
  # TODO: Replace the key names (e.g. "field1") with your actual API field names
  PAYLOAD=$(cat <<EOF
{
  "field1": "$value1",
  "field2": "$value2",
  "field3": "$value3",
  "field4": "$value4",
  "field5": "$value5",
  "field6": "$value6",
  "field7": "$value7",
  "field8": "$value8",
  "field9": "$value9",
  "field10": "$value10",
  "field11": "$value11",
  "field12": "$value12",
  "field13": "$value13",
  "field14": "$value14"
}
EOF
)
  echo "Processing row $LINE_NUM: $value1 $value2..."

  # Send the request
  HTTP_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" \
    --request POST \
    --header "Content-Type: application/json" \
    --header "Accept: application/json" \
    --data "$PAYLOAD" \
    "$API_URL")

  if [[ "$HTTP_STATUS" -ge 200 && "$HTTP_STATUS" -lt 300 ]]; then
    echo "  ✓ Row $LINE_NUM sent successfully (HTTP $HTTP_STATUS)"
    SUCCESS=$((SUCCESS + 1))
  else
    echo "  ✗ Row $LINE_NUM failed (HTTP $HTTP_STATUS)"
    FAIL=$((FAIL + 1))
  fi

done < "$CSV_FILE"

# Summary
echo ""
echo "========================================="
echo "Done. Processed $((LINE_NUM - 1)) rows."
echo "  Success : $SUCCESS"
echo "  Failed  : $FAIL"
echo "========================================="
