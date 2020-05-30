#!/usr/bin/env sh
#
# Script to enable backlight control on Intel graphics card (X11).
#
# Run me with:
#
# $ ./intel-backlight-control.sh

INTEL_DEVICE_CONF_FILE="/etc/X11/xorg.conf.d/20-intel.conf"

if [ ! -f "$INTEL_DEVICE_CONF_FILE" ]; then
cat <<- 'EOF' | sudo tee "$INTEL_DEVICE_CONF_FILE"
Section "Device"
    Identifier  "Intel Graphics"
    Driver      "intel"
    Option      "Backlight"  "intel_backlight"
EndSection
EOF
fi
