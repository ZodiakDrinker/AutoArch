# AutoArch

Automated Arch Linux installation for virtual machines, built on top of
[`archinstall`](https://wiki.archlinux.org/title/Archinstall). A single JSON
configuration installs the system, and a post-install script applies my
desktop setup.

**What you get**

- Window manager: **bspwm** + sxhkd, with **polybar**, **picom**, **rofi** and **feh**
- Display manager: **LightDM** with **slick-greeter**
- Terminal and shell: **kitty**, **zsh** (autosuggestions + syntax highlighting) and **starship**
- Editor: **Neovim** with **NvChad**
- Extras: Firefox, Flameshot, Obsidian, open-vm-tools, BlackArch tooling, and Metasploit with a ready-to-use PostgreSQL database

## Repository layout

| Path | Purpose |
| --- | --- |
| `user_configuration.json` | `archinstall` configuration: locale, profile, packages, services and post-install hook |
| `dotfiles.sh` | Non-interactive post-install script (configs, fonts, LightDM, zsh, NvChad, optional BlackArch) |
| `configurations/` | Dotfiles copied to `~/.config`, plus the zsh/starship templates and wallpapers |
| `fonts/` | Fonts copied to `~/.local/share/fonts` |

`user_credentials.json` is intentionally **not** part of the repository, since
it contains passwords (it is listed in `.gitignore`).

## Requirements

- A VM booted from the official [Arch Linux ISO](https://archlinux.org/download/)
- A working network connection (packages and this repository are downloaded during installation)

## Installation

1. Boot the VM from the Arch ISO and check connectivity (`ping archlinux.org`).

2. Download the configuration:

   ```bash
   curl -O https://raw.githubusercontent.com/ZodiakDrinker/AutoArch/main/user_configuration.json
   ```

3. Create `user_credentials.json` with your own username and passwords:

   ```json
   {
     "!root-password": "CHANGE_ME",
     "!users": [
       {
         "username": "youruser",
         "!password": "CHANGE_ME",
         "sudo": true
       }
     ]
   }
   ```

   > The credentials format depends on your `archinstall` version. If it is
   > rejected, create the user from the `archinstall` menu instead and omit
   > `--creds`.

4. Run the installer:

   ```bash
   archinstall --config user_configuration.json --creds user_credentials.json
   ```

5. The disk is **not** defined in the JSON on purpose. Select it in the menu
   and choose **Install**. Everything else is already configured.

6. When it finishes, reboot and log in from LightDM with the **bspwm** session.

## What happens during the installation

`archinstall` installs the base system, the packages listed in the JSON and
enables the services (`lightdm`, `vmtoolsd`, `vmware-vmblock-fuse`). At the end,
its `custom_commands` clone this repository into `/opt/AutoArch` and run
`dotfiles.sh`, which:

1. Copies `configurations/` to `~/.config` and the fonts to `~/.local/share/fonts`
2. Configures LightDM (slick-greeter, bspwm session, wallpaper)
3. Sets up zsh and starship for your user and root, and makes zsh their default shell
4. Installs NvChad
5. Adds the BlackArch repositories and tools (`--blackarch`)
6. Installs Metasploit and sets up its PostgreSQL database (`--metasploit`)

The user does not need to be named in the script: if no username is given,
`dotfiles.sh` uses the first regular user (UID >= 1000) on the system.

## Running `dotfiles.sh` manually

If the post-install step fails or you installed Arch another way:

```bash
git clone https://github.com/ZodiakDrinker/AutoArch
cd AutoArch
sudo ./dotfiles.sh [username] [--blackarch] [--metasploit]
```

It can be run more than once. An existing `~/.config/nvim` is never overwritten.
Apart from the optional `--blackarch` and `--metasploit` steps, this script does not
install packages, so the ones listed in `user_configuration.json` must already be present.

## Installed software

Everything below is installed automatically, either by `archinstall` (the
`packages` list in `user_configuration.json`) or by `dotfiles.sh`.

### Base system

- Linux kernel, GRUB bootloader, NetworkManager, sudo (from `archinstall`)
- Xorg and the rest of the **Bspwm** profile packages that `archinstall` pulls in
- `open-vm-tools` and `gtkmm3` (VMware guest integration)
- `openssh`, `inetutils`, `traceroute`

### Desktop

- **bspwm**: tiling window manager
- **sxhkd**: hotkey daemon
- **polybar**: status bar
- **picom**: compositor
- **rofi**: application launcher
- **feh**: wallpaper setter
- **wmname**: window manager name helper
- **LightDM** with **lightdm-slick-greeter**: login screen
- Fonts: `noto-fonts-emoji` plus the fonts bundled in `fonts/`

### Terminal and shell

- **kitty**: terminal emulator
- **zsh** with **zsh-autosuggestions** and **zsh-syntax-highlighting**
- **starship**: shell prompt
- **lsd**: modern `ls`
- **bat**: modern `cat`
- **neovim** with **NvChad**
- **nano**, **less**

### Applications

- **Firefox**
- **Flameshot**: screenshots
- **Obsidian**: notes
- **pavucontrol**: audio volume control

### Audio

- `pulseaudio`, `pulseaudio-alsa`, `alsa-utils`

### Development tools

- `git`, `base-devel`, `gcc`, `gdb`
- `unzip`, `wget`, `xclip`

### Security tools (`--blackarch`)

Installed after the BlackArch repositories are added:

- **Burp Suite**
- **Ghidra** and `jdk-openjdk`
- **Nmap**
- **Hashcat** and **hashid**
- **Gobuster** and **wfuzz**
- **NetExec**, **smbclient**, **smbmap** and **Certipy**
- **SecLists**
- `openbsd-netcat`, `sshpass`, `openvpn`, `plocate`

### Metasploit (`--metasploit`)

- **Metasploit Framework**
- **PostgreSQL**, with a ready `msf` database

### Services enabled at boot

- `lightdm`
- `vmtoolsd` and `vmware-vmblock-fuse`
- `postgresql` (only with `--metasploit`)

## Customization

| What | Where |
| --- | --- |
| Hostname, timezone | `hostname` and `timezone` in `user_configuration.json` |
| Keyboard layout and language | `locale_config` (`kb_layout`, `sys_lang`) |
| Packages | `packages` in `user_configuration.json` |
| Look and feel | files under `configurations/` |
| BlackArch / Metasploit | the `--blackarch` and `--metasploit` flags in the `dotfiles.sh` call in `custom_commands` (remove them to skip) |

Notes:

- `kb_layout` only sets the console keymap. For the X11 session and the greeter,
  use `localectl set-x11-keymap` (for example `localectl set-x11-keymap us pc105 intl`).
- When using `--blackarch`, `strap.sh` is downloaded and executed. Set
  `BLACKARCH_STRAP_SHA1` to the checksum published on
  [blackarch.org](https://blackarch.org/downloads.html) to verify it first.
- If you fork this repository, change the `git clone` URL in `custom_commands`.
- Metasploit uses the system PostgreSQL service with a `msf` role and database. The
  password is generated randomly and stored in `~/.msf4/database.yml`. Open
  `msfconsole` and run `db_status` to check the connection.
- BlackArch plus Metasploit add several GB of packages: give the VM at least 30 GB of disk.

## Troubleshooting

- **`'All open-source (default)' is not a valid GfxDriver`**: your `archinstall`
  version uses a different value. Use `"All open-source"` (as in this repo's JSON)
  or list the valid ones with
  `grep -rn "open-source" /usr/lib/python3*/site-packages/archinstall/lib/hardware.py`.
- **Cannot log in from the greeter**: switch to a text console with
  `Ctrl + Alt + F2` and check that the password works there. If it does, the
  problem is most likely the greeter's keyboard layout.
- **Session closes right after logging in**: check `~/.xsession-errors` and
  `journalctl -b` for errors in the bspwm configuration.
- **The JSON is rejected**: the `archinstall` schema changes between versions.
  Run it with `--dry-run` first, or generate a reference config by doing one
  manual install and reusing the saved `user_configuration.json`.

## Warning

This setup is intended for virtual machines. Installing to a disk wipes it, so
double-check the target device in the `archinstall` menu.
