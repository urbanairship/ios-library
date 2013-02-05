#!/bin/bash -ex

rm -rf distribution_binaries
./buildTarget.sh AirshipLib
./buildTarget.sh AirshipFullLib
./update_library_reference.sh
./package_airshiplib.sh

