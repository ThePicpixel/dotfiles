#!/bin/sh
log(){
    echo "$(date) [+] $1" | tee -a ~/installation.log
}

warning(){
    echo "$(date) [!] $1" | tee -a ~/installation.log
}

alias install="sudo zypper in -y"
alias upgrade="sudo zypper dup"

log "Starting installation $(date)"

log "Updating system"
upgrade

log "Installing wayland graphical environment"
install\
    rofi thunar sway  swaybg evince brightnessctl swaylock lxsession lxappearance\
    alacritty i3status Mesa-dri

# Uncomment to install X server
#log "Installing X.org graphical environment"
#install\
#     i3  lxrandr xinit xorg-x11 xorg-x11-server xfce4-screenshooter xfce4-power-manager 

log "Installing development tools"
install\
     emacs git zsh podman buildah python3-virtualenv python3-devel go

log "Installing reverse tools"
install\
     gdb glibc-32bit

log "Installing radare2 dependencies"
install\
    gcc gcc patch meson make

log "Installing gef for gdb"
wget -q -O- https://github.com/hugsy/gef/raw/master/scripts/gef.sh | sh

log "Installing theme assets"
install\
     qt5ct elementary-icon-theme breeze5-cursors elementary-wallpapers

log "Installing usefull stuff"
install\
    chromium keepassxc telegram-desktop wget htop\
    yubioath-desktop nextcloud-client NetworkManager-connection-editor

log "Installing video codecs"
install opi
opi codecs

log "Installing auio"
install pavucontrol
install pulseaudio

log "Installing fonts"
install -t pattern fonts
install alee-fonts

log "Setting up powertop"
sudo systemctl enable powertop
sudo systemctl start powertop

log "Setting up dotfiles"
mkdir ~/Documents
mkdir ~/Téléchargements
mkdir ~/Images
mkdir ~/Vidéos

cd ~/Documents
git clone http://github.com/ThePicpixel/dotfiles

cp dotfiles/wallpaper.png ~/Images/

rm -rf ~/.emacs*
ln -s ~/Documents/dotfiles/emacs ~/.emacs.d
mkdir ~/.config
rm ~/.config/chromium/Default/Preferences
ln -s ~/Documents/dotfiles/alacritty ~/.config
ln -s ~/Documents/dotfiles/i3status ~/.config
ln -s ~/Documents/dotfiles/rofi ~/.config
ln -s ~/Documents/dotfiles/sway ~/.config
ln -s ~/Documents/dotfiles/sakura ~/.config
ln -s ~/Documents/dotfiles/xorg/.xinitrc ~/.xinitrc
ln -s ~/Documents/dotfiles/git/.gitconfig ~/.gitconfig
ln -s ~/Documents/dotfiles/albert ~/.config

cp ~/Documents/dotfiles/chromium/Preferences ~/.config/chromium/Default

log "Configure subuids and subgid to support rootless podman"
myuser=$USER
sudo usermod --add-subuids 10000-65536 $my_user
sudo usermod --add-subgid 10000-65536 $my_user
log "Installing oh-my-zsh"
sh -c "$(wget https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"
