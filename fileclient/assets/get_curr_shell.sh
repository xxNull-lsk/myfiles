#!/bin/bash
SSH_TTY=`stat --format='%y %n' /dev/pts/[0-9]* | sort | tail -n 1|awk '{print $4}'`
for f in `ls /proc`; do
    if [ ! -f "/proc/$f/environ" ]; then
        continue
    fi
    cat /proc/$f/environ 2>/dev/null | grep $SSH_TTY 2>/dev/null
    if [ $? -ne 0 ]; then
        continue
    fi
    SSH_SHELL=`readlink /proc/$f/exe`
    SSH_CWD=`readlink /proc/$f/cwd`
    SSH_PID=$f
    break
done

echo "{"
echo "  \"SSH_TTY\": \"${SSH_TTY}\","
echo "  \"SSH_SHELL\": \"${SSH_SHELL}\","
echo "  \"SSH_PID\": \"${SSH_PID}\","
echo "  \"SSH_CWD\": \"${SSH_CWD}\""
echo "}"
