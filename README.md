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
- Extras: Firefox, Flameshot, Obsidian, open-vm-tools, and optional BlackArch tooling

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
5. Optionally adds the BlackArch repositories and tools

The user does not need to be named in the script: if no username is given,
`dotfiles.sh` uses the first regular user (UID >= 1000) on the system.

## Running `dotfiles.sh` manually

If the post-install step fails or you installed Arch another way:

```bash
git clone https://github.com/ZodiakDrinker/AutoArch
cd AutoArch
sudo ./dotfiles.sh [username] [--blackarch]
```

It can be run more than once. An existing `~/.config/nvim` is never overwritten.
This script does not install packages, so the ones listed in
`user_configuration.json` must already be present.

## Customization

| What | Where |
| --- | --- |
| Hostname, timezone | `hostname` and `timezone` in `user_configuration.json` |
| Keyboard layout and language | `locale_config` (`kb_layout`, `sys_lang`) |
| Packages | `packages` in `user_configuration.json` |
| Look and feel | files under `configurations/` |
| BlackArch tooling | add `--blackarch` to the `dotfiles.sh` call in `custom_commands` |

Notes:

- `kb_layout` only sets the console keymap. For the X11 session and the greeter,
  use `localectl set-x11-keymap` (for example `localectl set-x11-keymap us pc105 intl`).
- When using `--blackarch`, `strap.sh` is downloaded and executed. Set
  `BLACKARCH_STRAP_SHA1` to the checksum published on
  [blackarch.org](https://blackarch.org/downloads.html) to verify it first.
- If you fork this repository, change the `git clone` URL in `custom_commands`.

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
