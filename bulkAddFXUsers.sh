#!/bin/bash

# =============================================================================
# CSV to cURL POST Script
# =============================================================================
# Update the URL and field names below before use.
# Expects a CSV file path as the first argument: ./csv_to_curl.sh data.csv
# =============================================================================

# --- Config ------------------------------------------------------------------
API_URL="https://ondemand.fx.flywheeldigital.com/agency-central/api/admin/users"
CSV_FILE="${1:-data.csv}"
USERNAME="${2}"
PASSWORD_VAR="${3}"
SKIP_HEADER=${4:-true}   # Set to false if your CSV has no header row
DRYRUN=${5:-false}
FAILEDRECORDS=()
EUsername=$(jq -nr --arg str "${USERNAME}"'$str|@uri')
# -----------------------------------------------------------------------------

# Validate file exists
if [[ ! -f "$CSV_FILE" ]]; then
  echo "Error: CSV file '$CSV_FILE' not found."
  exit 1
fi

LINE_NUM=0
SUCCESS=0
FAIL=0

# --- Get Authentication cookie ---
echo "Getting authentication details"
cookie=$(curl -s -D - -H "Content-Type: application/x-www-form-urlencoded" -d "username=${EUsername}&password=${PASSWORD_VAR}" -X POST  "${BASE_URL}/api/authenticate" | grep -i Set-Cookie | cut -d " " -f 2,3 | tr -d )
echo "$cookie"

while IFS=',' read -r col1 col2 col3 col4 col5 col6 col7 col8 col9 col10 col11 col12 col13 col14; do
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
  value14="${value14//$'\r'/}"

  # Build JSON payload
  # TODO: Replace the key names (e.g. "field1") with your actual API field names
  PAYLOAD=$(cat <<EOF
{
  "firstName": "$value1",
  "lastnNme": "$value2",
  "email": "$value3",
  "username": "$value4",
  "password": "$value5",
  "agencyId": "$value6",
  "organisationOfficeId": "$value7",
  "roles": "$value8",
  "primaryRoleId": "$value9",
  "mediaTypes": "$value10",
  "primaryBuyingWorkflowId": "$value11",
  "teams": "$value12",
  "memberSince": "$value13",
  "memberTo": "$value14"
}
EOF
)
  echo "Processing row $LINE_NUM: $value1 $value2..."
  
  
  if DRYRUN; then
    echo "$PAYLOAD"
  else
    # Send the request
    HTTP_STATUS=$(curl --cookie "$cookie" \
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
      FAILEDRECORDS+=$LINE_NUM
    fi
  fi
  # Send the request
  HTTP_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" --cookie "$cookie" \
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
    FAILEDRECORDS+=$LINE_NUM
  fi

done < "$CSV_FILE"

# Summary
echo ""
echo "========================================="
echo "Done. Processed $((LINE_NUM - 1)) rows."
echo "  Success : $SUCCESS"
echo "  Failed  : $FAIL"
echo "  Failed records: $FAILEDRECORDS"
echo "========================================="
