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
BUILD_DEST_OS=$2
BUILD_DEST_ARCH=$3

# 处理版本号
if [ ! -f "../.version_major" ]; then
    echo "1" >../.version_major
fi
version_major=$(cat ../.version_major)

if [ ! -f "../.version_minor" ]; then
    echo "0" >../.version_minor
fi
version_minor=$(cat ../.version_minor)

if [ ! -f "../.version_fixed" ]; then
    echo "0" >../.version_fixed
fi
version_fixed=$(cat ../.version_fixed)

version="$version_major.$version_minor.$version_fixed"
BuildVersion="$version"
BuildTime=$(date "+%Y-%m-%d %H:%M:%S")
BuildCommitID=$(git rev-parse HEAD)
AppPkgName="myfileserver"
ProjectURL="https://github.com/xxNull-lsk/myfiles"

LDFLAGS="-X '$AppPkgName/lib.AppName=$AppPkgName' -X '$AppPkgName/lib.AppVersion=$BuildVersion' -X '$AppPkgName/lib.AppTime=$BuildTime' -X '$AppPkgName/lib.AppCommitID=$BuildCommitID' -X '$AppPkgName/lib.ProjectURL=$ProjectURL'"
LDFLAGS="-s -w $LDFLAGS"
export CGO_ENABLED=1

declare -A tools
tools=([arm]="arm-linux-gnueabi-gcc" [arm64]="aarch64-linux-gnu-gcc" [mips]="mips-linux-gnu-gcc" [mipsle]="mipsel-linux-gnu-gcc" [mips64]="mips64-linux-gnuabi64-gcc" [mips64le]="mips64el-linux-gnuabi64-gcc" [riscv64]="riscv64-linux-gnu-gcc" [amd64]="x86_64-linux-gnu-gcc" [386]="i686-linux-gnu-gcc-8")
if [ "$BUILD_TYPE" != "release" ]; then
    tools=([amd64]="x86_64-linux-gnu-gcc")
fi
for arch in amd64 386 arm arm64 mips mipsle mips64 mips64le riscv64; do
    if [ -z "${tools[$arch]}" ]; then
        continue
    fi
    if [ "linux" != "$BUILD_DEST_OS" ] && [ "" != "$BUILD_DEST_OS" ]; then
        continue
    fi
    if [ "$arch" != "$BUILD_DEST_ARCH" ] && [ "" != "$BUILD_DEST_ARCH" ]; then
        continue
    fi
    gcc_path=$(which ${tools["$arch"]})
    if [ $? -ne 0 ]; then
        echo "未找到 $arch 交叉编译工具 ${tools["$arch"]}"
        continue
    fi
    echo "Building for linux $arch use ${tools["$arch"]}..."
    CC=${tools["$arch"]} GOOS=linux GOARCH=$arch go build \
        -trimpath \
        -ldflags "$LDFLAGS" \
        -o $AppPkgName.$arch.$version.linux

    mkdir -p ${DIR}/dist/$AppPkgName.$arch.$version
    cp -rf ${DIR}/scripts/* ${DIR}/dist/$AppPkgName.$arch.$version
    mv $AppPkgName.$arch.$version.linux ${DIR}/dist/$AppPkgName.$arch.$version
    cd ${DIR}/dist/$AppPkgName.$arch.$version
    ln -sf $AppPkgName.$arch.$version.linux $AppPkgName
    chmod a+x *.sh
    cd ${DIR}/dist
    tar -czf $DIR/../dist/${AppPkgName}_linux_${arch}.tar.gz $AppPkgName.$arch.$version
    cd $DIR
    rm -rf ${DIR}/dist
done

cd $DIR
if [ "$BUILD_TYPE" == "release" ]; then
    tools=([amd64]="x86_64-w64-mingw32-gcc" [386]="i686-w64-mingw32-gcc")
    for arch in amd64 386; do
        if [ "windows" != "$BUILD_DEST_OS" ] && [ "" != "$BUILD_DEST_OS" ]; then
            continue
        fi
        if [ "$arch" != "$BUILD_DEST_ARCH" ] && [ "" != "$BUILD_DEST_ARCH" ]; then
            continue
        fi
        if [ -z "${tools[$arch]}" ]; then
            continue
        fi
        gcc_path=$(which ${tools["$arch"]})
        if [ $? -ne 0 ]; then
            echo "未找到 $arch 交叉编译工具 ${tools["$arch"]}"
            continue
        fi
        echo "Building for windows $arch use ${tools["$arch"]}..."
        CC=${tools["$arch"]} GOOS=windows GOARCH=$arch go build \
            -trimpath \
            -ldflags "$LDFLAGS" \
            -o $AppPkgName.$arch.exe
        zip -r ${DIR}/../dist/${AppPkgName}_windows_${arch}.zip -9 $AppPkgName.$arch.exe
        rm $AppPkgName.$arch.exe
    done
fi
