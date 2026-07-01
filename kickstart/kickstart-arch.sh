#!/usr/bin/env bash
#
# Script to kickstart my main production machine (Arch Linux).
#
# Author: David Anguita <david@davidanguita.name>
#
# Run me with:
#
# $ ./kickstart-arch.sh

set -e

readonly DOTFILES_PATH="$HOME/workspace/dotfiles"
readonly DOTFILES_REPO_URL="https://github.com/danguita/dotfiles.git"
readonly DWM_REPO_URL="https://github.com/danguita/dwm.git"
readonly SLSTATUS_REPO_URL="https://github.com/danguita/slstatus.git"

say() {
  printf "\n[$(date --iso-8601=seconds)] %s\n" "$1"
}

# shellcheck disable=SC2317
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
  sudo pacman --needed --noconfirm -S "$@"
}

install_flatpak_package() {
  sudo flatpak install -y flathub "$@"
}

clean_packages() {
  sudo paccache -r
}

enable_service() {
  sudo systemctl enable "$1"
}

add_user_to_group() {
  sudo usermod -a -G "$1" "$USER"
}

install_dotfiles() {
  mkdir -p "$DOTFILES_PATH"
  git clone --recurse-submodules "$DOTFILES_REPO_URL" "$DOTFILES_PATH"
  make -C "$DOTFILES_PATH" install
}

update_dotfiles() {
  make -C "$DOTFILES_PATH" update
}

install_dwm() {
  rm -rf "$HOME/tmp/dwm"
  git clone --depth 1 "$DWM_REPO_URL" "$HOME/tmp/dwm"
  sudo make -C "$HOME/tmp/dwm" deploy
}

install_slstatus() {
  rm -rf "$HOME/tmp/slstatus"
  git clone --depth 1 "$SLSTATUS_REPO_URL" "$HOME/tmp/slstatus"
  sudo make -C "$HOME/tmp/slstatus" deploy
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
    pacman-contrib \
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
    xdotool \
    xorg-xrandr \
    xterm \
    xdg-utils xdg-user-dirs xdg-dbus-proxy \
    xbindkeys \
    dbus \
    acpi \
    wget \
    curl \
    sed \
    shellcheck \
    net-tools \
    git lazygit \
    github-cli gist \
    gnupg \
    pulseaudio pavucontrol \
    playerctl \
    ranger \
    w3m \
    linux-firmware \
    fwupd \
    dunst \
    aws-cli \
    vim neovim \
    ctags \
    tmux \
    scrot \
    feh \
    zathura zathura-pdf-mupdf \
    mpv \
    bash-completion \
    the_silver_searcher \
    ttf-dejavu \
    noto-fonts noto-fonts-cjk noto-fonts-emoji \
    terminus-font \
    ttf-liberation \
    firefox \
    adwaita-icon-theme \
    dmenu j4-dmenu-desktop \
    slock \
    pcmanfm-gtk3 \
    gvfs \
    xarchiver \
    htop \
    gawk \
    nodejs npm \
    jq \
    rsync \
    keepassxc \
    rclone \
    libqalculate \
    fzf

  # OpenSSH.
  install_package openssh
  enable_service sshd.service

  # NetworkManager.
  install_package networkmanager networkmanager-openvpn
  enable_service NetworkManager.service

  # Login manager.
  install_package lemurs
  enable_service lemurs.service

  # Chromium.
  install_package chromium

  # yay (AUR helper).
  cd "$HOME/tmp"
  rm -rf yay-bin
  git clone https://aur.archlinux.org/yay-bin.git --depth 1
  cd yay-bin
  makepkg -si --noconfirm
  cd -
  rm -rf yay-bin
  cd ~

  # Docker.
  if confirm "Docker"; then
    install_package docker docker-compose
    enable_service docker.service
    add_user_to_group docker
  fi

  # Set default browser.
  /usr/bin/xdg-settings set default-web-browser chromium.desktop || \
    /usr/bin/xdg-settings set default-web-browser firefox.desktop || \
    true

  # Prefer dark color scheme in gtk applications.
  /usr/bin/dconf write /org/gnome/desktop/interface/color-scheme 'prefer-dark' || true

  # Create user directories.
  /usr/bin/xdg-user-dirs-update || true
  mkdir -p "$HOME/Pictures/screenshots"
  mkdir -p "$HOME/.local/bin"
  mkdir -p "$HOME/.local/state"
  mkdir -p "$HOME/.local/share/fonts"

  # Flatpak.
  #
  # Installing apps:
  #
  # % flatpak install -y flathub com.slack.Slack
  #
  # Sandboxing: Allow access to host filesystem:
  #
  # % flatpak override com.slack.Slack --filesystem=xdg-download
  # % flatpak override org.xonotic.Xonotic --filesystem=~/.xonotic
  if confirm "Flatpak"; then
    install_package flatpak
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi

  if confirm "Flatpak applications"; then
    install_flatpak_package com.discordapp.Discord # Discord
    install_flatpak_package com.getpostman.Postman # Postman
    install_flatpak_package com.slack.Slack        # Slack
    install_flatpak_package com.spotify.Client     # Spotify
    install_flatpak_package us.zoom.Zoom           # Zoom
  fi

  # Intel microcode.
  if confirm "Intel CPU"; then
    install_package intel-ucode
  fi

  # Intel GPU.
  if confirm "Intel GPU"; then
    install_package xf86-video-intel
  fi

  # AMD CPU.
  if confirm "AMD CPU"; then
    install_package amd-ucode
  fi

  # AMD GPU (amdgpu).
  if confirm "AMD GPU (amdgpu)"; then
    install_package xf86-video-amdgpu mesa libva-mesa-driver lib32-mesa vulkan-radeon lib32-vulkan-radeon
  fi

  # NVIDIA GPU (nvidia).
  if confirm "NVIDIA GPU (nvidia)"; then
    install_package nvidia nvidia-dkms
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

    enable_service cups.service
  fi

  # Bluetooth support.
  if confirm "Bluetooth support"; then
    install_package blueman bluez
    enable_service bluetooth.service
  fi

  # Install dotfiles.
  if [ -d "$DOTFILES_PATH" ]; then
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

  # Install slstatus (status monitor).
  if [ -x "$(command -v slstatus)" ]; then
    confirm "slstatus found. Update?" && install_slstatus
  else
    install_slstatus
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
