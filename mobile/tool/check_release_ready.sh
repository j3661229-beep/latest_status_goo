#!/usr/bin/env bash
# Fails if owner-only placeholders / known release blockers are still in the mobile app.
# Run before cutting a Play Store build:  bash mobile/tool/check_release_ready.sh
set -u
cd "$(dirname "$0")/.."
fail=0

echo "== Placeholder contact / legal details (lib/core/constants/app_constants.dart) =="
if grep -nE "TODO|\+91 00000|910000000000" lib/core/constants/app_constants.dart; then
  echo "FAIL: fill in the support, company, grievance-officer and policy details above."; fail=1
else
  echo "ok"
fi

echo "== Package id matches google-services.json =="
app_id=$(grep -oE 'applicationId = "[^"]+"' android/app/build.gradle.kts | head -1 | sed -E 's/.*"([^"]+)"/\1/')
if grep -q "\"package_name\": \"$app_id\"" android/app/google-services.json; then
  echo "ok ($app_id)"
else
  echo "FAIL: google-services.json has no client for applicationId '$app_id' — Google Sign-In / Firebase phone auth will not work."
  echo "      Download the google-services.json for '$app_id' from the Firebase console (or change applicationId)."; fail=1
fi

echo "== Live Razorpay key =="
echo "info: release builds must pass --dart-define=RAZORPAY_KEY_ID=rzp_live_... (default is a TEST key)."

exit $fail
