#!/bin/bash
#

DEVFILE=/sys/class/leds/chromeos\:\:kbd_backlight/brightness

function get_current_brightness {
    cat $DEVFILE
}

function set_brightness {
    local brightness=$1
    echo $brightness > $DEVFILE
}

function adjust_relative {
    local offset=$1
    let "new = $(get_current_brightness) + $offset"
    echo $new
}

if [[ "$1" =~ ^[0-9]+$ ]]; then
  brightness=$1
elif [[ "$1" =~ ^[-+][0-9]+$ ]]; then
    offset=$1
    brightness=$(adjust_relative $offset)
else
    echo "$0 <brightness>"
    echo "	brightness must be an integer beteween 0 and 100."
    echo "  if brightness is prefixed with - or +, the number will be used as a relative adjustment to the current brightness."
    exit 1
fi

if [ $brightness -lt 0 ]; then
    brightness=0
fi

if [ $brightness -gt 100 ]; then
    brightness=100
fi

set_brightness $brightness

echo "set backlight brightness to $(get_current_brightness)"
