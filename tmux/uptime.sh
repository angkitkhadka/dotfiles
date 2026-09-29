#!/bin/sh

# get uptime in seconds
if [ -r /proc/uptime ]; then
  # Linux and WSL2
  s=$(cut -d. -f1 /proc/uptime)
else
  # macOS: current time minus boot time
  boot=$(sysctl -n kern.boottime | sed 's/.*{ sec = \([0-9]*\).*/\1/')
  s=$(($(date +%s) - boot))
fi

# convert to days and hours
d=$((s / 86400))
h=$((s % 86400 / 3600))

# print the result
if [ "$d" -gt 0 ] && [ "$h" -gt 0 ]; then
  echo "${d}d ${h}h"
elif [ "$d" -gt 0 ]; then
  echo "${d}d"
else
  echo "${h}h"
fi
