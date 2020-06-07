#!/usr/bin/env sh
#
# Configures a new monitor with "1920x1080_60.00" as preferred mode (X11).
#
# Run me with:
#
# $ ./configure-monitors.sh
#
# Alternatively, using xrandr:
#
# $ xrandr --newmode "1920x1080_60.00"  173.00  1920 2048 2248 2576  1080 1083 1088 1120 -hsync +vsync
# $ xrandr --addmode Virtual-1 "1920x1080_60.00"
# $ xrandr -s 1920x1080

config_file="/etc/X11/xorg.conf.d/10-monitor.conf"

if [ ! -f "$config_file" ]; then
  sudo mkdir -p "$(dirname $config_file)"
  cat <<- 'EOF' | sudo tee "$config_file"
Section "Monitor"
    Identifier "Virtual-1"
    Modeline "1920x1080_60.00"  173.00  1920 2048 2248 2576  1080 1083 1088 1120 -hsync +vsync
    Option "PreferredMode" "1920x1080_60.00"
EndSection
EOF
fi
