#!/bin/bash

conf_file = "./files/etc/libinput/local-overrides.quirks"
outdir="/etc/libinput"

sudo mkdir -p ${outdir}
sudo cp ${conf_file} ${outdir}
