#!/bin/bash

workdir="./pixelbook-workdir"
outdir=""

cd ${workdir}

mkdir -p ${outdir}

# download and unzip eve recovery image
#wget https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_11021.81.0_eve_recovery_stable-channel_mp.bin.zip

#unzip chromeos_11021.81.0_eve_recovery_stable-channel_mp.bin.zip

# map the partitions to loopback devices
#sudo kpartx -av chromeos_11021.81.0_eve_recovery_stable-channel_mp.bin

# mount point for recovery image
#mkdir -p mnt

# mount the image on loop0p3
#sudo mount -t ext2 /dev/mapper/loop0p3 -o ro ./mnt

# copy all firmware files 
mkdir -p ${outdir}/lib/firmware
rsync -av ./mnt/lib/firmware/ ${outdir}/lib/firmware/

# also copy over /opt/google, since some things in /lib/firmware are symlinks to it
mkdir -p ${outdir}/opt/google
rsync -av ./mnt/opt/google/touch ${outdir}/opt/google
rsync -av ./mnt/opt/google/disk ${outdir}/opt/google
rsync -av ./mnt/opt/google/kbl-rt5514-hotword-support ${outdir}/opt/google
rsync -av ./mnt/opt/google/dsm ${outdir}/opt/google


# copy the alsaucm config for eve's soundcard
mkdir -p ${outdir}/usr/share/alsa/ucm
rsync -av ./mnt/usr/share/alsa/ucm/kbl_r5514_5663_max ${outdir}/usr/share/alsa/ucm

# copy the cras config
mkdir -p ${outdir}/usr/local/etc
rsync -av ./mnt/etc/cras ${outdir}/usr/local/etc
