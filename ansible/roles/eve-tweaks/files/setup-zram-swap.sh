#!/bin/bash

# This script is modified from
# https://chromium.googlesource.com/chromiumos/platform/init/+/factory-3536.B/swap.conf
#
# Original copyright notice:

# Copyright (c) 2012 The Chromium OS Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

SWAP_ENABLE_FILE="/root/.zram-swap"
LOG_TAG="zram-swap"

HIST_MIN=100
HIST_MAX=10000
HIST_BUCKETS=50
HIST_ARGS="$HIST_MIN $HIST_MAX $HIST_BUCKETS"

# Extract second field of MemTotal entry in /proc/meminfo.
# NOTE: this could be done with "read", "case", and a function
# that sets ram=$2, for a savings of about 3ms on an Alex.
ram=$(awk '/MemTotal/ { print $2; }' < /proc/meminfo)
[ "$ram" = "" ] && logger -t "$LOG_TAG" "could not get MemTotal"

# compute fraction of total RAM used for low-mem margin.  The fraction is
# given in bips.  A "bip" or "basis point" is 1/100 of 1%.  This unit is
# typically used in finance and in low-memory margin calculations.
MARGIN_BIPS=520
margin=$(($ram / 1000 * $MARGIN_BIPS / 10000))  # MB

# set the margin
echo $margin > /sys/kernel/mm/chromeos-low_mem/margin
logger -t "$LOG_TAG" "setting low-mem margin to $margin MB"

# Load zram module.  Ignore failure (it could be compiled in the kernel).
modprobe zram || logger -t "$LOG_TAG" "modprobe zram failed (compiled?)"
# Allocate zram (compressed ram disk) for swap.
# Default for uncompressed size is 1.5 of total memory.
# Override with content of .swap_enabled (in Mb).
# Calculations are in Kb to avoid 32 bit overflow.
# For security, only read first few bytes of SWAP_ENABLE_FILE.
if [ -f $SWAP_ENABLE_FILE ]; then
  REQUESTED_SIZE_MB="$(head -c 4 $SWAP_ENABLE_FILE)"
else
  REQUESTED_SIZE_MB=""
fi

if [ -z "$REQUESTED_SIZE_MB" ]; then
  ZRAM_SIZE_KB=$(awk '/MemTotal/ { print $2 * 3 / 2 }' /proc/meminfo)
elif [ "$REQUESTED_SIZE_MB" != 500 -a \
       "$REQUESTED_SIZE_MB" != 1000 -a \
       "$REQUESTED_SIZE_MB" != 2000 -a \
       "$REQUESTED_SIZE_MB" != 3000 -a \
       "$REQUESTED_SIZE_MB" != 4000 -a \
       "$REQUESTED_SIZE_MB" != 4500 -a \
       "$REQUESTED_SIZE_MB" != 6000 ]; then
  logger -t "$LOG_TAG" "invalid value $REQUESTED_SIZE_MB for swap"
  exit 1
else
  ZRAM_SIZE_KB=$(($REQUESTED_SIZE_MB * 1024))
fi

logger -t "$LOG_TAG" "setting zram size to $ZRAM_SIZE_KB Kb"
# Approximate the kilobyte to byte conversion to avoid issues
# with 32-bit signed integer overflow.
echo ${ZRAM_SIZE_KB}000 >/sys/block/zram0/disksize ||
    logger -t "$LOG_TAG" "failed to set zram size"
mkswap /dev/zram0 || logger -t "$LOG_TAG" "mkswap /dev/zram0 failed"

# hack to prevent "device or resource busy"
sleep 0.1

swapon /dev/zram0 || logger -t "$LOG_TAG" "swapon /dev/zram0 failed"
