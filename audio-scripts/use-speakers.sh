#!/bin/bash


output_id=$(cras_test_client | grep SPEAKER | awk '{print $2;}')

cras_test_client --select_output $output_id
