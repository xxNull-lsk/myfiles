#!/bin/bash
CURR=$(pwd)
BUILD_TYPE=$1
BUILD_DEST=$2

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
# 处理版本号，将版本号写入到pubspec.yaml文件中
sed -i "s/^version:.*/version: $version/g" pubspec.yaml

# iconfont_convert --config iconfont.yaml

if [ "$BUILD_DEST" == "apk" ] || [ "$BUILD_DEST" == "" ]; then
    # 解决open_file_android插件问题，选择后会记住，如果选择错了，无法修改。
    files=`find $HOME/.pub-cache/hosted/pub.flutter-io.cn/ -name OpenFilePlugin.java`
    for f in $files; do
        if [ -f $f.fileclient.bak ]; then
            continue
        fi
        cp -f $f $f.fileclient.bak
        patch $f < $CURR/hook/openfile.patch
    done
    cd $CURR
    flutter build apk --release -v
    cp build/app/outputs/flutter-apk/app-release.apk ../dist/myfileclient.apk
    [ "$BUILD_DEST" == "apk" ] && exit 0
fi

if [ "$BUILD_DEST" == "deb" ] || [ "$BUILD_DEST" == "" ]; then
    cd $CURR
    flutter build linux --release -v
    cd build/linux/x64/release/bundle/
    cp $CURR/cfg.json .
    tar -czf $CURR/../dist/myfileclient_linux_x64.tar.gz *

    cd $CURR
    mkdir -p ./deb/opt/myfileclient >/dev/null 2>&1
    cp -rf build/linux/x64/release/bundle/* ./deb/opt/myfileclient/
    sed -i "s/^Version:.*/Version:${version}/g" ./deb/DEBIAN/control
    dpkg-deb --build deb $CURR/../dist/myfileclient_linux_x64.deb
    rm -rf deb/opt/myfileclient/*
    sed -i "s/^Version:.*/Version:0.0.0/g" ./deb/DEBIAN/control
    [ "$BUILD_DEST" == "deb" ] && exit 0
fi

if [ "$BUILD_DEST" == "web" ] || [ "$BUILD_DEST" == "" ]; then
    cd $CURR
    flutter build web -v --release --base-href=/front/ --no-web-resources-cdn
    rm -rf ../server/front
    mkdir -p ../server/front >/dev/null 2>&1
    cp -rf build/web/* ../server/front/
    [ "$BUILD_DEST" == "web" ] && exit 0
fi
exit 0
