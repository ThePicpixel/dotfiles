#!/bin/sh
log(){
    echo "$(date) [+] $1" | tee -a ~/installation.log
}

warning(){
    echo "$(date) [!] $1" | tee -a ~/installation.log
}

alias install="sudo zypper in"
alias upgrade="sudo zypper dup"

log "Starting installation $(date)"

log "Updating system"
upgrade

log "Installing wayland graphical environment"
install\
    rofi thunar sway brightnessctl swaylock lxsession lxappearance\
    alacritty i3status

log "Installing development tools"
install\
     emacs git zsh podman buildah python3-virtualenv python3-devel go

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
install un-fonts ubuntu-fonts

log "Setting up powertop"
sudo systemctl enable powertop
sudo systemctl start powertop

log "Setting up dotfiles"
mkdir ~/Documents
mkdir ~/Downloads
mkdir ~/Pictures
mkdir ~/Vidéos

cd ~/Documents
git clone http://github.com/ThePicpixel/dotfiles --single-branch dev

cp dotfiles/wallpaper.png ~/Pictures/

rm -rf ~/.emacs*
ln -s ~/Documents/dotfiles/emacs ~/.emacs.d

mkdir -p ~/.config/chromium/Default


ln -s ~/Documents/dotfiles/alacritty ~/.config
ln -s ~/Documents/dotfiles/i3status ~/.config
ln -s ~/Documents/dotfiles/rofi ~/.config
ln -s ~/Documents/dotfiles/sway ~/.config
ln -s ~/Documents/dotfiles/git/.gitconfig ~/.gitconfig

cp ~/Documents/dotfiles/chromium/Preferences ~/.config/chromium/Default/Preferences

log "Configure subuids and subgid to support rootless podman"
myuser=$USER
sudo usermod --add-subuids 10000-65536 $my_user
sudo usermod --add-subgid 10000-65536 $my_user

log "Installing oh-my-zsh"
sh -c "$(wget https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"
