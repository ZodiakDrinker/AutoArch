#!/bin/bash
# dotfiles.sh - parte "de configuración" de AutoArch, 100% no interactiva.
#
# Pensado para ejecutarse desde custom_commands de archinstall (root, dentro
# del chroot), pero también sirve tras el primer arranque con sudo.
#
# Uso:  sudo ./dotfiles.sh <usuario> [--blackarch]
#
# Variable opcional (solo con --blackarch):
#   BLACKARCH_STRAP_SHA1  SHA1 publicado en https://blackarch.org/downloads.html
#                         para verificar strap.sh antes de ejecutarlo.
set -euo pipefail

log()  { echo -e "\n[+] $*"; }
ok()   { echo -e "[✔] $*"; }
warn() { echo -e "[!] $*" >&2; }

if [ "$(id -u)" -ne 0 ]; then
  echo "error: ejecuta este script como root (sudo)." >&2
  exit 1
fi

USER_NAME="${1:-}"
BLACKARCH=0
if [ "${2:-}" = "--blackarch" ]; then
  BLACKARCH=1
fi

if [ -z "$USER_NAME" ] || ! id "$USER_NAME" &>/dev/null; then
  echo "uso: $0 <usuario_existente> [--blackarch]" >&2
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
USER_GROUP="$(id -gn "$USER_NAME")"
CONF="$USER_HOME/.config"

cd "$USER_HOME"
as_user() { runuser -u "$USER_NAME" -- env HOME="$USER_HOME" "$@"; }

# ---------------------------------------------------------------- configs --
log "Copiando configuraciones a $CONF"
install -d -o "$USER_NAME" -g "$USER_GROUP" "$CONF"
cp -r "$REPO_DIR"/configurations/. "$CONF"/

if [ -d "$CONF/polybar" ]; then
  find "$CONF/polybar" -type f -exec chmod +x {} \;
fi
for f in sxhkd/sxhkdrc bspwm/bspwmrc polybar/launch.sh bspwm/scripts/bspwm_resize; do
  if [ -f "$CONF/$f" ]; then
    chmod +x "$CONF/$f"
  fi
done

# ----------------------------------------------------------------- fuentes --
log "Instalando fuentes"
install -d "$USER_HOME/.local/share/fonts"
cp -r "$REPO_DIR"/fonts/. "$USER_HOME/.local/share/fonts/"
chown -R "$USER_NAME:$USER_GROUP" "$USER_HOME/.local" "$CONF"
fc-cache -f "$USER_HOME/.local/share/fonts" || warn "fc-cache falló (no es crítico)"
ok "Configuraciones y fuentes listas"

# ---------------------------------------------------------- LightDM/bspwm --
log "Configurando LightDM (slick-greeter) y sesión bspwm"

if [ -f "$REPO_DIR/configurations/Wallpapers/greeter-wall.jpg" ]; then
  install -Dm644 "$REPO_DIR/configurations/Wallpapers/greeter-wall.jpg" \
    /usr/share/backgrounds/greeter-wall.jpg
fi

# El paquete bspwm ya trae su .desktop; solo lo creamos si falta.
if [ ! -f /usr/share/xsessions/bspwm.desktop ]; then
  install -d /usr/share/xsessions
  cat > /usr/share/xsessions/bspwm.desktop <<'EOF'
[Desktop Entry]
Name=bspwm
Comment=Tiling window manager
Exec=bspwm
TryExec=bspwm
Type=Application
DesktopNames=bspwm
EOF
fi

# Drop-in en lugar de sed sobre lightdm.conf: idempotente y no pisa nada.
install -d /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-autoarch.conf <<'EOF'
[Seat:*]
greeter-session=lightdm-slick-greeter
user-session=bspwm
EOF

cat > /etc/lightdm/slick-greeter.conf <<'EOF'
[Greeter]
show-hostname=false
background=/usr/share/backgrounds/greeter-wall.jpg
font-name=HackNerdFont
EOF
ok "LightDM configurado"

# ------------------------------------------------------------------- zsh ---
log "Configurando zsh y starship"
install -m644 -o "$USER_NAME" -g "$USER_GROUP" \
  "$REPO_DIR/configurations/zshrc_template" "$USER_HOME/.zshrc"
if ! grep -q 'starship init zsh' "$USER_HOME/.zshrc"; then
  echo 'eval "$(starship init zsh)"' >> "$USER_HOME/.zshrc"
fi
install -m644 -o "$USER_NAME" -g "$USER_GROUP" \
  "$REPO_DIR/configurations/starship_template" "$CONF/starship.toml"

ln -sf "$USER_HOME/.zshrc" /root/.zshrc
usermod -s /usr/bin/zsh root
usermod -s /usr/bin/zsh "$USER_NAME"
ok "zsh + starship listos"

# ------------------------------------------------------------------- audio --
# pulseaudio es socket-activated; esto es solo un refuerzo.
systemctl --global enable pulseaudio.socket 2>/dev/null || true

# ----------------------------------------------------------------- NvChad ---
log "Instalando NvChad"
if [ -d "$CONF/nvim" ]; then
  warn "$CONF/nvim ya existe, no se toca"
elif as_user git clone --depth 1 https://github.com/NvChad/starter "$CONF/nvim"; then
  rm -rf "$CONF/nvim/.git"
  as_user nvim --headless "+Lazy! sync" +qa \
    || warn "Los plugins de NvChad no se sincronizaron; se instalarán al abrir nvim"
  ok "NvChad instalado"
else
  warn "No se pudo clonar NvChad (¿sin red?). Continuando"
fi

# ---------------------------------------------------------------- BlackArch -
install_blackarch() {
  local tmp
  tmp="$(mktemp -d)" || return 1
  curl -fsSL https://blackarch.org/strap.sh -o "$tmp/strap.sh" || return 1
  if [ -n "${BLACKARCH_STRAP_SHA1:-}" ]; then
    echo "$BLACKARCH_STRAP_SHA1  $tmp/strap.sh" | sha1sum -c - || return 1
  else
    warn "BLACKARCH_STRAP_SHA1 no definido: strap.sh se ejecuta SIN verificar"
  fi
  chmod +x "$tmp/strap.sh"
  "$tmp/strap.sh" || return 1
  pacman -S --noconfirm --needed \
    jdk-openjdk burpsuite openbsd-netcat hashid hashcat seclists plocate \
    wfuzz gobuster netexec smbclient smbmap certipy nmap ghidra sshpass \
    openvpn || return 1
}

if [ "$BLACKARCH" -eq 1 ]; then
  log "Instalando repositorios BlackArch y herramientas"
  if install_blackarch; then
    ok "BlackArch y herramientas instalados"
  else
    warn "Falló la instalación de BlackArch; el resto del sistema sigue intacto"
  fi
else
  echo "[i] BlackArch omitido (usa --blackarch para instalarlo)"
fi

echo -e "\n[✔] DONE. Reinicia y elige la sesión bspwm en LightDM."
