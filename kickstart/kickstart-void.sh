#!/usr/bin/env bash
#
# Script to kickstart my main production machine (Void Linux).
#
# Author: David Anguita <david@davidanguita.name>
#
# Run me with:
#
# $ ./kickstart-void.sh

set -e

readonly DOTFILES_PATH="$HOME/workspace/dotfiles"
readonly DOTFILES_REPO_URL="https://github.com/danguita/dotfiles.git"

say() {
  printf "\n[$(date --iso-8601=seconds)] %b\n" "$1"
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
  sudo xbps-install -y "$@"
}

clean_packages() {
  sudo xbps-remove -Ooy # Clean cache and remove orphans.
}

enable_service() {
  [ ! -e "/var/service/$1" ] && sudo ln -s "/etc/sv/$1" /var/service/ || return 0
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

main() {
  # Create installation directories.
  say "Creating installation directories"
  mkdir -p "$HOME/tmp"
  mkdir -p "$HOME/.config"

  # Repositories.
  say "Adding nonfree repository"
  install_package void-repo-nonfree

  # Base packages.
  say "Installing base packages"
  sudo xbps-install -Su # Sync and update.

  install_package \
    base-system \
    base-devel \
    xorg-minimal \
    xrdb \
    xsetroot \
    xset \
    setxkbmap \
    xinit \
    xinput \
    xtools \
    acpilight \
    xclip \
    xdotool \
    xrandr \
    xterm \
    xdg-utils xdg-user-dirs xdg-dbus-proxy \
    xdg-desktop-portal xdg-desktop-portal-gtk \
    xurls \
    dbus dbus-x11 \
    elogind \
    polkit \
    cwm \
    acpi \
    tlp \
    wget \
    curl \
    sed \
    shellcheck \
    bind-utils \
    net-tools \
    openntpd \
    git \
    git-gui \
    gist \
    gnupg \
    libX11-devel libXft-devel libXinerama-devel \
    pulseaudio pulsemixer pamixer pavucontrol \
    sof-firmware \
    playerctl \
    ranger \
    w3m w3m-img \
    linux-firmware linux-firmware-network wifi-firmware \
    linux-lts linux-lts-headers \
    linux linux-headers \
    fwupd \
    dunst \
    aws-cli \
    vim vim-x11 \
    ctags \
    tmux \
    tig \
    scrot \
    feh \
    zathura zathura-pdf-mupdf \
    mpv \
    bash-completion \
    the_silver_searcher \
    terminus-font \
    dejavu-fonts-ttf \
    liberation-fonts-ttf \
    noto-fonts-ttf noto-fonts-cjk noto-fonts-emoji \
    firefox \
    adwaita-icon-theme \
    rofi \
    polybar \
    slock \
    pcmanfm \
    gvfs \
    xarchiver \
    htop \
    gawk \
    nodejs \
    jq \
    rsync \
    keepassxc \
    rclone \
    fzf

  # Access to removable storage devices.
  add_user_to_group storage

  # Ability to use KVM for virtual machines, e.g. via QEMU.
  add_user_to_group kvm

  # NTP daemon.
  enable_service ntpd

  # Seat management.
  enable_service dbus
  enable_service elogind
  enable_service polkitd

  # Power management.
  enable_service tlp

  # OpenSSH.
  install_package openssh
  enable_service sshd

  # NetworkManager.
  install_package NetworkManager NetworkManager-openvpn
  enable_service NetworkManager
  add_user_to_group network

  # Docker.
  if confirm "Docker"; then
    install_package docker docker-compose
    enable_service docker
    add_user_to_group docker
  fi

  # Ruby.
  if confirm "Ruby dev tools"; then
    install_package ruby ruby-devel ruby-ri
    sudo gem install bundler solargraph
  fi

  # VirtualBox.
  if confirm "VirtualBox"; then
    install_package virtualbox-ose virtualbox-ose-guest
    add_user_to_group vboxusers
    # Install latest VM VirtualBox Extension Pack
    # latest=$(curl https://download.virtualbox.org/virtualbox/LATEST.TXT)
    # wget https://download.virtualbox.org/virtualbox/$latest/Oracle_VM_VirtualBox_Extension_Pack-$latest.vbox-extpack
    # sudo VBoxManage extpack install --replace ./Oracle_VM_VirtualBox_Extension_Pack-$latest.vbox-extpack
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
  mkdir -p "$HOME/.local/bin"

  # Flatpak.
  #
  # Installing apps:
  #
  # $ sudo flatpak install -y flathub com.slack.Slack
  #
  # Sandboxing: Allow access to host filesystem:
  #
  # $ sudo flatpak override com.slack.Slack --filesystem=xdg-download
  # $ sudo flatpak override org.xonotic.Xonotic --filesystem=~/.xonotic
  if confirm "Flatpak"; then
    install_package flatpak xdg-desktop-portal xdg-desktop-portal-gtk
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi

  # Intel microcode.
  if confirm "Intel CPU"; then
    say "Installing drivers"
    install_package linux-firmware-intel intel-ucode
  fi

  # Intel GPU.
  if confirm "Intel GPU"; then
    say "Installing drivers"
    install_package linux-firmware-intel intel-video-accel mesa-dri
  fi

  # AMD microcode.
  if confirm "AMD CPU"; then
    install_package linux-firmware-amd
  fi

  # AMD GPU (amdgpu).
  if confirm "AMD GPU (amdgpu)"; then
    install_package linux-firmware-amd xf86-video-amdgpu
  fi

  # NVIDIA GPU (nvidia).
  if confirm "NVIDIA GPU (nvidia)"; then
    install_package linux-firmware-nvidia nvidia nvidia-dkms
  fi

  # Extra file system: NTFS.
  if confirm "NTFS support"; then
    install_package ntfs-3g
  fi

  # Extra file system: ExFAT.
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

    enable_service cupsd
    add_user_to_group lpadmin
    add_user_to_group lp
    add_user_to_group scanner

    # Enable hpaio backend.
    echo hpaio | sudo tee -a /etc/sane.d/dll.conf
  fi

  # Bluetooth support.
  if confirm "Bluetooth support"; then
    install_package blueman bluez
    enable_service bluetoothd
    add_user_to_group bluetooth
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

  # Clean packages.
  say "Cleaning things up"
  clean_packages

  # Finish up.
  say "All done :tada:"
}

if [ "${1}" != "--source-only" ]; then
  main "${@}"
fi
