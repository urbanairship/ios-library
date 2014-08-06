#!/bin/bash

cd Airship

find . -type f -name '*.h' ! -name '*+Internal.h' ! -name 'AirshipLib.h' ! -path './UI/*' -exec basename {} \; | awk '{print "#import \"" $0"\""}' > AirshipLib.h
