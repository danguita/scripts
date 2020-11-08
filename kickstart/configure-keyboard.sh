#!/usr/bin/env sh
#
# Script to have the `hid_apple` module parameters set on boot. See [1] for
# reference.
#
# [1] https://wiki.archlinux.org/index.php/Apple_Keyboard#Function_keys_do_not_work
#
# Run me with:
#
# $ ./configure-keyboard.sh

config_file="/etc/modprobe.d/hid_apple.conf"

if [ ! -f "$config_file" ]; then
  echo "options hid_apple fnmode=2" | sudo tee "$config_file"
fi
