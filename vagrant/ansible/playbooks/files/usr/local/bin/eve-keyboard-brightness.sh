#!/bin/bash
#


if [[ "$1" =~ ^[0-9]+$ ]]; then
  brightness=$1
else
    echo "$0 <brightness>"
    echo "	brightness must be an integer beteween 0 and 100"
    exit 1
fi

if [ $brightness -lt 0 -o $brightness -gt 100 ]; then
  echo "error: brightness must be between 0 and 100"
  exit 1
fi

DEVFILE=/sys/class/leds/chromeos\:\:kbd_backlight/brightness

echo $brightness > $DEVFILE
