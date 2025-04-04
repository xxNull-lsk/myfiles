#!/bin/bash
script_path=$(readlink -f "$0")
if [ $? -ne 0 ]; then
    echo "get script path failed"
    exit 1
fi
script_dir=$(dirname "$script_path")
if [ $? -ne 0 ]; then
    echo "get script dir failed"
    exit 1
fi
cd $script_dir
DIR=$(pwd)

BUILD_TYPE=$1
if [ -z "$BUILD_TYPE" ]; then
    BUILD_TYPE="debug"
fi

# 处理版本号
if [ ! -f ".version_major" ]; then
    echo "1" >.version_major
fi
version_major=$(cat .version_major)

if [ ! -f ".version_minor" ]; then
    echo "0" >.version_minor
fi
version_minor=$(cat .version_minor)

if [ ! -f ".version_fixed" ]; then
    echo "0" >.version_fixed
fi
version_fixed=$(cat .version_fixed)

version="$version_major.$version_minor.$version_fixed"
BuildVersion="$version"

rm -rf $DIR/dist
mkdir -p $DIR/dist

cd $DIR/fileclient
./bld.sh $BUILD_TYPE

cd $DIR/fileshared
./bld.sh $BUILD_TYPE

cd $DIR/install-wizard
./bld.sh $BUILD_TYPE

cd $DIR

IP_TYPE=4
if [ -f ".check.net.sh" ]; then
    source .check.net.sh
fi
echo IP_TYPE=$IP_TYPE
if [ "$BUILD_TYPE" == "release" ]; then
    git add .
    git commit -m "Release: $BuildVersion"
    git push -${IP_TYPE}
    git tag "v$BuildVersion"
    git push -${IP_TYPE} origin ":v$BuildVersion"
    git push -${IP_TYPE} --tags
fi

cd $DIR/server
./bld.sh $BUILD_TYPE

cd $DIR
next_version_fixed=$((version_fixed + 1))
echo $next_version_fixed >.version_fixed

if [ -f ".upload.sh" ]; then
    bash .upload.sh $BUILD_TYPE $IP_TYPE
fi

exit 0
