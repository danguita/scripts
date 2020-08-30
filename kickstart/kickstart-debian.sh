#!/usr/bin/env bash
#
# Script to kickstart my main production machine (Debian version).
#
# Author: David Anguita <david@davidanguita.name>
#
# Run me with:
#
#   ./kickstart-debian.sh

set -e

dotfiles_path="$HOME/workspace/dotfiles"
dwm_download_url="https://dl.suckless.org/dwm"
dwm_tar_name="dwm-6.2.tar.gz"

say() {
  printf "\n[$(date --iso-8601=seconds)] %s\n" "$1"
}

confirm() {
  while true; do
    read -r -p "$1 (y/[n]): " answer
    case $answer in
      [Yy]* ) return 0; break;;
      [Nn]* ) return 1; break;;
      "" ) return 1; break;;
      * ) echo "Please answer yes or no.";;
    esac
  done
}

install_package() {
  sudo apt install --no-install-recommends -y "$@"
}

install_dotfiles() {
  mkdir -p "$dotfiles_path"
  git clone --recurse-submodules https://github.com/danguita/dotfiles.git "$dotfiles_path"
  cd "$dotfiles_path" && make install
}

update_dotfiles() {
  cd "$dotfiles_path" && make update
}

install_dwm() {
  if [ ! -s "$HOME/tmp/$dwm_tar_name" ]; then
    wget $dwm_download_url/$dwm_tar_name -O "$HOME/tmp/$dwm_tar_name"
    mkdir -p "$HOME/tmp/dwm/" && \
      tar xzf "$HOME/tmp/$dwm_tar_name" -C "$HOME/tmp/dwm" --strip-components=1
  fi
  cp "$dotfiles_path/dwm/config.h" "$HOME/tmp/dwm/"
  sudo make -C "$HOME/tmp/dwm" clean install || return
}

