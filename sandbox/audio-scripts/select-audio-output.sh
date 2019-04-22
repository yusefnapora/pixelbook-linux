#!/bin/bash

devicename=$1

if [[ "$devicename" == "" ]]; then
	echo "usage $0 <device-name>"
	exit 1
fi

device_id=$(cras_test_client | grep "$devicename" | awk '{print $2}')

echo $device_id
