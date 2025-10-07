#!/bin/bash
set -e
XCFRAMEWORK_PATH=$1
FILE_SIZE=$2
PREVIOUS_FILE_SIZE=$3

echo "Checking all XCFrameworks in: $XCFRAMEWORK_PATH"
echo "---------------------------------------------"
# Ensure required arguments are passed
if [ -z "$XCFRAMEWORK_PATH" ] || [ -z "$FILE_SIZE" ] || [ -z "$PREVIOUS_FILE_SIZE" ]; then
  echo "Usage: $0 <xcframeworks_folder> <current_size_file> <previous_size_file>"
  exit 1
fi
#  Use a temporary file for safe writing
TEMP_FILE=$(mktemp /tmp/xcframework_sizes.XXXXXX)
# Collect current sizes for all frameworks
found_any=false
echo "Current XCFramework sizes:"
for f in "$XCFRAMEWORK_PATH"/*.xcframework; do
  if [ -d "$f" ]; then
    found_any=true
    size_kb=$(du -sk "$f" | cut -f1)
    name=$(basename "$f")
    echo "$name=$size_kb" >> "$TEMP_FILE"
    echo "  $name → ${size_kb} KB"
  fi
done
if [ "$found_any" = false ]; then
  echo "No .xcframework files found in $XCFRAMEWORK_PATH"
  rm -f "$TEMP_FILE"
  exit 1
fi
# Compare with previous sizes
if [ -f "$PREVIOUS_FILE_SIZE" ] && [ -s "$PREVIOUS_FILE_SIZE" ]; then
  echo ""
  echo " Comparing with previous sizes:"
  echo "---------------------------------------------"
  # Loop through current sizes
  while IFS="=" read -r name size; do
    # Look up previous size by grep
    if prev=$(grep "^$name=" "$PREVIOUS_FILE_SIZE" 2>/dev/null | cut -d= -f2); then
      if [ -z "$prev" ]; then
        echo "$name is new (${size} KB)"
      else
        diff=$((size - prev))
        if [ $diff -gt 0 ]; then
          echo "$name grew by ${diff} KB (was ${prev} KB)"
        elif [ $diff -lt 0 ]; then
          echo "$name shrank by $((-diff)) KB (was ${prev} KB)"
        else
          echo "$name unchanged (${size} KB)"
        fi
      fi
    else
      echo "   $name is new (${size} KB)"
    fi
  done < "$TEMP_FILE"
else
  echo ""
  echo "No previous size file found — creating baseline."
fi
# Safely move temp file to target FILE_SIZE
mv "$TEMP_FILE" "$FILE_SIZE" 2>/dev/null || {
  echo "Could not overwrite $FILE_SIZE directly, trying sudo..."
  sudo mv "$TEMP_FILE" "$FILE_SIZE"
}
#  Update previous size file
cp "$FILE_SIZE" "$PREVIOUS_FILE_SIZE" 2>/dev/null || {
  echo "Could not update $PREVIOUS_FILE_SIZE, trying sudo..."
  sudo cp "$FILE_SIZE" "$PREVIOUS_FILE_SIZE"
}
echo ""
echo "Size check complete. Baseline updated: $PREVIOUS_FILE_SIZE"
