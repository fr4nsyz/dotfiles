#!/bin/env bash

cd ~/

sudo apt install git i3 polybar stow

sudo apt-get install ninja-build gettext cmake curl build-essential

sudo apt install neovim
LV_BRANCH='release-1.4/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh)

git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

cd ~/dotfiles

stow tmux
stow zsh
stow lvim
stow i3
stow polybar
stow sketchybar

sudo cp ./housekeeping/30-dpms.conf /etc/X11/xorg.conf.d/10-serverflags.conf
echo "HandlePowerKey=ignore" >> /etc/systemd/logind.conf
sudo cp ./nwg-piotr-autotiling.py /usr/bin/autotiling

cd ~/

sudo apt install libconfig-dev libdbus-1-dev libegl-dev libev-dev libgl-dev libepoxy-dev libpcre2-dev libpixman-1-dev libx11-xcb-dev libxcb1-dev libxcb-composite0-dev libxcb-damage0-dev libxcb-glx0-dev libxcb-image0-dev libxcb-present-dev libxcb-randr0-dev libxcb-render0-dev libxcb-render-util0-dev libxcb-shape0-dev libxcb-util-dev libxcb-xfixes0-dev meson ninja-build uthash-dev

git clone https://github.com/yshui/picom.git

cd ~/picom

sudo ninja -C build install

cd ~/

wget https://raw.githubusercontent.com/betterlockscreen/betterlockscreen/main/install.sh -O - -q | bash -s user

sudo apt install autoconf gcc make pkg-config libpam0g-dev libcairo2-dev libfontconfig1-dev libxcb-composite0-dev libev-dev libx11-xcb-dev libxcb-xkb-dev libxcb-xinerama0-dev libxcb-randr0-dev libxcb-image0-dev libxcb-util0-dev libxcb-xrm-dev libxkbcommon-dev libxkbcommon-x11-dev libjpeg-dev

git clone https://github.com/Raymo111/i3lock-color.git
cd i3lock-color

./install-i3lock-color.sh