main() {
  # 1. Removes comments and blank lines.
  # 2. Adds "contrib" and "non-free" branches.
  # 3. Adds references to "stable" and "sid" repositories (not enabled by default).
  say "Adding extra repositories"
  sudo sed -i.bak -E \
    -e "/(^#|^$)/d" \
    -e "s/(^deb.*)(main$)/\1main contrib non-free/g" \
    /etc/apt/sources.list

  sudo sed -i -E \
    -e "\$a# deb http://deb.debian.org/debian/ stable main contrib non-free" \
    -e "\$a# deb http://deb.debian.org/debian/ unstable main contrib non-free" \
    /etc/apt/sources.list

  # Base packages.
  say "Installing base packages"
  sudo apt update
  sudo apt upgrade -y
  install_package \
    acpi \
    acpid \
    awscli \
    bash \
    bash-completion \
    build-essential \
    curl \
    dbus \
    dbus-x11 \
    dnsutils \
    docker-compose \
    docker.io \
    dunst \
    evince \
    exuberant-ctags \
    firefox-esr \
    firmware-linux \
    fonts-dejavu-core \
    fonts-hack \
    fonts-liberation \
    fonts-noto \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
    fwupd \
    gawk \
    gist \
    git \
    git-gui \
    gnome-keyring \
    gnupg \
    gpaste \
    gpicview \
    gvfs-backends \
    htop \
    j4-dmenu-desktop \
    jq \
    libavcodec-extra \
    libnss-myhostname \
    libx11-dev \
    libxft-dev \
    libxinerama-dev \
    man \
    mpv \
    neovim \
    net-tools \
    network-manager \
    network-manager-openvpn \
    nodejs \
    npm \
    openssh-client \
    openssh-server \
    pavucontrol \
    pcmanfm \
    playerctl \
    plymouth-x11 \
    pulseaudio \
    qalc \
    ranger \
    rsync \
    ruby-dev \
    rxvt-unicode \
    scrot \
    sed \
    sensible-utils \
    shellcheck \
    silversearcher-ag \
    software-properties-common \
    suckless-tools \
    tig \
    tmux \
    w3m \
    w3m-img \
    x11-xserver-utils \
    xbacklight \
    xbindkeys \
    xclip \
    xdg-user-dirs \
    xdg-utils \
    xinit \
    xinput \
    xserver-xorg

  # Firefox from unstable branch.
  if confirm "Firefox (unstable)"; then
    # Uncomment unstable branch.
    sudo sed -i.ff-bak -E \
      "/unstable/s/^#[[:space:]]//g" \
      /etc/apt/sources.list

    # Install firefox.
    sudo apt update && \
      install_package firefox

    # Comment unstable branch.
    sudo sed -i.ff-bak -E \
      "/unstable/s/^/# /g" \
      /etc/apt/sources.list

    sudo apt update
  fi

  # Chromium.
  if confirm "Chromium"; then
    install_package chromium chromium-sandbox
  fi

  # Set default browser.
  /usr/bin/xdg-settings set default-web-browser firefox.desktop || \
    /usr/bin/xdg-settings set default-web-browser firefox-esr.desktop || \
    /usr/bin/xdg-settings set default-web-browser chromium.desktop || \
    true

  # Remote desktop client.
  if confirm "Remote desktop client"; then
    install_package \
      remmina \
      remmina-plugin-vnc \
      remmina-plugin-rdp
  fi

  # Elixir/Erlang development tools.
  if confirm "Elixir/Erlang development tools"; then
    install_package \
      elixir \
      erlang-dialyzer \
      erlang-dev
  fi

  # Flatpak.
  if confirm "Flatpak"; then
    install_package \
      flatpak \
      xdg-desktop-portal \
      xdg-desktop-portal-gtk
          sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

      # Installing apps:
      #
      #   sudo flatpak install -y flathub org.keepassxc.KeePassXC
      #   sudo flatpak install -y flathub org.libreoffice.LibreOffice
      #   sudo flatpak install -y flathub com.visualstudio.code
      #   sudo flatpak install -y flathub com.slack.Slack
      #
      # Sandboxing: Allow access to host filesystem:
      #
      #   sudo flatpak override com.slack.Slack --filesystem=xdg-download
      #   sudo flatpak override org.xonotic.Xonotic --filesystem=~/.xonotic
  fi

  # Add $USER to `docker` group.
  sudo usermod -a -G docker "$USER"

  # Create ~/tmp directory.
  mkdir -p "$HOME/tmp"

  # Intel microcode.
  if confirm "Intel CPU"; then
    install_package intel-microcode
  fi

  # Intel GPU (i915).
  if confirm "Intel GPU (i915)"; then
    say "Installing drivers"
    install_package xserver-xorg-video-intel

    say "Configuring device"
    INTEL_DEVICE_CONF_FILE="/etc/X11/xorg.conf.d/20-intel.conf"
    if [ ! -f "$INTEL_DEVICE_CONF_FILE" ]; then
      cat <<- 'EOF' | sudo tee "$INTEL_DEVICE_CONF_FILE"
Section "Device"
    Identifier  "Intel Graphics"
    Driver      "intel"
    Option      "Backlight"  "intel_backlight"
    Option      "DRI"    "3"
EndSection
EOF
# ^
# SC1040: When using <<-, you can only indent with tabs.
# See https://github.com/koalaman/shellcheck/wiki/SC1040
    fi
  fi

  # AMD microcode.
  if confirm "AMD CPU"; then
    install_package amd-microcode
  fi

  # AMD GPU (amdgpu).
  if confirm "AMD GPU (amdgpu)"; then
    install_package xserver-xorg-video-amdgpu
  fi

  # Intel Wireless card support (iwlwifi).
  if confirm "Intel Wireless drivers"; then
    install_package firmware-iwlwifi
  fi

  # Realtek wired ethernet support.
  if confirm "Realtek drivers"; then
    install_package firmware-realtek
  fi

  # Extra file system: NTFS.
  if confirm "NTFS support"; then
    install_package ntfs-3g
  fi

  # Extra file system: ExFAT.
  if confirm "ExFAT support"; then
    install_package exfat-fuse exfat-utils
  fi

  # Printing tools.
  if confirm "Printing tools"; then
    install_package \
      cups \
      hplip \
      sane \
      simple-scan \
      system-config-printer

    # Add $USER to `lpadmin` group.
    sudo usermod -a -G lpadmin "$USER"
  fi

  # Bluetooth support.
  if confirm "Bluetooth support"; then
    install_package \
      blueman \
      bluez \
      bluez-tools
  fi

  # Clean up packages.
  sudo apt autoclean -y
  sudo apt autoremove -y

  # Create user directories.
  say "Creating user directories"
  mkdir -p "$HOME/.config"

  # Update XDG user dir configuration (Updates ~/.config/user-dirs.dirs).
  /usr/bin/xdg-user-dirs-update || true

  # Create util directories.
  mkdir -p "$HOME/Pictures/screenshots"

  # Install dotfiles.
  if [ -d "$dotfiles_path" ]; then
    if confirm "Dotfiles found. Update?"; then
      say "Updating dotfiles"
      update_dotfiles || return
    fi
  else
    say "Installing dotfiles"
    install_dotfiles || return
  fi

  # dwm (window manager).
  if [ -x "$(command -v dwm)" ]; then
    confirm "dwm found. Update?" && install_dwm
  else
    install_dwm
  fi

  # Finish up.
  say "All done :tada:"
}

if [ "${1}" != "--source-only" ]; then
  main "${@}"
fi
