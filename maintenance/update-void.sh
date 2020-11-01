#!/usr/bin/env sh
#
# Run me with:
#
# $ ./update-void.sh

say() {
  printf "\n[$(date --iso-8601=seconds)] %s\n" "$1"
}

say 'Syncing repositories...'
sudo xbps-install -S

say 'Cleaning package cache...'
sudo xbps-remove -yO

say 'Updating packages...'
sudo xbps-install -yu

say 'Removing orphaned packages...'
sudo xbps-remove -yo

say 'Purging old kernels...'
sudo vkpurge rm all

say 'Updating flatpak...'
sudo flatpak -y update

say 'Removing unused flatpak refs...'
sudo flatpak uninstall --unused

say 'Updating firmware...'
fwupdmgr refresh
fwupdmgr update
