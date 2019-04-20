#!/bin/bash

workdir="./pixelbook-workdir"
kernel_branch="release-R72-11316.B-chromeos-4.4"

mkdir -p ${workdir}

cd ${workdir}

git clone https://github.com/megabytefisher/eve-linux-hacks

git clone --depth=1 -b ${kernel_branch} https://chromium.googlesource.com/chromiumos/third_party/kernel

cp eve-linux-hacks/eve-custom.config kernel/.config

cd kernel

make oldconfig
make -j15
make -j15 modules
sudo make modules_install
sudo make install

# update grub config
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
