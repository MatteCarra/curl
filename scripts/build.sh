#!/usr/bin/env bash

# Yay shell scripting! This script builds a static version of
# libcurl for iOS.

set -e
# set -x
BASE_PWD="$PWD"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# Setup paths to stuff we need
CURL_VERSION="7.80.0"
DEVELOPER=$(xcode-select --print-path)
DEVROOT="${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain"

export IPHONEOS_DEPLOYMENT_VERSION="6.0"
export MACOSX_DEPLOYMENT_TARGET="10.10"
IPHONEOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IPHONESIMULATOR_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
OSX_SDK=$(xcrun --sdk macosx --show-sdk-path)

# Turn versions like 1.2.3 into numbers that can be compare by bash.
version()
{
   printf "%03d%03d%03d%03d" $(tr '.' ' ' <<<"$1");
}

configure() {
   local OS=$1
   local ARCH=$2
   local HOST=$3
   local BUILD_DIR=$4
   local SRC_DIR=$5

   echo "Configuring for ${OS} ${ARCH} ${HOST}"

   local SDK=
   case "$OS" in
      iPhoneOS)
	 SDK="${IPHONEOS_SDK}"
    TYPE="iphoneos"
    DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_VERSION}"
	 ;;
      iPhoneSimulator)
	 SDK="${IPHONESIMULATOR_SDK}"
    TYPE="iphonesimulator"
    DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_VERSION}"
	 ;;
      MacOSX)
	 SDK="${OSX_SDK}"
    TYPE="macosx"
    DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET}"
	 ;;
      *)
	 echo "Unsupported OS '${OS}'!" >&1
	 exit 1
	 ;;
   esac

   local PREFIX="${BUILD_DIR}/${CURL_VERSION}-${OS}-${ARCH}"

   export PATH="${DEVROOT}/usr/bin/:${PATH}"
   export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot $SDK -m$TYPE-version-min=$DEPLOYMENT_TARGET -fembed-bitcode"
   ${SRC_DIR}/configure --disable-shared --without-zlib --enable-static --enable-ipv6 --host="${HOST}" --prefix=${PREFIX} --with-secure-transport
}

build()
{
   local ARCH=$1
   local HOST=$2
   local OS=$3
   local BUILD_DIR=$4
   local TYPE=$5 # iphoneos/iphonesimulator

   local SRC_DIR="${BUILD_DIR}/curl-${CURL_VERSION}-${TYPE}"
   local PREFIX="${BUILD_DIR}/${CURL_VERSION}-${OS}-${ARCH}"

   mkdir -p "${SRC_DIR}"
   tar xzf "${SCRIPT_DIR}/../curl-${CURL_VERSION}.tar.gz" -C "${SRC_DIR}" --strip-components=1

   echo "Building for ${OS} ${ARCH}"

   # Change dir
   cd "${SRC_DIR}"

   # fix headers for Swift
   configure "${OS}" $ARCH $HOST ${BUILD_DIR} ${SRC_DIR}

   LOG_PATH="${PREFIX}.build.log"
   echo "Building ${LOG_PATH}"
   make -j8 &> ${LOG_PATH}
   make install &> ${LOG_PATH}
   cd ${BASE_PWD}

   # Add arch to library
   if [ -f "${SCRIPT_DIR}/../${TYPE}/lib/libcurl.a" ]; then
      xcrun lipo "${SCRIPT_DIR}/../${TYPE}/lib/libcurl.a" "${PREFIX}/lib/libcurl.a" -create -output "${SCRIPT_DIR}/../${TYPE}/lib/libcurl.a"
   else
      cp "${PREFIX}/lib/libcurl.a" "${SCRIPT_DIR}/../${TYPE}/lib/libcurl.a"
   fi

   rm -rf "${SRC_DIR}"
}

