# 💤 Edifier QR30 Timeout + Simple LED Animation

Automatically dims, and animates the **LED brightness** of the **Edifier QR30** (VID `2d99`, PID `a101`) speaker or keyboard, depending on user idle time and volume changes with smooth brightness transitions.

This project includes:
- A **bash script** for LED animations and brightness control.
- A **systemd user service** to auto-start the animation on login.
- A **udev rule** to set proper permissions for the HID device.

---

## 🗂 Files Overview

### `QR30_timeout-_simple_animation.sh`
The main script.  
It monitors **user idle time** (using `wprintidle`) and **volume changes** (via `wpctl`) to animate LED brightness on your Edifier QR30.

#### Features:
- ✅ Dims the LEDs after a set idle time  
- ✅ Restores brightness on user activity  
- ✅ Animates LEDs when changing system volume (up/down)  
- ✅ Automatically detects the correct `/dev/hidrawX` device by VID, PID, and interface number  
- ✅ Customizable animation speeds and brightness levels  

> The script communicates directly with the device using HID raw writes, sending pre-built brightness packets.

Animations can be customized for:
- Going idle
- Becoming active
- Volume up/down events

### `QR30-timeout.service`
A systemd user service that launches the animation script automatically after login. (edit the path to fit your needs)

### `99-edifier.rules`
Udev rules to set the permission needed to talk to the speaker directly. 

## BUG
The speaker has a firmware bug that triggers a reboot when connected to Linux. An upstream patch is currently in development.

As a temporary workaround, add `usbhid.quirks=0x2d99:0xa101:0x400` to your kernel command line.

## Simple video where I show the sycronization and use idle wrong because I was excited. It's in portuguese so...

[![Watch the video](https://img.youtube.com/vi/k4Ag1TyBJ8g/maxresdefault.jpg)](https://youtu.be/k4Ag1TyBJ8g)
