#!/bin/bash

function set_output_id {
  cras_test_client --select_output $1
}

function set_input_id {
  cras_test_client --select_input $1
}

function get_cras_id {
  local name=$1
  cras_test_client | grep -E "$name" | awk '{print $2}'
}

function get_headphones_id {
  get_cras_id HEADPHONE
}

function get_speaker_id {
  get_cras_id SPEAKER
}

function get_hdmi1_id {
  get_cras_id HDMI1
}

function get_hdmi2_id {
  get_cras_id HDMI2
}

function get_headset_mic_id {
  get_cras_id 'MIC *Mic'
}

function get_internal_mic_id {
  get_cras_id INTERNAL_MIC
}

function is_active {
  local pattern=$1
  cras_test_client | grep '\*'"$pattern" > /dev/null
}

function active_output {
  if is_active 'Headphone'; then
    echo headphones
    return
  elif is_active 'Speaker'; then
    echo speakers
    return
  elif is_active 'HDMI1'; then
    echo hdmi1
    return
  elif is_active 'HDMI2'; then
    echo hdmi2
    return
  else
    echo unknown
  fi
}

function active_input {
  if is_active 'Mic'; then
    echo headset
    return
  elif is_active 'Internal Mic'; then
    echo internal
    return
  else
    echo unknown
  fi
}

function set_cras_output {
  local name=$1
  case "$name" in
	headphones)
		set_output_id $(get_headphones_id)
		;;
	speakers)
		set_output_id $(get_speaker_id)
		;;
	hdmi1)
		set_output_id $(get_hdmi1_id)
		;;
	hdmi2)
		set_output_id $(get_hdmi2_id)
		;;
	*)
		echo "unknown output $name - valid options are: headphones | speakers | hdmi1 | hdmi2"
		return
		;;
      	esac
	echo "set output to $name"
}

function set_cras_input {
  local name=$1
  case "$name" in
	headset)
		set_input_id $(get_headset_mic_id)
		;;
	internal)
		set_input_id $(get_internal_mic_id)
		;;
	*)
		echo "unknown input $name - valid options are: headset | internal"
		return
		;;
  esac
  echo "set input to $name"
}

function on_connect_headphones {
  echo headphones connected
  set_cras_output headphones 
}

function on_disconnect_headphones {
  echo headphones disconnected
  set_cras_output speakers
}

function on_connect_mic {
  echo mic connected
  set_cras_input headset
}

function on_disconnect_mic {
  echo mic disconnected
  set_cras_input internal
}

function jack_listen {
  echo "listening for headset plug/unplug events"

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
}

function print_active {
  echo "active input device: $(active_input)"
  echo "active output device: $(active_output)"
}

function usage {
  echo "usage: $0 [-o <speakers|heaphones|hdmi1|hdmi2>] [-i <headset|internal>] [-l]"
  echo "options:"
  echo "	-o: set preferred output device"
  echo "	-i: set preferred input device"
  echo "	-l: listen for headphone/mic jack plug events and set input/output device on changes"
}

while getopts ":i:o:lh" opt; do
  case ${opt} in
    i )
      input_target=$OPTARG
      ;;
    o )
      output_target=$OPTARG
      ;;
    l )
      listen_for_jack="true"
      ;;
    h )
      show_usage="true"
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      ;;
  esac
done
shift $((OPTIND -1))

if [[ "$show_usage" == "true" ]]; then
	usage
	exit 0
fi

print_active

if [[ "$input_target" != "" ]]; then
  set_cras_input $input_target
fi

if [[ "$output_target" != "" ]]; then
  set_cras_output $output_target
fi

if [[ "$listen_for_jack" == "true" ]]; then
  jack_listen
fi
