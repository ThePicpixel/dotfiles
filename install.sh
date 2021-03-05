#!/bin/sh
log(){
    echo "$(date) [+] $1" | tee -a ~/installation.log
}

warning(){
    echo "$(date) [!] $1" | tee -a ~/installation.log
}

alias install="sudo zypper -n in -y"
alias upgrade="sudo zypper -n dup -y"

log "Starting installation $(date)"

log "Updating system"
upgrade

log "Installing wayland graphical environment"
install\
    rofi thunar sway brightnessctl swaylock lxsession lxappearance\
    alacritty i3status

log "Installing development tools"
install\
     git zsh podman buildah python3-virtualenv python3-devel go

log "Installing usefull stuff"
install\
    flatpak NetworkManager-connection-editor

log "Installing flatpak apps"
flatpak --user --if-not-exists remote-add flathub https://flathub.org/repo/flathub.flatpakrepo

flatpak install -y --noninteractive --user flathub org.gnu.emacs
flatpak install -y --noninteractive --user flathub org.chromium.Chromium
flatpak install -y --noninteractive --user flathub org.keepassxc.KeePassXC
flatpak install -y --noninteractive --user flathub org.telegram.desktop
flatpak install -y --noninteractive --user flathub com.nextcloud.desktopclient.nextcloud

ln -s ~/.local/share/flatpak/exports/share/applications ~/.local/share/applications

log "Installing video codecs"
install opi
opi codecs

log "Installing auio"
install pavucontrol
install pulseaudio

log "Installing fonts"
install -t pattern fonts
install ubuntu-fonts

log "Setting up powertop"
sudo systemctl enable powertop
sudo systemctl start powertop

log "Setting up dotfiles"
mkdir ~/Documents
mkdir ~/Downloads
mkdir ~/Pictures
mkdir ~/Videos

cd ~/Documents
git clone http://github.com/ThePicpixel/dotfiles --single-branch --branch dev

cp dotfiles/wallpaper.png ~/Pictures/

rm -rf ~/.emacs*
ln -s ~/Documents/dotfiles/emacs ~/.emacs.d
git clone https://github.com/arcticicestudio/nord-emacs.git ~/.emacs.d/themes

mkdir -p ~/.themes
git clone https://github.com/EliverLara/Nordic.git ~/.themes/Nordic

git clone https://github.com/basigur/papirus-folders.git
mkdir -p ~/.local/share/icons
cp -r papirus-folders/src/*apirus*nordic*folders/ ~/.local/share/icons/
rm -rf papirus-folders

ln -s ~/Documents/dotfiles/alacritty ~/.config
ln -s ~/Documents/dotfiles/i3status ~/.config
ln -s ~/Documents/dotfiles/rofi ~/.config
ln -s ~/Documents/dotfiles/sway ~/.config
ln -s ~/Documents/dotfiles/git/.gitconfig ~/.gitconfig


log "Configure subuids and subgid to support rootless podman"
myuser=$USER
sudo usermod --add-subuids 10000-65536 $my_user
sudo usermod --add-subgid 10000-65536 $my_user

log "Installing oh-my-zsh"
sh -c "$(wget https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"
