#!/bin/bash -ex
set -o pipefail

# TODO: this is merely a shim that points our CI system to the newer, preferred 'scripts' version
# this should be removed once the job has been updated


SCRIPT_DIRECTORY=`dirname ${0}`/scripts
ROOT_PATH=`dirname "${0}"`

"${SCRIPT_DIRECTORY}/run-ci-tasks.sh"


