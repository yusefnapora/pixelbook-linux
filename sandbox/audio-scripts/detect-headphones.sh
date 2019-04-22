#!/bin/bash

function get_cras_id {
  local name=$1
  cras_test_client | grep -E "$name" | awk '{print $2}'
}

function set_cras_output {
  local name=$1
  cras_test_client --select_output $(get_cras_id "$name")
}

function set_cras_input {
  local name=$1
  cras_test_client --select_input $(get_cras_id $name)
}

function on_connect_headphones {
	echo headphones connected
     	set_cras_output HEADPHONE
}

function on_disconnect_headphones {
	echo headphones disconnected
  set_cras_output SPEAKER
}

function on_connect_mic {
	echo mic connected
  set_cras_input 'MIC *Mic'
}

function on_disconnect_mic {
	echo mic disconnected
  set_cras_input INTERNAL_MIC
}

acpi_listen | while IFS= read -r line;
do
    if [ "$line" = "jack/headphone HEADPHONE plug" ]
    then
	    on_connect_headphones
    elif [ "$line" = "jack/headphone HEADPHONE unplug" ]
    then
	    on_disconnect_headphones
    elif [ "$line" = "jack/microphone MICROPHONE plug" ]
    then
	    on_connect_mic
    elif [ "$line" = "jack/microphone MICROPHONE unplug" ]
    then
	    on_disconnect_mic
    fi
done
