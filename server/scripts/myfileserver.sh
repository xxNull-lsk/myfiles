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

while [ true ]; do
    $script_dir/myfileserver
    sleep 10
done
