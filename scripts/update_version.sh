#!/bin/bash -ex
VERSION=$1
ROOT_PATH=`dirname "${0}"`/../

if [ -z "$1" ]
  then
    echo "No version number supplied"
    exit
fi

# Pods
sed -i '' "s/\(^AIRSHIP_VERSION *= *\)\".*\"/\1\"$VERSION\"/g" $ROOT_PATH/Airship.podspec
sed -i '' "s/\(^AIRSHIP_VERSION *= *\)\".*\"/\1\"$VERSION\"/g" $ROOT_PATH/AirshipExtensions.podspec
sed -i '' "s/\(^AIRSHIP_VERSION *= *\)\".*\"/\1\"$VERSION\"/g" $ROOT_PATH/AirshipDebug.podspec
sed -i '' "s/\(^AIRSHIP_VERSION *= *\)\".*\"/\1\"$VERSION\"/g" $ROOT_PATH/AirshipContentExtension.podspec
sed -i '' "s/\(^AIRSHIP_VERSION *= *\)\".*\"/\1\"$VERSION\"/g" $ROOT_PATH/AirshipServiceExtension.podspec

# Airship Config
sed -i '' "s/\CURRENT_PROJECT_VERSION.*/CURRENT_PROJECT_VERSION = $VERSION/g" $ROOT_PATH/Airship/AirshipConfig.xcconfig

# UAirshipVersion.m
sed -i '' "s/\(public static let version *= *\)\".*\"/\1\"$VERSION\"/g" $ROOT_PATH/Airship/AirshipCore/Source/AirshipVersion.swift
