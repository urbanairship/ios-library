#!/bin/bash -ex

./buildTarget.sh AirshipLib
./buildTarget.sh AirshipPushLib
./update_library_reference.sh
./package_airshiplib.sh

