#!/usr/bin/env bash
# install.sh — instala gifdesk (reproductor GIF/WebP flotante, mpv).
# Soporta: Arch/Artix/CachyOS/Manjaro/EndeavourOS/Garuda, Debian/Ubuntu/Mint/Pop,
# Fedora/RHEL/Rocky/Alma/Nobara, openSUSE, Void. Otros: aviso manual.
set -euo pipefail

APP="gifdesk"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/gifdesk"
CONFIG_FILE="$CONFIG_DIR/gifdesk.conf"
AUTOSTART_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
DESKTOP_FILE="$AUTOSTART_DIR/gifdesk.desktop"
SHARE_DIR="$HOME/.local/share/gifdesk"

FILE_ARG=""
WITH_HYPR="no"
WITH_SYSTEMD="no"
YES="no"

msg() { printf '%s\n' "$*"; }
die() { printf 'install: error: %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Uso: ./install.sh [OPCIONES]

  --file RUTA       GIF/WebP que se mostrara al iniciar (defecto: ~/Descargas/rem.gif si existe)
  --with-hypr       Anade autostart a Hyprland (execs.lua) ademas de XDG autostart
  --with-systemd    Instala tambien la unidad de usuario systemd (opcional)
  -y, --yes         No preguntar, asumir si
  -h, --help        Esta ayuda
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --file) FILE_ARG="${2:-}"; shift 2 ;;
        --file=*) FILE_ARG="${1#*=}"; shift ;;
        --with-hypr) WITH_HYPR="yes"; shift ;;
        --with-systemd) WITH_SYSTEMD="yes"; shift ;;
        -y|--yes) YES="yes"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "opcion desconocida: $1" ;;
    esac
done

# ---------- 1. detectar distro ----------
FAM="desconocida"
if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    IDL="$(printf '%s %s' "${ID:-}" "${ID_LIKE:-}" | tr '[:upper:]' '[:lower:]')"
    case "$IDL" in
        *arch*|*artix*|*cachyos*|*manjaro*|*endeavour*|*garuda*|*arco*) FAM="arch" ;;
        *debian*|*ubuntu*|*mint*|*pop*|*mx*|*zorin*)                     FAM="debian" ;;
        *fedora*|*rhel*|*centos*|*rocky*|*alma*|*nobara*|*ultramarine*|*bazzite*) FAM="fedora" ;;
        *opensuse*|*suse*)                                              FAM="suse" ;;
        *void*)                                                        FAM="void" ;;
        *gentoo*)                                                      FAM="gentoo" ;;
    esac
fi
msg "Distro detectada: familia '$FAM'."

install_deps() {
    if ! command -v mpv >/dev/null 2>&1; then
        case "$FAM" in
            arch)   sudo pacman -S --needed --noconfirm mpv ffmpeg ;;
            debian) sudo apt-get update && sudo apt-get install -y mpv ffmpeg ;;
            fedora) sudo dnf install -y mpv ffmpeg ;;
            suse)   sudo zypper install -y mpv ffmpeg ;;
            void)   sudo xbps-install -S mpv ffmpeg ;;
            gentoo) die "Gentoo: instala manualmente: emerge media-video/mpv media-video/ffmpeg" ;;
            *)      die "distro no reconocida: instala mpv y ffmpeg manualmente y reintenta" ;;
        esac
    else
        msg "mpv ya instalado."
    fi
    # tkinter para la interfaz grafica (gifdesk-gui).
    if ! python3 -c "import tkinter" 2>/dev/null; then
        msg "Instalando tkinter para la interfaz grafica..."
        case "$FAM" in
            arch)   sudo pacman -S --needed --noconfirm tk ;;
            debian) sudo apt-get install -y python3-tk ;;
            fedora) sudo dnf install -y python3-tkinter ;;
            suse)   sudo zypper install -y python3-tk ;;
            void)   sudo xbps-install -S python3-tkinter ;;
            *)      msg "Aviso: no se pudo instalar tkinter; la GUI puede no abrir." ;;
        esac
    fi
}

if [[ "$YES" != "yes" ]]; then
    printf 'Instalar %s y registrar autostart? [S/n] ' "$APP"
    read -r ans || true
    [[ "${ans:-}" =~ ^([nN]|no|NO)$ ]] && die "cancelado por el usuario"
