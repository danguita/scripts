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

dotfiles_path="$HOME/workspace/dotfiles"
dotfiles_repo_url="https://github.com/danguita/dotfiles.git"
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
  mkdir -p "$dotfiles_path"
  git clone --recurse-submodules "$dotfiles_repo_url" "$dotfiles_path"
  make -C "$dotfiles_path" install
}

update_dotfiles() {
  make -C "$dotfiles_path" update
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
    xbacklight \
    xclip \
    xbindkeys \
    xrandr \
    xdg-utils xdg-user-dirs xdg-dbus-proxy \
    dbus dbus-x11 \
    elogind \
    polkit \
    acpi \
    wget \
    curl \
    sed \
    shellcheck \
    net-tools \
    git \
    git-gui \
    gist \
    gnupg \
    GPaste \
    libX11-devel libXft-devel libXinerama-devel \
    pulseaudio pavucontrol \
    playerctl \
    ranger \
    w3m w3m-img \
    linux5.6 linux5.6-headers \
    linux-firmware-network wifi-firmware \
    fwupd \
    dunst \
    rxvt-unicode \
    aws-cli \
    vim neovim \
    ctags \
    tmux \
    tig \
    scrot \
    feh \
    zathura zathura-pdf-mupdf \
    mpv \
    bash-completion \
    the_silver_searcher \
    dejavu-fonts-ttf \
    font-hack-ttf \
    noto-fonts-ttf noto-fonts-cjk noto-fonts-emoji \
    font-symbola \
    liberation-fonts-ttf \
    firefox \
    adwaita-icon-theme \
    dmenu j4-dmenu-desktop \
    slock \
    pcmanfm \
    gvfs \
    xarchiver \
    htop \
    gawk \
    nodejs-lts-10 \
    jq \
    rsync \
    keepassxc \
    rclone \
    trayer-srg

  # Access to removable storage devices.
  add_user_to_group storage

  # Ability to use KVM for virtual machines, e.g. via QEMU.
  add_user_to_group kvm

  # Seat management.
  enable_service dbus
  enable_service polkitd
  enable_service elogind

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
    install_package ruby ruby-devel
    sudo gem install bundler solargraph
  fi

  # VirtualBox.
  if confirm "VirtualBox"; then
    install_package virtualbox-ose
    add_user_to_group vboxusers
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
    install_package linux-firmware-intel xf86-video-intel

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
