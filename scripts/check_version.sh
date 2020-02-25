#!/bin/bash
set -e
set -x

ROOT_PATH=`dirname "${0}"`/..
AIRSHIP_VERSION=$(sh "$ROOT_PATH/scripts/airship_version.sh")

if [ $1 = $AIRSHIP_VERSION ]; then
 exit 0
else
 exit 1
fi