fi

install_deps
command -v mpv >/dev/null 2>&1 || die "mpv no quedo instalado"

# ---------- 2. elegir archivo ----------
GIF="$FILE_ARG"
if [[ -z "$GIF" && -f "$HOME/Descargas/rem.gif" ]]; then
    GIF="$HOME/Descargas/rem.gif"
fi
if [[ -z "$GIF" ]]; then
    printf 'Ruta del GIF/WebP a mostrar (ej: ~/Descargas/rem.gif): '
    read -r GIF || true
fi
# Normalizar ruta: ~/ -> HOME, relativa -> PWD actual.
# Ademas repara el caso "$HOME/~/resto" (pegar rutas con ~ sin expandir).
case "$GIF" in
    "~/"*) GIF="$HOME/${GIF#~/}" ;;
    "~")   GIF="$HOME" ;;
    /*)    ;;
    *)     GIF="$PWD/$GIF" ;;
esac
if [[ "$GIF" == "$HOME/~/"* ]]; then
    GIF="$HOME/${GIF#"$HOME/~/"}"
fi
[[ -f "$GIF" ]] || die "no existe: $GIF"
case "$(printf '%s' "$GIF" | tr '[:upper:]' '[:lower:]')" in
    *.gif|*.webp) ;;
    *) die "solo .gif / .webp: $GIF" ;;
esac

# ---------- 3. instalar binarios (visor + GUI) ----------
LIB_DIR="$SHARE_DIR/library"
INST_DIR="$CONFIG_DIR/instances"
mkdir -p "$BIN_DIR" "$CONFIG_DIR" "$SHARE_DIR" "$LIB_DIR" "$INST_DIR" "${XDG_CACHE_HOME:-$HOME/.cache}/gifdesk"
cp -f "$SRC_DIR/gifdesk" "$BIN_DIR/gifdesk"
chmod +x "$BIN_DIR/gifdesk"
bash -n "$BIN_DIR/gifdesk"
msg "Binario instalado: $BIN_DIR/gifdesk"
cp -f "$SRC_DIR/gifdesk-gui" "$BIN_DIR/gifdesk-gui"
chmod +x "$BIN_DIR/gifdesk-gui"
python3 -m py_compile "$BIN_DIR/gifdesk-gui" 2>/dev/null \
    || msg "Aviso: no se pudo precompilar la GUI (python3 ausente?); igual intentara abrirse."
# Atajos extra del GIF (opcional, archivo editable por el usuario).
if [[ ! -f "$CONFIG_DIR/input.conf" ]]; then
    cp -f "$SRC_DIR/input.conf" "$CONFIG_DIR/input.conf"
    msg "Atajos instalados: $CONFIG_DIR/input.conf"
fi
msg "GUI instalada: $BIN_DIR/gifdesk-gui"

# Importar el GIF elegido a la libreria (la GUI gestiona esa carpeta).
# Si ya existe identico, se reutiliza sin duplicar.
LIB_GIF="$LIB_DIR/$(basename "$GIF")"
if [[ "$GIF" != "$LIB_GIF" ]]; then
    if [[ -f "$LIB_GIF" ]] && cmp -s "$GIF" "$LIB_GIF"; then
        msg "Ya estaba en la libreria: $LIB_GIF"
    else
        base="${LIB_GIF%.*}"; ext="${LIB_GIF##*.}"; i=1
        while [[ -f "${base}_${i}.${ext}" ]]; do i=$((i+1)); done
        LIB_GIF="${base}_${i}.${ext}"
        cp -f "$GIF" "$LIB_GIF"
        msg "Importado a la libreria: $LIB_GIF"
    fi
fi
GIF="$LIB_GIF"

# ---------- 4. config ----------
if [[ ! -f "$CONFIG_FILE" ]]; then
    # printf en vez de heredoc: una ruta con $ o backticks no se expande.
    {
        printf '# gifdesk — configuracion (la usa %s)\n' "'gifdesk --autostart'"
        printf 'FILE="%s"\n' "$GIF"
        printf 'MODE=widget\nSIZE=\nPOS=BR\nLOCKED=no\n'
    } >"$CONFIG_FILE"
    msg "Config creada: $CONFIG_FILE"
else
    msg "Config ya existia, se conserva: $CONFIG_FILE"
    msg "  (para cambiar el archivo, edita FILE= en ese fichero o usa gifdesk-gui)"
    grep -qE '^[[:space:]]*LOCKED[[:space:]]*=' "$CONFIG_FILE" || echo 'LOCKED=no' >>"$CONFIG_FILE"
fi

# ---------- 5. autostart XDG (KDE, XFCE, MATE, LXQt, GNOME, Openbox...) ----------
mkdir -p "$AUTOSTART_DIR"
cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=gifdesk
Comment=Muestra un GIF/WebP flotante al iniciar sesion
Exec="$BIN_DIR/gifdesk" --autostart
Icon=image-x-generic
Terminal=false
Categories=Utility;
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=2
EOF
msg "Autostart XDG: $DESKTOP_FILE"

# ---------- 5b. entrada en el menu de aplicaciones para la GUI ----------
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$APPS_DIR"
cat >"$APPS_DIR/gifdesk-gui.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=gifdesk gestor
Comment=Gestiona tus GIF/WebP flotantes (galeria y editor)
Exec="$BIN_DIR/gifdesk-gui"
Icon=image-x-generic
Terminal=false
Categories=Utility;Graphics;
EOF
msg "Menu de aplicaciones: $APPS_DIR/gifdesk-gui.desktop"

# ---------- 6. Hyprland (no lee XDG autostart por defecto) ----------
HYPR_EXEC="$HOME/.config/hypr/hyprland/execs.lua"
if [[ -d "$HOME/.config/hypr" ]]; then
    if [[ "$WITH_HYPR" == "yes" ]]; then
        if [[ -f "$HYPR_EXEC" ]] && ! grep -q "gifdesk --autostart" "$HYPR_EXEC" 2>/dev/null; then
            # Ruta no estandar (setup Lua propio, no hyprland.conf). Backup primero.
            cp -f "$HYPR_EXEC" "$HYPR_EXEC.bak-gifdesk" &&
            # Insertar antes del 'end)' final del bloque hyprland.start es fragil;
            # mejor: anadir linea hl.exec_cmd al final del fichero dentro de un bloque seguro.
            cat >>"$HYPR_EXEC" <<'EOF'

-- gifdesk (anadido por install.sh --with-hypr)
hl.on("hyprland.start", function()
    hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/gifdesk --autostart")
end)
EOF
            msg "Hyprland: autostart anadido a $HYPR_EXEC"
        else
            msg "Hyprland: ya contenia gifdesk o no se encontro execs.lua (revisa manual)."
        fi
    else
        msg "Hyprland detectado: NO modifica tu config."
        msg "  Para autostart en Hyprland, reinstala con --with-hypr o anade:"
        msg "    hl.exec_cmd(os.getenv(\"HOME\") .. \"/.local/bin/gifdesk --autostart\")"
    fi
fi

# ---------- 7. systemd user (opcional) ----------
if [[ "$WITH_SYSTEMD" == "yes" ]]; then
    mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    cp -f "$SRC_DIR/gifdesk.service" "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/gifdesk.service"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable gifdesk.service 2>/dev/null || true
        msg "systemd user: unidad instalada y habilitada (gifdesk.service)."
        msg "  Nota: si tu DE ya usa XDG autostart, desactiva una de las dos para no duplicar."
    else
        msg "systemd no disponible (runit/OpenRC?); unidad copiada pero no habilitada."
    fi
fi

# ---------- 8. prueba ----------
if "$BIN_DIR/gifdesk" --check --file "$GIF" 2>&1 | head -n 20; then
    msg "Comprobacion OK."
else
    msg "Aviso: --check reporto algo (revisa arriba); igual puedes probar manualmente."
fi

cat <<EOF

Listo. Prueba ahora con:
  $BIN_DIR/gifdesk --file "$GIF"
  $BIN_DIR/gifdesk-gui          # interfaz grafica: galeria + editor

Util:
  $BIN_DIR/gifdesk --stop     # detener
  $BIN_DIR/gifdesk --status   # estado

El GIF se mostrara solo al iniciar sesion (autostart XDG).
Para quitarlo: ./uninstall.sh
EOF
