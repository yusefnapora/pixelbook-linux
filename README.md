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

Because [fuck Apple](https://www.wsj.com/graphics/apple-still-hasnt-fixed-its-macbook-keyboard-problem/), that's why.

More seriously, I absolutely love the Pixelbook hardware. The keyboard is better than any laptop keyboard I've ever used,
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
- 2 USB flash drives with USB-C connectors or adapters. Anything over 2GB should be fine
- A Linux machine, or a Windows PC that can run Linux from a USB drive.
  - This is required for disabling write protect. Note that the process requires that the second
    machine run Linux and will not work from macOS or Windows.
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
[bought the cable][suzyqable] and have a spare Linux machine nearby to run the debug commands. If you only
have access to a Windows machine, you can boot from the same Ubuntu live installation USB drive that you'll
be using later to [install Ubuntu](#installing-stock-ubuntu).

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

Immediately after the reboot, shut down the Pixelbook, then boot it again holding `Ctrl-R`.
It will start in recovery mode, and you can press `Ctrl-D` to re-enable Developer Mode.

When you're back in Developer mode, open a `crosh` shell again and enter:

```bash
gsctool -a --ccd_info
```

In the status report that follows, you should see `State: Open`. This means the Pixelbook
is ready to accept CCD commands using the special cable.

##### Use the CCD cable to connect to the cr50 console

Okay, it's special cable time!

While the Pixelbook is running, take the CCD debug cable and connect the USB-C end to the 
**left USB-C port** on the Pixelbook. The right port **will not work!**.

Take the other end of the cable and attach it to your Linux machine. You should see some new
`ttyUSB` devices in `/dev`, e.g. `/dev/ttyUSB0`, `/dev/ttyUSB1`, etc.

**Important Note**: If you don't see the `/dev/ttyUSB` devices showing up when you plug in the
cable, flip the USB-C connector that's plugged into the Pixelbook over! Unlike most USB-C cables,
the pins on the CCD cable **are not bidirectional.**

Make sure the `minicom` command is installed on your Linux machine. For Ubuntu:

```bash
sudo apt install -y python3-serial
```

Now you can use `minicom` to connect to `/dev/ttyUSB0`, which should be the `cr50` serial console:

```bash
minicom /dev/ttyUSB0
```

Type `help` at the prompt. One of the commands listed should be called `wp`; if it's missing, try
connecting to one of the other serial consoles (`ttyUSB1` or `ttyUSB2`) instead.

Now we can disable write protect by entering:

```
wp false
wp false atboot
```

The first command will disable write protect, but it will come back on reboot unless you enter the
second command as well. 

We also want to change some of the CCD capabilities, so that if flashing the firmware fails, we can
recover without needing to open the CCD again:

```
ccd set OverrideWP Always
ccd set FlashAP Always
```


Alright, now that you've disabled Write Protect, you can flash the firmware!

You won't be needing the CCD cable anymore, so feel free to disconnect it and put away the Linux
machine you used for the unlocking process.

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

When the system comes back up, you should boot into the ChromiumOS-flavored kernel.
You'll be able to tell that you're using the correct kernel by the display backlight
becoming very dim just after boot. Once the GUI is up, you can adjust the backlight
using the Gnome slider in the upper-right corner.

### After the install

Coming soon: description of the quirks and helper scripts that were installed.

For now, read through the [implementation details](implementation-details.md).

Note that the install process will dump some files into `/opt/eve-linux-setup` that
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
