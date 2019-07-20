# Installing "real" linux on a Google Pixelbook

This repo documents the process of replacing ChromeOS on a stock [Google Pixelbook][pixelbook_product_page]
with a "real" linux distribution. It also contains an automated configuration script that will fix things
that are broken in a stock install, like sound, display and keyboard backlights, touchpad sensitivity, etc.

A very nice feature of the method described here is that it **does not require taking the machine apart**!
Previous resources I've come across have instructed people to disassemble their Pixelbook and disconnect
the battery cable to disable the firmware write protect. This method avoids the need for that, although
you will need to spend ~$20 USD on a special USB cable. See the [installation instructions](#installation)
for details.

The automated configuration targets Ubuntu 19.04 (Disco Dingo), although it's likely that the basic techniques
used will work for any distribution. I initially tried using Fedora Workstation 29, but ran into an issue where
the system would crash immediately after resuming from suspend. I assumed this was due to my tweaks, but decided
to give another distro a shot and found Ubuntu worked without issue. As a nice bonus, bluetooth works out of the
box on Ubuntu, whereas Fedora required some fiddling post-install.

## Why

I absolutely love the Pixelbook hardware. The keyboard is better than any laptop keyboard I've ever used,
including the sorely missed pre-butterfly MacBook Pro keyboards. I also really like the 3:2 screen aspect ratio, the 
beautiful chassis and design, etc.

I bought the machine in the first place because I was excited about [Crostini](https://reddit.com/r/crostini), which is
a quite clever means of running linux inside a container (which is itself inside a virtual machine) on ChromeOS.

While I immensely respect what the Chromium team is doing with Crostini, it's just not workable for me as a primary
workstation in its current state. When I discovered that you could install a real UEFI firmware and install "real linux",
I decided to give it a try, and the result was close enough to great that I decided to see if I could take it the rest
of the way there.

## Current Status

Here's what's working at the moment:

| Feature            | Stock Ubuntu         | After modifications                                               |
|--------------------|----------------------|-------------------------------------------------------------------|
| WiFi               | Working              | Working                                                           |
| Bluetooth          | Working              | Working                                                           |
| Touchscreen        | Working              | Working                                                           |
| Suspend            | Working              | Working                                                           |
| Touchpad           | Working, but awkward | Working (tweaked to feel nice)                                    |
| Display backlight  | Always on at 100%    | Adjustable using standard controls                                |
| Sound              | Broken               | Working, [see details](implementation-details.md#audio-support)   |
| Keyboard backlight | Broken               | Working (using helper script to adjust)                           |
| Swap               | Working              | zram swap only [see details](implementation-details#swap-support) |
| Hibernate          | Untested             | Unsupported, [see details](implementation-details.md#hibernation) |


**Known limitations**:

- It seems like dual-boot setups (and possibly other installs that don't use
  full UEFI firmware) [fail to extract files from the recovery
  image](https://github.com/yusefnapora/pixelbook-linux/issues/3).
- Running the install script while booting from an external USB has not been
  verified to work, and might suffer from a similar issue. Please update 
  [this issue](https://github.com/yusefnapora/pixelbook-linux/issues/1) if
  you're able to test it out.
  
Please [open an issue](https://github.com/yusefnapora/pixelbook-linux/issues/new) if you find other problems.


## Installation

There are three main phases involved in getting from a stock Pixelbook to a really nice Ubuntu install:

1. [Flash UEFI firmware](#flashing-uefi-firmware)
2. [Install stock Ubuntu](#installing-stock-ubuntu)
3. [Run the automatic configuration script](#running-the-install-script)

Once the install is complete, you'll probably want to read the [post-install notes](#after-the-install)
to learn about the quirks that were added.

### Requirements

Before you start, you'll need to have the following things to complete the process:

- A [SuzyQable CCD Debugging cable][suzyqable], ~$15 USD + shipping
- A USB-A to USB-C adapter
- 2 USB flash drives with USB-C connectors or adapters. Anything over 2GB should be fine
- A willingness to accept that this is a potentially destructive process that may render your
  expensive Pixelbook inoperable or otherwise busted. See the [scary disclaimer](#disclaimer) below.

### Disclaimer

The process described in this document could cause irreversible damage to your expensive laptop, and
you should prepare yourself mentally and emotionally for that outcome before you begin.

I accept absolutely no responsibility for the consequences of anyone choosing to follow or ignore any
of the instructions in this document, and make no guarantees about the quality or effectiveness of the
software in this repo.

That said, the chances of damage are quite low, and you're (presumably) all adults capable of weighing
your own risk/reward thresholds. If you get into a jam, raise an issue in this repo and I'll try to
help as time allows.


### Flashing UEFI Firmware

To boot operating systems other than ChromeOS, we need to replace the Pixelbook firmware with a more
standard UEFI firmare implementation.

Luckily, the indefatigable [MrChromebox](https://mrchromebox.tech) has developed a full replacement
firmware for many ChromeOS devices, including the Pixelbook.

However, before we can flash the firmware, we need to disable a security feature called Firmware Write Protect.

#### Disabling Write Protect

The Pixelbook (like all ChromeOS devices), ships with the firmware Write Protect setting enabled, which prevents
us from mucking about with the firmware.

The Write Protect setting is enforced by an embedded controller called `cr50`.

There are two ways to disable the Write Protect setting: disassemble the Pixelbook and remove the battery cable,
or buy a special debugging cable for ~$15 USD.

I'm guessing that most people reading this would rather do the latter, so this guide assumes you've already
[bought the cable][suzyqable].

##### Prepare the Pixelbook for closed-case-debugging

Before we can connect our special debug cable, we need to enable Closed Case Debugging (ccd) mode on the
Pixelbook.

First, [enable Developer Mode](https://www.lifewire.com/how-to-enable-chromebook-developer-mode-4173431) on
your Pixelbook.

Once you're running in Developer mode, open a `crosh` shell by pressing `Ctrl+Alt+T` and then type `shell`
at the prompt.

We'll be using the `gsctool` command to "open" the CCD mode.

I made an asciinema cast to walk through opening CCD mode that might be helpful:

[![asciicast](https://asciinema.org/a/241078.svg)](https://asciinema.org/a/241078)

If you'd rather not sit through that, the quick version is:

```bash
# at the crosh shell on the Pixelbook, in developer mode:
gsctool -a --ccd_open
```

This will take several minutes, and you have to sit by the Pixelbook the whole time,
since it will periodically ask you to press the "PP" button, meaning the Pixelbook
power button. Tap the button when asked, and eventually the Pixelbook will abruptly
power down.

**Important:** when the Pixelbook reboots, it will take itself out of Developer Mode!

Once it's done resetting back to normal mode, turn off the machine and reboot while
holding `Esc` and `Refresh` (the key with the circular arrow icon). At the recovery
boot prompt, press `Ctrl-D` to re-enable Developer mode.

When you're back in Developer mode, open a `crosh` shell again and enter:

```bash
gsctool -a --ccd_info
```

In the status report that follows, you should see `State: Open`. This means the Pixelbook
is ready to accept CCD commands using the special cable.

##### Use the CCD cable to connect to the cr50 console

Okay, it's special cable time!

We'll be using the Pixelbook to debug itself, so plug the USB-A end of the cable into
the USB-A to USB-C adapter and plug the adapter into the **right USB-C port** on the
Pixelbook. The USB-C end of the CCD cable must be plugged into the **left USB-C** port.

Now check to see if new `ttyUSB` devices show up in `/dev`:

```bash
ls /dev/tty*
```

**Important Note**: If you don't see any `/dev/ttyUSB` devices showing up when you plug in the
cable, flip the USB-C end of the CCD cable over! Unlike most USB-C cables, the pins on the CCD 
cable **are not bidirectional.**

Now we can send commands to the `cr50` console at `/dev/ttyUSB0`:

```
sudo su -
echo "wp false" > /dev/ttyUSB0
echo "wp false atboot" > /dev/ttyUSB0
echo "ccd set OverrideWP Always" > /dev/ttyUSB0
echo "ccd set FlashAP Always" > /dev/ttyUSB0
```

That will disable write protect, and also change the capabilities to allow overriding the write
protect setting and flashing the firmware even if the CCD is locked. This makes it possible to
recover if anything goes wrong during flashing and makes it easier to restore the original
firmawre.

Once you've issued the commands above, check the status with `gsctool -a -I` - you should see
that the `OverrideWP` and `FlashAP` capabilities have changed from the default of `IfOpened`
to `Always`.

Now run `crossystem wpsw_cur` to verify the current write protect setting.

Alright, now that you've disabled Write Protect, you can flash the firmware!

You won't be needing the CCD cable anymore, so feel free to disconnect it and put it away.

#### Flashing the firmware

We'll be using MrChromebox's [firmware utility script](https://mrchromebox.tech/#fwscript) to flash
the UEFI firmware.

I made an ascii-cast for this as well, if you want to follow along:

[![asciicast](https://asciinema.org/a/241665.svg)](https://asciinema.org/a/241665)

On the Pixelbook, open a `crosh` shell and enter:

```
cd; curl -LO https://mrchromebox.tech/firmware-util.sh && sudo bash firmware-util.sh
```

At the prompt, enter the number for "Install / Update Full ROM Firmware" and follow the
prompts.

**Important:** Make a backup when prompted! This is why the requirements section told you to get
2 USB flash drives. Seriously, USB drives are dirt cheap; don't skip this step.

After a couple minutes, you should be all set! Say goodbye to ChromeOS; by flashing this firmware
you lose the ability to boot into ChromeOS, and you'll need to restore your firmware from the
backup if you want to go back.

### Installing stock Ubuntu

Now that you're running a standard UEFI firmware, installing Ubuntu works just like on a standard
laptop.

Download an ISO image for [Ubuntu Desktop 19.04][ubuntu_dl] - other versions might work, but I make absolutely
no guarantees, and I won't be able to help you out if things are broken. Note that I might not be
able to help regardless, but if you run into issues and you're not running the same distro as me,
chances are much higher I'll shrug my shoulders and ineffectually wish you good luck, rather than
offering any useful help.

Write the image to disk using whatever method seems best - this is pretty Google-friendly & depends
on your setup, so I'll let you figure this bit out.

Now attach the drive to your Pixelbook and boot.

You may need to press `Esc` when booting to bring up the UEFI menu. From there, select "Boot Manager"
and choose the USB device as the boot target.

You should now boot into the Ubuntu installer.

**Note:** due to wonky touchpad support in the default Ubuntu kernel, the touchpad might not work
unless you wiggle the cursor when the system is booting. If your mouse cursor isn't working in the
installer (or in the stock Ubuntu install afterward), try rebooting and continuously moving your
finger around on the trackpad while the system starts.

Now you can go ahead and install Ubuntu using the standard method. The installer defaults should all
work fine, although I recommend encrypting your disk, or at least enabling LVM for volume management.

Note that you'll have to erase the entire Pixelbook disk; since we can't boot back to ChromeOS anyway,
this is no big loss.

After a little while, you should get a message that your install is complete, and you can remove the USB
drive and reboot. When the system comes back up, you can run my install script to finish the setup.

### Running the install script

Boot into your new fresh Ubuntu install and log in.

Open a terminal and run the following to install some bare-minimum requirements:

```bash
sudo apt install -y git python ansible

# replace the values below with your info!
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

Now clone this repository:

```bash
git clone https://github.com/yusefnapora/pixelbook-linux
```

Enter the `pixelbook-linux` directory and run the install script:

```bash
cd pixelbook-linux
sudo mkdir /etc/libinput/
./run-ansible.sh
```

The script will ask you a couple of questions, after which it will spend ~20 minutes
downloading and installing stuff. If you don't know how to answer the questions, just
accept the defaults.

If everything goes well, the script should complete successfully, and you can now
reboot:

```bash
sudo reboot
```

You should NOT boot into the main Ubuntu kernel as it contains none of the drivers just 
compiled into the kernel. By default, the script selects the "Advanced" option submenu.
You should pick the submenu and then the ChromiumOS kernel.

When the system comes back up, you should boot into the ChromiumOS-flavored kernel.
You'll be able to tell that you're using the correct kernel by the display backlight
becoming very dim just after boot. Once the GUI is up, you can adjust the backlight
using the Gnome slider in the upper-right corner.

### After the install

Here's some info about the scripts and other customizations I added. If you're interested
in the details or for more context, see the [implementation details doc](implementation-details.md).

#### Switching audio outputs & inputs

Support for the audio hardware relies on a component called `cras`, short for
the Chromium Audio Server. The install script will build `cras` for vanilla Linux
and add configuration for ALSA and Pulseaudio to make things work, however, there's
no way to switch between headphone and speaker outputs using the standard GUI controls.

To work around this, I wrote a little python script called `eve-audio-ctl.py`
that wraps the `cras_test_client` program that gets built alongside `cras`.

Running the script with no arguments will show some status output:

```bash
$ eve-audio-ctl.py
Output Devices:
	hdmi2
	hdmi1
active:	headphone
	speaker

Input Devices:
	mic
active:	internal_mic
	post_dsp_loopback
	post_mix_pre_dsp_loopback
```

To switch outputs, use `eve-audio-ctl.py -o <output-name>`, e.g. `eve-audio-ctl.py -o speaker`.

Switching inputs works much the same, but with `-i` instead of `-o`: `eve-audio-ctl.py -i internal_mic`

Since it's nice to automatically switch to headphones when they're plugged in, there's also a `-j` flag
that will listen for plug and unplug events. When headphones are plugged in, it will automatically switch
the audio output to the headphones, and when they're removed it will switch to speakers. Likewise, if you
plug in a headset with a microphone, it will switch the input to `mic` and switch back to `internal_mic`
when removed.

The script needs to be running to detect the events, so I also added a systemd service that runs the script
at boot. If you'd rather not have the script running, you can disable it with: `sudo systemctl disable eve-headphone-jack-listener`.

Unfortunately the script isn't smart enough to detect whether the headphones are plugged in when the
system first starts - it can only detect changes, not the current state. So at boot the output will
always default to speakers if you're running the systemd service.

Note that currently the volume won't be changed when you switch devices, so if you're playing audio through
headphones and suddenly switch to speakers, it might be louder than you expect.

#### Keyboard backlight

You can control the brightness of the keyboard backlight by running the `eve-keyboard-brightness.sh` script.

The script can either set the brightness to an absolute value between 1 and 100, e.g.:

```bash
# set brightness to 50%
eve-keyboard-brightness.sh 50

# turn backlight off:
eve-keyboard-brightness.sh 0
```

Or, you can adjust the current brightness by prefixing a number with either `+` or `-`:

```bash
# increase brightness by 10:
eve-keyboard-brightness.sh +10

# decrease by 20:
eve-keyboard-brightness.sh -20
```

The latter form is especially handy when bound to a keyboard shortcut.

#### Remapping keyboard keys

If you decide after the install that you want to change the keyboard mapping,
you can edit `/lib/udev/hwdb.d/61-eve-keyboard.hwdb` as root and change the keycodes
on the right-hand of the equal signs for the keys you want to change.

A list of valid keycodes can be found in [ansible/keycodes.txt](ansible/keycodes.txt).

After changing the file, you'll need to reload your hwdb config:

```bash
sudo udevadm hwdb --update
sudo udevadm trigger
```

#### Cleaning up installation files

The install process will dump some files into `/opt/eve-linux-setup` that
can be safely removed afterward to reclaim ~1.5 GB of space. If you're not interested
in fiddling around with the installer setup, it's a good idea to remove that directory:

```bash
sudo rm -rf /opt/eve-linux-setup
```

Do NOT remove `/opt/google` - it contains some files needed by the audio setup.



[ansible]: https://ansible.com
[pixelbook_product_page]: https://www.google.com/chromebook/device/google-pixelbook/
[suzyqable]: https://www.sparkfun.com/products/14746
[ubuntu_dl]: https://www.ubuntu.com/download/desktop/thank-you?country=US&version=19.04&architecture=amd64
