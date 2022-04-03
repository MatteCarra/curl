#!/usr/bin/env bash

set -e
# set -x

BASE_PWD="$PWD"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
FWNAME="curl"

# XCFramework
rm -rf "${BASE_PWD}/Frameworks/${FWNAME}.xcframework"

xcrun xcodebuild -create-xcframework \
	-library "${BASE_PWD}/iphonesimulator/lib/libcurl.a" -headers "${BASE_PWD}/iphonesimulator/include" \
	-library "${BASE_PWD}/iphoneos/lib/libcurl.a" -headers "${BASE_PWD}/iphoneos/include" \
	-output "${BASE_PWD}/Frameworks/${FWNAME}.xcframework"

# Zip archive
zip --symlinks -r "${BASE_PWD}/Frameworks/${FWNAME}.xcframework.zip" "${BASE_PWD}/Frameworks/${FWNAME}.xcframework"