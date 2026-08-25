#!/bin/sh

exec /usr/sbin/mixer -f /dev/mixer0 vol=+2% >/dev/null
