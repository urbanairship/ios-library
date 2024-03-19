#!/bin/bash

set -o pipefail
set -e

if ! which xcbeautify > /dev/null; then
echo "Missing xcbeautify!"
exit 1
fi