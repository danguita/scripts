#!/usr/bin/env bash
#
# Script to configure intel graphics in X11 server.
#
# - Requires ./kickstart-void.sh to work.
#
# Run me with:
#
# $ ./configure-intel-graphics.sh

[ ! -f ./kickstart-void.sh ] && \
  printf "Error: %s cannot be found\n" "./kickstart-void.sh" && \
  exit 1

# shellcheck disable=SC1091
source ./kickstart-void.sh --source-only && configure_intel_graphics
