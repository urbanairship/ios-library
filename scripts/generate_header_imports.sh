#!/bin/bash -ex

SCRIPT_DIRECTORY=`dirname $0`
ROOT_PATH=`dirname "${0}"`/../

cd "${ROOT_PATH}/Airship"

#find all header files, excluding UASQLite, the internal headers, AirshipLib.h,
#UI, and AirshipKit.framework, and convert to Obj-C import statements

find . -type f -name '*.h' ! -name UASQLite.h  ! -name '*+Internal.h' ! -name 'AirshipLib.h' ! -path './UI/*' ! -path './AirshipKit.framework/*' -exec basename {} \; | awk '{print "#import \"" $0"\""}' > AirshipLib.h
