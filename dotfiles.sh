#!/bin/bash
# dotfiles.sh - parte "de configuración" de AutoArch, 100% no interactiva.
#
# Pensado para ejecutarse desde custom_commands de archinstall (root, dentro
# del chroot), pero también sirve tras el primer arranque con sudo.
#
# Uso:  sudo ./dotfiles.sh [usuario] [--blackarch] [--metasploit]
#
#   --blackarch    añade los repositorios BlackArch e instala herramientas
#   --metasploit   instala Metasploit y prepara su base de datos en el
#                  PostgreSQL del sistema (rol y base "msf")
#
# Variable opcional (solo con --blackarch):
#   BLACKARCH_STRAP_SHA1  SHA1 publicado en https://blackarch.org/downloads.html
#                         para verificar strap.sh antes de ejecutarlo.
set -euo pipefail

log()  { echo -e "\n[+] $(date +%H:%M:%S) $*"; }
ok()   { echo -e "[✔] $*"; }
warn() { echo -e "[!] $*" >&2; }

if [ "$(id -u)" -ne 0 ]; then
  echo "error: ejecuta este script como root (sudo)." >&2
  exit 1
fi

# Toda la salida (pasos, pacman, NvChad, msfconsole...) se guarda también en un
# log. archinstall no muestra la salida de custom_commands, pero se puede seguir
# desde otra consola con:  tail -f /mnt/var/log/autoarch.log
LOG_FILE=/var/log/autoarch.log
exec > >(tee -a "$LOG_FILE") 2>&1

USER_NAME=""
BLACKARCH=0
METASPLOIT=0
for arg in "$@"; do
  case "$arg" in
    --blackarch)  BLACKARCH=1 ;;
    --metasploit) METASPLOIT=1 ;;
    *) USER_NAME="$arg" ;;
  esac
done

# Sin usuario indicado: usa el primer usuario normal (UID >= 1000) del sistema.
if [ -z "$USER_NAME" ]; then
  USER_NAME="$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1; exit}' /etc/passwd)"
  [ -n "$USER_NAME" ] && echo "[i] Usuario detectado automáticamente: $USER_NAME"
fi

if [ -z "$USER_NAME" ] || ! id "$USER_NAME" &>/dev/null; then
  echo "error: el usuario '${USER_NAME}' no existe." >&2
  echo "usuarios disponibles: $(awk -F: '$3 >= 1000 && $3 < 60000 {printf "%s ", $1}' /etc/passwd)" >&2
  echo "uso: $0 [usuario] [--blackarch] [--metasploit]" >&2
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
# Los mirrors de BlackArch caídos o filtrados pueden dejar a pacman colgado
# durante horas (sin timeout de conexión). Mientras se instalan BlackArch y
# Metasploit se usa curl como descargador: 5 s para conectar y aborta si baja
# de 1 KB/s durante 30 s, pasando así al siguiente mirror.
XFER_TAG="# autoarch-xfer"
xfer_on() {
  if grep -q "$XFER_TAG" /etc/pacman.conf; then
    return 0
  fi
  sed -i "/^\[options\]/a XferCommand = /usr/bin/curl -fL -C - --connect-timeout 5 --speed-limit 1024 --speed-time 30 --retry 3 --retry-delay 2 -o %o %u $XFER_TAG" /etc/pacman.conf
}
xfer_off() { sed -i "/$XFER_TAG/d" /etc/pacman.conf; }

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
  # strap.sh pregunta "Perform full system upgrade? [Yn]" leyendo de /dev/tty y
  # después pacman -Su pide confirmación por stdin. Se ejecuta en un pty propio
  # (script) y se le manda una "y" cada 3 s, así que todas las preguntas se
  # contestan que sí. stty -echo evita que las "y" aparezcan en el log.
  local strap_ok=0
  if command -v script >/dev/null 2>&1; then
    timeout 30m script -qefc "stty -echo 2>/dev/null; exec $tmp/strap.sh" /dev/null \
      < <(sleep 2; while :; do echo y; sleep 3; done) && strap_ok=1
  else
    warn "script (util-linux) no disponible: strap.sh puede pedir confirmación y bloquearse"
    timeout 30m "$tmp/strap.sh" </dev/null && strap_ok=1
  fi
  if [ "$strap_ok" -ne 1 ]; then
    pkill -f "$tmp/strap.sh" || true
    pkill -x pacman || true
    rm -f /var/lib/pacman/db.lck
    return 1
  fi
  pacman -S --noconfirm --needed \
    jdk-openjdk burpsuite openbsd-netcat hashid hashcat seclists plocate \
    wfuzz gobuster netexec smbclient smbmap certipy nmap ghidra sshpass \
    openvpn || return 1
}

