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

if [ `id -u` != "0" ]; then
    echo "please run as root"
    exit 1
fi

systemctl stop myfileserver.service
systemctl disable myfileserver.service
rm -rf /etc/systemd/system/myfileserver.service
systemctl daemon-reload
rm -rf /wls/myfileserver

if [ "$1" == "full" ]; then
    rm /etc/myfileserver.cfg
    rm -rf /var/lib/myfileserver
fi

echo "uninstall success"
