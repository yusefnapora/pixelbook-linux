# Installing "real" linux on a Google Pixelbook

This repo documents the process of replacing ChromeOs on a stock [Google Pixelbook][pixelbook_product_page]
with a "real" linux distribution.

You can also find an automated installation script that uses [ansible][ansible] to modify a stock installation
of Fedora Workstation 29 on the Pixelbook and enable some functionality that's broken in a fresh install.

If you want to use another distribution, please see the [Implementation Details](#implementation-details** section
to understand how the process works. I believe that it can be easily adapted to any modern distribution, as the
only thing that seems distro-specific is the package manager and set of packages used to install dependencies. 
If anyone has time & motivation to add support for other distributions, please open a pull request in this repo.


## Current Status

| Feature           | Stock Fedora         | After modifications                   |
|-------------------|----------------------|---------------------------------------|
| WiFi              | Working              | Working                               |
| Bluetooth         | Working              | Working                               |
| Sound             | Broken               | Working ([see below](#audio-support)) |
| Touchpad          | Working, but awkward | Working (tweaked to feel nice)        |
| Touchscreen       | Working              | Working                               |
| Display backlight | Broken               | Working (control using script)        |
| Hibernate         | Unknown              | Currently broken :(                   |
    

ansible: https://ansible.io # FIXME: is this right?
pixelbook_product_page: http://fixme.before.merge
