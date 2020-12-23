#!/usr/bin/env bash
#
# Script to install st.
#
# - Requires ./kickstart-void.sh to work.
#
# Run me with:
#
# $ ./install-st.sh

[ ! -f ./kickstart-void.sh ] && \
  printf "Error: %s cannot be found\n" "./kickstart-void.sh" && \
  exit 1

# shellcheck disable=SC1091
source ./kickstart-void.sh --source-only && install_st
