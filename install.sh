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
    alacritty i3status greetd greetd-branding-upstream tuigreet

log "Installing development tools"
install\
     git zsh podman buildah python3-virtualenv python3-devel go

log "Installing virtual environment"
install \
	libvirt qemu virt-manager libvirt-daemon-driver-qemu qemu-kvm

log "Installing usefull stuff"
install\
    flatpak NetworkManager-connection-editor htop emacs chromium keepassxc nextcloud-desktop telegram-desktop

#log "Installing flatpak apps"
#flatpak --user --if-not-exists remote-add flathub https://flathub.org/repo/flathub.flatpakrepo

#flatpak install -y --noninteractive --user flathub org.gnu.emacs
#flatpak install -y --noninteractive --user flathub org.chromium.Chromium
#flatpak install -y --noninteractive --user flathub org.keepassxc.KeePassXC
#flatpak install -y --noninteractive --user flathub org.telegram.desktop
#flatpak install -y --noninteractive --user flathub com.nextcloud.desktopclient.nextcloud

#ln -s ~/.local/share/flatpak/exports/share/applications ~/.local/share/applications

log "Installing video codecs"
install opi
opi codecs

log "Installing audio"
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
git clone http://github.com/ThePicpixel/dotfiles

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

mkdir -p ~/.config
ln -s ~/Documents/dotfiles/alacritty ~/.config
ln -s ~/Documents/dotfiles/i3status ~/.config
ln -s ~/Documents/dotfiles/rofi ~/.config
ln -s ~/Documents/dotfiles/sway ~/.config
ln -s ~/Documents/dotfiles/git/.gitconfig ~/.gitconfig
ln -s ~/Documents/dotfiles/zsh/.zshrc ~/.zshrc

log "Configuring greetd session manager"
if ! id greeter >/dev/null 2>&1; then
    log "Creating greeter system user for greetd"
    sudo useradd -M -G video -s /usr/sbin/nologin greeter
fi
sudo mkdir -p /etc/greetd
sudo cp ~/Documents/dotfiles/greetd/config.toml /etc/greetd/config.toml
log "Seeding default keyboard layout state"
if [ ! -f ~/Documents/dotfiles/sway/kb-layout.conf ]; then
    echo "input type:keyboard xkb_layout fr" > ~/Documents/dotfiles/sway/kb-layout.conf
fi
sudo systemctl set-default graphical.target
sudo systemctl enable greetd

if systemctl is-enabled display-manager.service >/dev/null 2>&1; then
    log "Disabling existing display manager in favor of greetd"
    sudo systemctl disable --now display-manager.service
fi

log "Configure subuids and subgid to support rootless podman"
myuser=$USER
sudo usermod --add-subuids 10000-65536 $myuser
sudo usermod --add-subgid 10000-65536 $myuser

log "Installing oh-my-zsh"
sh -c "$(wget https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"
