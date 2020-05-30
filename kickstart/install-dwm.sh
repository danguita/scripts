#!/usr/bin/env bash
#
# Script to compile dwm from source.
#
# - Requires ./kickstart-void.sh to work.
#
# Run me with:
#
# $ ./install-dwm.sh

source ./kickstart-void.sh --source-only
install_dwm
