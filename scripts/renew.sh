#!/usr/bin/env bash
# ---------------------------------------------------------------------
# renew.sh: resets the 60-day BigQuery sandbox expiry on all dashboard views.
#
# What it does:
#   1. Re-runs sql/setup.sql (CREATE OR REPLACE, so it also restores any
#      view that has already expired).
#   2. Explicitly sets each view's expiration to 59 days from now.
#   3. Prints the new expiry date of every view so you can confirm.
#
# Safe to run as often as you like. Run it at least every ~50 days.
# Usage:  ./scripts/renew.sh
# ---------------------------------------------------------------------
set -euo pipefail

PROJECT="ecom-retention-shuvro"
DATASET="retention_engine"
VIEWS=(
  v_monthly_revenue_timeline
  v_customer_rfm_segments
  v_product_profit_margins
  v_customer_cohort_retention
)
# 59 days in seconds (the sandbox limit is 60, so stay safely under it)
EXPIRY_SECONDS=5097600

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="$SCRIPT_DIR/../sql/setup.sql"

if [[ ! -f "$SQL_FILE" ]]; then
  echo "ERROR: cannot find $SQL_FILE" >&2
  exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Renewing views in $PROJECT:$DATASET"

echo "Step 1/3: recreating views from setup.sql ..."
bq query --use_legacy_sql=false --project_id="$PROJECT" --quiet < "$SQL_FILE" > /dev/null

echo "Step 2/3: resetting expiration to 59 days ..."
for v in "${VIEWS[@]}"; do
  bq update --project_id="$PROJECT" --expiration "$EXPIRY_SECONDS" "${PROJECT}:${DATASET}.${v}" > /dev/null
done

echo "Step 3/3: verifying ..."
for v in "${VIEWS[@]}"; do
  ms=$(bq show --project_id="$PROJECT" --format=prettyjson "${PROJECT}:${DATASET}.${v}" \
        | grep '"expirationTime"' | tr -dc '0-9')
  if [[ -z "$ms" ]]; then
    echo "  $v: no expiry set"
  else
    secs=$((ms / 1000))
    # macOS uses date -r, Linux uses date -d
    when=$(date -r "$secs" '+%Y-%m-%d' 2>/dev/null || date -d "@$secs" '+%Y-%m-%d')
    echo "  $v: expires $when"
  fi
done

echo "Done. Next renewal due within 50 days."