build_ios() {
   local TMP_BUILD_DIR=$( mktemp -d )

   # Clean up whatever was left from our previous build
   rm -rf "${SCRIPT_DIR}"/../{iphonesimulator/include,iphonesimulator/lib}
   mkdir -p "${SCRIPT_DIR}"/../{iphonesimulator/include,iphonesimulator/lib}

   build "i386" "i386-apple-darwin" "iPhoneSimulator" ${TMP_BUILD_DIR} "iphonesimulator"
   build "x86_64" "x86_64-apple-darwin" "iPhoneSimulator" ${TMP_BUILD_DIR} "iphonesimulator"
   build "arm64" "arm-apple-darwin" "iPhoneSimulator" ${TMP_BUILD_DIR} "iphonesimulator"

   # The World is not ready for arm64e!
   # build "arm64e" "iPhoneSimulator" ${TMP_BUILD_DIR} "iphonesimulator"

   rm -rf "${SCRIPT_DIR}"/../{iphoneos/include,iphoneos/lib}
   mkdir -p "${SCRIPT_DIR}"/../{iphoneos/include,iphoneos/lib}

   build "armv7" "armv7-apple-darwin" "iPhoneOS" ${TMP_BUILD_DIR} "iphoneos"
   build "armv7s" "armv7s-apple-darwin" "iPhoneOS" ${TMP_BUILD_DIR} "iphoneos"
   build "arm64" "arm-apple-darwin" "iPhoneOS" ${TMP_BUILD_DIR} "iphoneos"

   # The World is not ready for arm64e!
   # build "arm64e" "iPhoneOS" ${TMP_BUILD_DIR} "iphoneos"

   ditto "${TMP_BUILD_DIR}/${CURL_VERSION}-iPhoneOS-arm64/include/curl" "${SCRIPT_DIR}/../iphoneos/include/curl"
   cp -f "${SCRIPT_DIR}/../shim/shim.h" "${SCRIPT_DIR}/../iphoneos/include/curl/shim.h"

   # Copy headers
   ditto "${TMP_BUILD_DIR}/${CURL_VERSION}-iPhoneSimulator-arm64/include/curl" "${SCRIPT_DIR}/../iphonesimulator/include/curl"
   cp -f "${SCRIPT_DIR}/../shim/shim.h" "${SCRIPT_DIR}/../iphonesimulator/include/curl/shim.h"

   rm -rf ${TMP_BUILD_DIR}
}

build_macos() {
   local TMP_BUILD_DIR=$( mktemp -d )

   # Clean up whatever was left from our previous build
   rm -rf "${SCRIPT_DIR}"/../{macosx/include,macosx/lib}
   mkdir -p "${SCRIPT_DIR}"/../{macosx/include,macosx/lib}

   build "x86_64" "x86_64-apple-darwin" "MacOSX" ${TMP_BUILD_DIR} "macosx"
   build "arm64" "arm-apple-darwin" "MacOSX" ${TMP_BUILD_DIR} "macosx"
   # The World is not ready for arm64e!
   # build "arm64e" "MacOSX" ${TMP_BUILD_DIR} "macosx"

   # Copy headers
   ditto ${TMP_BUILD_DIR}/${CURL_VERSION}-MacOSX-x86_64/include/curl "${SCRIPT_DIR}/../macosx/include/curl"
   cp -f "${SCRIPT_DIR}/../shim/shim.h" "${SCRIPT_DIR}/../macosx/include/curl/shim.h"

   rm -rf ${TMP_BUILD_DIR}
}

# Start

if [ ! -f "${SCRIPT_DIR}/../curl-${CURL_VERSION}.tar.gz" ]; then
   curl -fL "https://curl.se/download/curl-${CURL_VERSION}.tar.gz" -o "${SCRIPT_DIR}/../curl-${CURL_VERSION}.tar.gz"
   rm -f "${SCRIPT_DIR}/../curl-${CURL_VERSION}.tar.gz.sha256"
fi

build_macos
build_ios
