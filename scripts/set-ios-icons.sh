#!/bin/bash
# ./set-ios-icons.sh <png file> <PushSample or InboxSample>

p=`dirname "$0"`
f="${p}/../${2}/Resources/Images.xcassets/AppIcon.appiconset"
echo ${f}

# Universal app icon requirements.

# Required
sips --resampleWidth 120 "${1}" --out "${f}/Icon-60@2x.png"
sips --resampleWidth 76 "${1}" --out "${f}/Icon-76.png"

# Optional but recommended
sips --resampleWidth 180 "${1}" --out "${f}/Icon-60@3x.png"
sips --resampleWidth 152 "${1}" --out "${f}/Icon-76@2x.png"
sips --resampleWidth 40 "${1}" --out "${f}/Icon-Small-40.png"
sips --resampleWidth 80 "${1}" --out "${f}/Icon-Small-40@2x.png"
sips --resampleWidth 120 "${1}" --out "${f}/Icon-Small-40@3x.png"

# Recommended if you have a Settings bundle, optional otherwise
sips --resampleWidth 29 "${1}" --out "${f}/Icon-Small.png"
sips --resampleWidth 58 "${1}" --out "${f}/Icon-Small@2x.png"
sips --resampleWidth 87 "${1}" --out "${f}/Icon-Small@3x.png"


# Universal app icon requirements (iOS 6.1 and earlier)

# Required
sips --resampleWidth 57 "${1}" --out "${f}/Icon.png"
sips --resampleWidth 72 "${1}" --out "${f}/Icon-72.png"

# Optional but recommended
sips --resampleWidth 114 "${1}" --out "${f}/Icon@2x.png"
sips --resampleWidth 144 "${1}" --out "${f}/Icon-72@2x.png"
sips --resampleWidth 50 "${1}" --out "${f}/Icon-Small-50.png"
sips --resampleWidth 100 "${1}" --out "${f}/Icon-Small-50@2x.png"
