#!/usr/bin/env sh
#
# Script to have the `hid_apple` module parameters set on boot.
#
# Run me with:
#
# $ ./configure-keyboard.sh

config_file="/etc/modprobe.d/hid_apple.conf"

if [ ! -f "$config_file" ]; then
  echo "options hid_apple fnmode=2" | sudo tee "$config_file"
fi
