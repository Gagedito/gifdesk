#!/usr/bin/env bash
# uninstall.sh — revierte lo que hizo install.sh. No toca tu GIF original.
set -euo pipefail

BIN="$HOME/.local/bin/gifdesk"
GUI_BIN="$HOME/.local/bin/gifdesk-gui"
BIN_DIR_PYCACHE="$HOME/.local/bin/__pycache__"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/gifdesk"
DESKTOP="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/gifdesk.desktop"
GUI_DESKTOP="${XDG_DATA_HOME:-$HOME/.local/share}/applications/gifdesk-gui.desktop"
LIB_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/gifdesk"
UNIT="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/gifdesk.service"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/gifdesk"
PURGE="no"

for a in "$@"; do
    case "$a" in
        --purge) PURGE="yes" ;;
        -h|--help) printf 'Uso: ./uninstall.sh [--purge]\n  Sin --purge conserva %s y la libreria %s\n' "$CONFIG_DIR" "$LIB_DIR"; exit 0 ;;
        *) printf 'uninstall: error: opcion desconocida: %s\n' "$a" >&2; exit 1 ;;
    esac
done

"$BIN" --stop >/dev/null 2>&1 || pkill -f "wayland-app-id=gifdesk" 2>/dev/null || true
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user disable gifdesk.service 2>/dev/null || true
fi
rm -f "$BIN" "$GUI_BIN" "$DESKTOP" "$GUI_DESKTOP" "$UNIT"
rm -rf "$CACHE" "$BIN_DIR_PYCACHE"
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload 2>/dev/null || true
fi

HYPR_EXEC="$HOME/.config/hypr/hyprland/execs.lua"
if [[ -f "$HYPR_EXEC" ]] && grep -q "gifdesk --autostart" "$HYPR_EXEC" 2>/dev/null; then
    printf 'uninstall: tu %s aun menciona gifdesk; quita ese bloque manualmente.\n' "$HYPR_EXEC"
fi

if [[ "$PURGE" == "yes" ]]; then
    rm -rf "$CONFIG_DIR" "$LIB_DIR"
    printf 'gifdesk desinstalado (con --purge: config y libreria eliminadas).\n'
else
    printf 'gifdesk desinstalado. Config en %s y libreria en %s (usa --purge para borrarlas).\n' "$CONFIG_DIR" "$LIB_DIR"
fi
