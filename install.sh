#!/bin/bash

#### install.sh
# Check UID
[ "$(id -u)" -eq 0 ] && echo "error: avoid running autoArch.sh as root/sudo." && exit


# install packages

echo -ne "\n[+] Installing required packages\n"
sudo pacman -S --noconfirm git lsd bat kitty lightdm lightdm-slick-greeter bspwm wmname sxhkd polybar zsh feh picom rofi nano unzip zsh noto-fonts-emoji zsh-syntax-highlighting zsh-autosuggestions wget firefox flameshot neovim gdb gcc xclip open-vm-tools openssh base-devel

# create directories
echo -ne "\n[+] Setting up directories\n"
mkdir $HOME/.config
cp -r configurations/* $HOME/.config/

find $HOME/.config/polybar/ -type f -exec chmod +x {} \; 

mkdir ~/.local/share/fonts
cp -r fonts/* ~/.local/share/fonts
fc-cache -fv

sudo chmod +x ~/.config/sxhkd/sxhkdrc
sudo chmod +x ~/.config/bspwm/bspwmrc
sudo chmod +x ~/.config/polybar/launch.sh
sudo chmod +x ~/.config/bspwm/scripts/bspwm_resize

echo -ne "\n[+] Creating bspwm.desktop for LightDM\n"
sudo mkdir -p /usr/share/xsessions
sudo mkdir -p /usr/share/backgrounds
sudo cp configurations/Wallpapers/greeter-wall.jpg /usr/share/backgrounds/

cat <<EOF | sudo tee /usr/share/xsessions/bspwm.desktop > /dev/null
[Desktop Entry]
Name=bspwm
Comment=Tiling window manager
Exec=bspwm
TryExec=bspwm
Type=Application
DesktopNames=bspwm
EOF

sudo sed -i '/\[Seat:\*\]/a greeter-session=lightdm-slick-greeter\nuser-session=bspwm' /etc/lightdm/lightdm.conf

cat <<EOF | sudo tee /etc/lightdm/slick-greeter.conf > /dev/null
[Greeter]
show-hostname=false
background=/usr/share/backgrounds/greeter-wall.jpg
font-name=HackNerdFont
EOF

echo -ne "\n[✔] Minimal bspwm setup done. Select it from LightDM at login.\n"

echo -ne "\n[+] Installing NvChad"

git clone https://github.com/NvChad/starter ~/.config/nvim && nvim --headless +qa
rm -rf ~/.config/nvim/.git

echo -ne "\n[✔] NvChad installed on nvim" 

echo -ne "\n[+] Enabling LightDM"

sudo systemctl enable lightdm.service
sudo systemctl enable vmtoolsd.service
sudo systemctl enable vmware-vblock-fuse.service
sudo pacman -S --noconfirm gtkmm3

echo -ne "\n[✔] Lightdm enabled"

sh postinstall.sh
