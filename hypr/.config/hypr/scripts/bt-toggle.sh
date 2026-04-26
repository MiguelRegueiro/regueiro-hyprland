#!/bin/bash

if /usr/bin/bluetoothctl show | grep -q "Powered: yes"; then
    /usr/bin/bluetoothctl power off
else
    /usr/bin/bluetoothctl power on
fi
