#!/bin/bash
# build_docs.sh CURRENT_VERSION
#  - CURRENT_VERSION: The SDK current version.
# Adaptive DocC build script that works for both private and public repos

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
DOCS_DIR="docs"

# 🔍 Detect repository context
if [ -n "$GITHUB_REPOSITORY" ]; then
    # Running in GitHub Actions
    REPO_NAME=$(basename "$GITHUB_REPOSITORY")
else
    # Running locally - try to detect from git remote
    REPO_URL=$(git remote get-url origin 2>/dev/null || echo "")
    if [[ "$REPO_URL" == *"ios-library.git"* ]] || [[ "$REPO_URL" == *"ios-library"* ]]; then
        REPO_NAME="ios-library"
    else
        REPO_NAME="ios-library-dev"
    fi
fi

echo "📘 Building DocC for repository: $REPO_NAME"
echo "📘 Version: $CURRENT_VERSION"

# 🧼 Clean up
rm -rf $BUILD
rm -rf $DOCS_DIR
mkdir -p "$DOCS_DIR"

# 📘 Generate DocC for each scheme
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
    
    # 🔧 Set hosting base path based on repository
    if [ "$REPO_NAME" = "ios-library" ]; then
        HOSTING_BASE_PATH="/ios-library/$CURRENT_VERSION/$SCHEME"
    else
        HOSTING_BASE_PATH="/$CURRENT_VERSION/$SCHEME"
    fi
    
    echo "📘 Using hosting base path: $HOSTING_BASE_PATH"
    
    $(xcrun --find docc) process-archive \
        transform-for-static-hosting \
        "$ARCHIVE_PATH" \
        --output-path "$OUTPUT_PATH" \
        --hosting-base-path "$HOSTING_BASE_PATH"
    
    echo "✅ $SCHEME docs ready at $OUTPUT_PATH"
done

echo "🎉 Docs generated for $REPO_NAME"
