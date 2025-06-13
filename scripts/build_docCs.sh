#!/bin/bash
# build_docs.sh CURRENT_VERSION
#  - CURRENT_VERSION: The SDK current version.

set -o pipefail
set -e

CURRENT_VERSION="$1"

# 🔧 CONFIG
SCHEMES=(
  "AirshipCore"
  "AirshipPreferenceCenter"
  "AirshipMessageCenter"
  "AirshipAutomation"
  "AirshipFeatureFlags"
  "AirshipObjectiveC"
  "AirshipNotificationServiceExtension"
)

BUILD="build"
# Root directory for all documentation
DOCS_DIR="docs"

# 🧼 Clean up
rm -rf $BUILD
rm -rf $DOCS_DIR
mkdir -p "$DOCS_DIR"

# 📘 Generate DocC for each versions and schemes
echo "📘 Building DocC for schemes: ${SCHEMES[*]}"

for SCHEME in "${SCHEMES[@]}"; do
echo "📘 Building DocC for $SCHEME ..."

DERIVED_DATA="$BUILD/$SCHEME"
xcodebuild docbuild \
    -scheme "$SCHEME" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA"

ARCHIVE_PATH=$(find "$DERIVED_DATA" -name "$SCHEME.doccarchive" | head -n 1)
    
if [ -z "$ARCHIVE_PATH" ]; then
    echo "❌ No doccarchive for $SCHEME in $CURRENT_VERSION"
    exit 1
fi
    
OUTPUT_PATH="$DOCS_DIR/$SCHEME"
mkdir -p "$OUTPUT_PATH"

$(xcrun --find docc) process-archive \
    transform-for-static-hosting \
    "$ARCHIVE_PATH" \
    --output-path "$OUTPUT_PATH" \
    --hosting-base-path "/$CURRENT_VERSION/$SCHEME"

echo "✅ $SCHEME docs ready at $OUTPUT_PATH"

done

echo "🎉 Docs generated"


