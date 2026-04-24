#!/bin/bash
if /usr/bin/nmcli radio wifi | grep -q enabled; then
    /usr/bin/nmcli radio wifi off
else
    /usr/bin/nmcli radio wifi on
fi
