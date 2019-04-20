#!/bin/bash

#CRASBUILDTMP="`mktemp -d linux-cras.XXXXXX --tmpdir=/tmp`"

filesdir="$PWD/files"
workdir="$PWD/pixelbook-workdir"
outdir=""

pushd $workdir

# install build dependencies
sudo dnf install -y @development-tools libtool libudev-devel sbc-devel alsa-lib-devel iniparser-devel ladspa-devel speex-devel speexdsp-devel

# download cras source
adhd_repo="https://chromium.googlesource.com/chromiumos/third_party/adhd"
ref="master"

git clone ${adhd_repo}
pushd adhd
git checkout ${ref}

# first run of make is expected to fail, but it generates cras/configure
make || true

pushd cras

./configure --disable-dbus --disable-webrtc-apm --with-socketdir=/var/run/cras
make

mkdir -p ${outdir}/usr/local/bin
mkdir -p ${outdir}/usr/local/etc/cras
mkdir -p ${outdir}/usr/lib64/alsa-lib

sudo cp src/cras src/cras_test_client ${outdir}/usr/local/bin

sudo cp src/.libs/libasound_module*.so ${outdir}/usr/lib64/alsa-lib
sudo cp src/.libs/libcras.so.*.* ${outdir}/usr/lib64/
#sudo ldconfig -l ${outdir}/usr/lib64/libcras.so.*.*

#if [[ ! id cras ]]; then
	sudo useradd -M cras
	sudo usermod -aG audio cras
	sudo usermod -aG cras yusef
#fi

# add cras systemd config
mkdir -p ${outdir}/etc/systemd/system
sudo cp ${filesdir}/etc/systemd/system/cras.service ${outdir}/etc/systemd/system/cras.service


# TODO: copy alsa and pulseaudio configs from ./files/etc

popd




popd
