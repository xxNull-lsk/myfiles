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

if [ -f /wls/myfileserver/uninstall.sh ]; then
    type=$1
    if [ -z "$type" ]; then
        type="update"
    fi
    bash /wls/myfileserver/uninstall.sh $type
fi

mkdir -p /wls/myfileserver

cp * /wls/myfileserver/
chown -R root:root /wls/myfileserver/
chmod +x /wls/myfileserver/myfileserver.sh
chmod +x /wls/myfileserver/myfileserver
cp myfileserver.service /etc/systemd/system/
rm -rf /wls/myfileserver/install.sh
if [ ! -f /etc/myfileserver.cfg ]; then
    mv /wls/myfileserver/myfileserver.cfg.default /etc/myfileserver.cfg
fi
ln -sf /etc/myfileserver.cfg /wls/myfileserver/myfileserver.cfg
if [ ! -d /var/lib/myfileserver ]; then
    mkdir -p /var/lib/myfileserver
fi

chown -R root:root /etc/systemd/system/myfileserver.service
systemctl daemon-reload
systemctl enable myfileserver.service
systemctl start myfileserver.service
echo "install success"