if [ "$BLACKARCH" -eq 1 ] || [ "$METASPLOIT" -eq 1 ]; then
  xfer_on
  trap xfer_off EXIT
fi

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

# --------------------------------------------------------------- Metasploit -
# Usa el PostgreSQL del sistema (postgresql.service) con un rol y una base
# "msf". La contraseña se genera al azar y se guarda en ~/.msf4/database.yml.
# Se instala DESPUÉS de BlackArch para que el paquete esté disponible en
# cualquiera de los dos repositorios.
PGDATA=/var/lib/postgres/data

as_pg() { (cd /var/lib/postgres && runuser -u postgres -- "$@"); }

init_postgres() {
  if [ -s "$PGDATA/PG_VERSION" ]; then
    return 0
  fi
  as_pg initdb --locale=C.UTF-8 --encoding=UTF8 \
    --auth-local=peer --auth-host=scram-sha-256 -D "$PGDATA"
}

# Requiere PostgreSQL en marcha.
configure_msf_db() {
  local yml="$USER_HOME/.msf4/database.yml" pass exists

  exists="$(as_pg psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='msf'")" || return 1

  if [ ! -f "$yml" ]; then
    pass="$(openssl rand -hex 16)" || return 1
    if [ "$exists" = "1" ]; then
      as_pg psql -c "ALTER ROLE msf WITH LOGIN PASSWORD '$pass'" || return 1
    else
      as_pg psql -c "CREATE ROLE msf LOGIN PASSWORD '$pass'" || return 1
    fi
    install -d -m700 -o "$USER_NAME" -g "$USER_GROUP" "$USER_HOME/.msf4" || return 1
    cat > "$yml" <<EOF
production:
  adapter: postgresql
  database: msf
  username: msf
  password: $pass
  host: 127.0.0.1
  port: 5432
  pool: 200
  timeout: 5
EOF
    chown "$USER_NAME:$USER_GROUP" "$yml" || return 1
    chmod 600 "$yml" || return 1
  elif [ "$exists" != "1" ]; then
    warn "$yml existe pero el rol msf no. Bórralo y vuelve a ejecutar el script."
    return 1
  fi

  exists="$(as_pg psql -tAc "SELECT 1 FROM pg_database WHERE datname='msf'")" || return 1
  [ "$exists" = "1" ] || as_pg createdb -O msf msf || return 1

  # Primera conexión: crea el esquema de la base de datos.
  as_user timeout 20m msfconsole -q -x "db_status; exit" \
    || warn "No se pudo crear el esquema ahora; se creará en el primer msfconsole"
}

setup_metasploit() {
  local started=0 rc=0

  pacman -S --noconfirm --needed metasploit postgresql openssl || return 1
  init_postgres || return 1

  # Si PostgreSQL no está corriendo (chroot de archinstall), se levanta uno
  # temporal sin systemd y se para al terminar.
  if ! as_pg pg_isready -q; then
    install -d -o postgres -g postgres -m 755 /run/postgresql || return 1
    as_pg pg_ctl -D "$PGDATA" -l /var/lib/postgres/autoarch-initial.log -w start || return 1
    started=1
  fi

  configure_msf_db || rc=1

  if [ "$started" -eq 1 ]; then
    as_pg pg_ctl -D "$PGDATA" -m fast -w stop || warn "No se pudo parar el PostgreSQL temporal"
  fi

  [ "$rc" -eq 0 ] || return 1
  systemctl enable postgresql.service || return 1
}

if [ "$METASPLOIT" -eq 1 ]; then
  log "Instalando y preparando Metasploit (PostgreSQL + base de datos msf)"
  if setup_metasploit; then
    ok "Metasploit listo: abre msfconsole y comprueba con db_status"
  else
    warn "Falló la preparación de Metasploit; el resto del sistema sigue intacto"
  fi
else
  echo "[i] Metasploit omitido (usa --metasploit para instalarlo)"
fi

echo -e "\n[✔] DONE. Reinicia y elige la sesión bspwm en LightDM."
