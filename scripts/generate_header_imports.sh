#!/bin/bash -ex

# navigate to the public headers directory of the built target
cd ${BUILT_PRODUCTS_DIR}/AirshipKit.framework/Headers

# find all public headers, excluding AirshipLib/AirshipKit and convert into
# objective-c import statements, overwriting AirshipLib.h
find . -type f -name '*.h' ! -name 'AirshipLib.h' ! -name 'AirshipKit.h'  -exec basename {} \; | awk '{print "#import \"" $0"\""}' > AirshipLib.h 

# copy new AirshipLib.h back into the top-level Airship directory
cp AirshipLib.h ${SRCROOT}/../Airship/
