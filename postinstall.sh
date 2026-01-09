#!/bin/bash

echo -ne "\n[+] Fixing .zshrc\n"

cp configurations/zshrc_template ~/.zshrc

echo -ne "\n[+] Instaling starship terminal"

curl -sS https://starship.rs/install.sh | sh
echo 'eval "$(starship init zsh)"' >> ~/.zshrc
cp configurations/starship_template ~/.config/starship.toml

echo -ne "\n[✔] Starship installed" 

# make symlink in root
sudo ln -sf $HOME/.zshrc /root/.zshrc
sudo chsh -s /usr/bin/zsh root 

## blackarch
read -p "Do you want to install the BlackArch repositories?[Y/n]: " choice
choice=${choice:-Y}
if [[ "$choice" == "Y" || "$choice" == "y" ]]; then 
  curl -O https://blackarch.org/strap.sh
  sudo sh strap.sh
  echo -ne "\n[✔] BlackArch Repositories installed"
  echo -ne "\n[+] Installing hacking tools"
  sudo pacman -S --noconfirm jdk-openjdk burpsuite openbsd-netcat hashid hashcat seclists plocate wfuzz gobuster netexec smbclient smbmap certipy nmap ghidra sshpass openvpn
  echo -ne "\n[✔] Hacking Tools installed"
elif [[ "$choice" == "N" || "$choice" == "n" ]]; then
  echo -ne "\n[✖]The Respositories has not been installed"
else
  echo -ne "\n[✖]The Respositories has not been installed"
fi 

# clean
echo -ne "\n[+] Cleaning up...\n "
sudo pacman -Sy archlinux-keyring

echo -ne "\n[+] DONE!\n"
