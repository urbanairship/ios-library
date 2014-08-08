#!/bin/bash

cd Airship

#find all header files, excluding UASQLite, the internal headers, and AirshipLib.h,
#and convert to Obj-C import statements
find . -type f -name '*.h' ! -name UASQLite.h  ! -name '*+Internal.h' ! -name 'AirshipLib.h' ! -path './UI/*' -exec basename {} \; | awk '{print "#import \"" $0"\""}' > AirshipLib.h
