#!/bin/bash
set -e

XCFRAMEWORK_PATH=$1
FILE_SIZE=$2
PREVIOUS_FILE_SIZE=$3

echo "Checking size of: $XCFRAMEWORK_PATH"

if [ ! -d "$XCFRAMEWORK_PATH" ]; then
echo "Framework not found at $XCFRAMEWORK_PATH"
exit 1
fi

SIZE_KB=$(du -sk "$XCFRAMEWORK_PATH" | cut -f1)
echo "$SIZE_KB" > "$FILE_SIZE"
echo "Current size: ${SIZE_KB} KB"

if [ -f "$PREVIOUS_FILE_SIZE" ]; then
PREV_SIZE=$(cat "$PREVIOUS_FILE_SIZE")
DIFF=$((SIZE_KB - PREV_SIZE))
if [ $DIFF -gt 0 ]; then
echo "Framework grew by ${DIFF} KB (was ${PREV_SIZE} KB)"
elif [ $DIFF -lt 0 ]; then
echo "Framework shrank by $((-DIFF)) KB (was ${PREV_SIZE} KB)"
else
echo "➖ Framework size unchanged (${SIZE_KB} KB)"
fi
else
echo "No previous size to compare against."
fi

cp "$FILE_SIZE" "$PREVIOUS_FILE_SIZE"
