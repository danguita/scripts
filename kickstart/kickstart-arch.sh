#!/usr/bin/env bash
#
# Script to kickstart my main production machine (Arch Linux).
#
# Author: David Anguita <david@davidanguita.name>
#
# Run me with:
#
#   ./kickstart-arch.sh

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
  sudo pacman --needed --noconfirm -Sy "$@"
}

clean_packages() {
  sudo paccache -r
}

add_user_to_group() {
  sudo usermod -a -G "$1" "$USER"
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
  sudo make -C "$HOME/tmp/dwm" clean install
}

main() {
  # Create installation directories.
  say "Creating installation directories"
  mkdir -p "$HOME/tmp"
  mkdir -p "$HOME/.config"

  # Base packages.
  say "Installing base packages"
  sudo pacman --noconfirm -Su # Sync and update.

  install_package \
    base \
    base-devel \
    man \
    xorg-server \
    xorg-xrdb \
    xorg-xsetroot \
    xorg-xset \
    xorg-setxkbmap \
    xorg-xinit \
    xorg-xinput \
    xorg-xbacklight \
    xclip \
    xorg-xrandr \
    xdg-utils xdg-user-dirs xdg-dbus-proxy \
    xbindkeys \
    dbus \
    acpi \
    wget \
    curl \
    sed \
    shellcheck \
    net-tools \
    git \
    gist \
    gnupg \
    gpaste \
    pulseaudio pavucontrol \
    playerctl \
    ranger \
    w3m \
    linux-firmware \
    ipw2100-fw ipw2200-fw \
    fwupd \
    dunst \
    rxvt-unicode \
    aws-cli \
    vim \
    neovim \
    ctags \
    tmux \
    tig \
    scrot \
    vimiv \
    zathura zathura-pdf-mupdf \
    mpv \
    bash-completion \
    the_silver_searcher \
    ttf-dejavu \
    ttf-hack \
    noto-fonts noto-fonts-cjk noto-fonts-emoji \
    ttf-liberation \
    firefox \
    adwaita-icon-theme \
    dmenu \
    slock \
    pcmanfm \
    gvfs \
    xarchiver \
    htop \
    gawk \
    nodejs-lts-dubnium \
    jq \
    rsync \
    keepassxc \
    rclone \
    trayer-srg \
    pacman-contrib

  # From AUR:
  #
  # xbindkeys
  # w3m-img
  # j4-dmenu-desktop

  # OpenSSH.
  install_package openssh

  # NetworkManager.
  install_package networkmanager networkmanager-openvpn

  # Docker.
  if confirm "Docker"; then
    install_package docker docker-compose
    add_user_to_group docker
  fi

  # Ruby.
  if confirm "Ruby dev tools"; then
    install_package ruby
    sudo gem install bundler solargraph
  fi

  # Chromium.
  if confirm "Chromium"; then
    install_package chromium
  fi

  # Set default browser.
  /usr/bin/xdg-settings set default-web-browser firefox.desktop || \
    /usr/bin/xdg-settings set default-web-browser chromium.desktop || \
    true

  # Create user directories.
  /usr/bin/xdg-user-dirs-update || true
  mkdir -p "$HOME/Pictures/screenshots"

  # Flatpak.
  if confirm "Flatpak"; then
    install_package flatpak xdg-desktop-portal xdg-desktop-portal-gtk
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    # Installing apps:
    #
    #   sudo flatpak install -y flathub org.libreoffice.LibreOffice
    #   sudo flatpak install -y flathub com.visualstudio.code
    #   sudo flatpak install -y flathub com.slack.Slack
    #
    # Sandboxing: Allow access to host filesystem:
    #
    #   sudo flatpak override com.slack.Slack --filesystem=xdg-download
    #   sudo flatpak override org.xonotic.Xonotic --filesystem=~/.xonotic
  fi

  # Intel microcode.
  if confirm "Intel CPU"; then
    install_package intel-ucode
  fi

  # Intel GPU.
  if confirm "Intel GPU"; then
    say "Installing drivers"
    install_package xf86-video-intel

    say "Configuring device"
    INTEL_DEVICE_CONF_FILE="/etc/X11/xorg.conf.d/20-intel.conf"
    sudo mkdir -p "$(dirname $INTEL_DEVICE_CONF_FILE)"
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

  # AMD GPU (amdgpu).
  if confirm "AMD GPU (amdgpu)"; then
    install_package xf86-video-amdgpu
  fi

  # Extra file system: NTFS.
  if confirm "NTFS support"; then
    install_package ntfs-3g
  fi

  # Extra file system: ExFAT
  if confirm "ExFAT support"; then
    install_package fuse-exfat exfat-utils
  fi

  # Printing/Scanning tools.
  if confirm "Printing/Scanning tools"; then
    install_package \
      cups \
      hplip \
      sane \
      simple-scan \
      system-config-printer

    add_user_to_group lp
    add_user_to_group scanner

    # Enable hpaio backend.
    echo hpaio | sudo tee -a /etc/sane.d/dll.conf
  fi

  # Bluetooth support.
  if confirm "Bluetooth support"; then
    install_package blueman bluez
  fi

  # Install dotfiles.
  if [ -d "$dotfiles_path" ]; then
    if confirm "Dotfiles found. Update?"; then
      say "Updating dotfiles"
      update_dotfiles
    fi
  else
    say "Installing dotfiles"
    install_dotfiles
  fi

  # Install dwm (window manager).
  if [ -x "$(command -v dwm)" ]; then
    confirm "dwm found. Update?" && install_dwm
  else
    install_dwm
  fi

  # Clean packages.
  say "Cleaning things up"
  clean_packages

  # Finish up.
  say "All done :tada:"
}

if [ "${1}" != "--source-only" ]; then
  main "${@}"
fi
