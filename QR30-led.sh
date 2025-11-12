#!/bin/sh
# qr30-led.sh
# Usage: qr30-led.sh off|on

find_qr30_hidraw() {
    for dev in /dev/hidraw*; do
        [ -e "$dev" ] || continue
        udev=$(/sbin/udevadm info -q property -n "$dev")
        VID=$(echo "$udev" | grep ^ID_VENDOR_ID= | cut -d= -f2)
        PID=$(echo "$udev" | grep ^ID_MODEL_ID= | cut -d= -f2)
        IFACE=$(echo "$udev" | grep ^ID_USB_INTERFACE_NUM= | cut -d= -f2)
        if [ "$VID" = "2d99" ] && [ "$PID" = "a101" ] && [ "$IFACE" = "03" ]; then
            echo "$dev"
            return
        fi
    done
}

static="2eaaec6b00070d0200000028ff3e000000000000000000000000000000000000"
gliter="2eaaec6b00070d0b02000028ff49000000000000000000000000000000000000"

case "$1" in
  off)
    touch /tmp/qr30-sleep.lock
    dev=$(find_qr30_hidraw)
    [ -n "$dev" ] && echo "$static" | /usr/bin/xxd -r -p | /bin/dd bs=64 count=1 conv=sync of="$dev"
    ;;
  on)
    rm -f /tmp/qr30-sleep.lock
    dev=$(find_qr30_hidraw)
    [ -n "$dev" ] && echo "$gliter" | /usr/bin/xxd -r -p | /bin/dd bs=64 count=1 conv=sync of="$dev"
    ;;
esac
