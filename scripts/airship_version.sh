#!/bin/bash

set -o pipefail
set -e

ROOT_PATH=`dirname "${0}"`/..
echo $(awk -F'"' '/public static let version/ { print $2 }' "$ROOT_PATH/Airship/AirshipCore/Source/AirshipVersion.swift")
