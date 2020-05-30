#!/usr/bin/env sh
#
# Run me with:
#
# $ ./update-debian.sh

say() {
  printf "\n[$(date --iso-8601=seconds)] %s\n" "$1"
}

say 'Syncing repositories...'
sudo apt update

say 'Updating packages...'
sudo apt -y upgrade

say 'Purging old packages...'
sudo apt -y autoclean
sudo apt -y autoremove

say 'Updating flatpak...'
sudo flatpak -y update

say 'Updating firmware...'
fwupdmgr refresh
fwupdmgr update
