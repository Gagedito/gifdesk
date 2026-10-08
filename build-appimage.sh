#!/usr/bin/env bash
# Empaqueta gifdesk como AppImage (AppDir + mksquashfs + appimagetool).
set -euo pipefail

REPO=/home/sabrina/Projects/gifdesk
WORK=/tmp/opencode/pkg
APPDIR=$WORK/gifdesk.AppDir
OUT=/home/sabrina/Documents
VERSION=1.2.0

say() { printf '\n== %s\n' "$*"; }
die() { printf 'build: error: %s\n' "$*" >&2; exit 1; }

say "AppDir limpio"
# Los ficheros copiados desde el store vienen de solo lectura: sin esto, el
# rm del build anterior falla y el AppDir seAccumula de forma corrupta.
chmod -R u+w "$APPDIR" 2>/dev/null || true
rm -rf "$APPDIR"
mkdir -p "$APPDIR"/usr/bin "$APPDIR"/usr/lib \
         "$APPDIR"/usr/share/applications \
         "$APPDIR"/usr/share/gnome-shell/extensions \
         "$APPDIR"/usr/share/gifdesk "$APPDIR"/usr/lib/gifdesk

say "scripts de la app"
install -Dm755 "$REPO/gifdesk"            "$APPDIR/usr/lib/gifdesk/gifdesk"
install -Dm755 "$REPO/gifdesk-gui"        "$APPDIR/usr/lib/gifdesk/gifdesk-gui"
install -Dm755 "$REPO/gifdesk-gui-gnome"  "$APPDIR/usr/lib/gifdesk/gifdesk-gui-gnome"
install -Dm755 "$REPO/gifdesk-gui-kde"    "$APPDIR/usr/lib/gifdesk/gifdesk-gui-kde"
install -Dm644 "$REPO/input.conf"         "$APPDIR/usr/share/gifdesk/input.conf"
cp -r "$REPO/extensions/gifdesk-widgets@gifdesk.local" \
      "$APPDIR/usr/share/gnome-shell/extensions/"

say "descarga de binarios (nix) + libs (ldd)"
mapfile -t TOOLS < <(nix-shell \
    -p "python3.withPackages (ps: [ ps.pygobject3 ps.tkinter ])" \
    -p gtk4 -p libadwaita -p gobject-introspection \
    -p mpv -p ffmpeg -p glib -p bash -p coreutils \
    --run 'for t in python3 mpv ffmpeg ffprobe gdbus bash grep sed awk cat \
            tr cut head tail basename dirname find wc cp rm mv mkdir chmod \
            readlink sha1sum sort ls date sleep kill pgrep; do
            command -v "$t" 2>/dev/null
        done' 2>/dev/null | awk '!seen[$0]++')

n=0
for t in "${TOOLS[@]}"; do
    [[ -x "$t" ]] || continue
    base="$(basename "$t")"
    install -Dm755 "$t" "$APPDIR/usr/bin/$base"
    n=$((n+1))
done
say "$n binarios en usr/bin"

say "librerias compartidas"
mapfile -t LIBS < <(for f in "$APPDIR"/usr/bin/*; do
    ldd "$f" 2>/dev/null | awk '{print $3}'
done | grep '^/' | sort -u)

m=0
for l in "${LIBS[@]}"; do
    [[ -f "$l" ]] || continue
    dest="$APPDIR$(dirname "$l")"
    mkdir -p "$dest"
    if [[ -e "$dest$(basename "$l")" ]]; then
        continue
    fi
    cp -L "$l" "$dest/" 2>/dev/null && m=$((m+1))
done
find "$APPDIR/usr/lib" -type f -name '*.so*' -exec chmod u+w {} + 2>/dev/null || true
say "$m librerias"

say "modulos python (gi, pygobject, tkinter)"
# Copiar solo el binario python3 no basta: el interprete de nix busca sus
# site-packages por ruta ABI dentro del store. Hay que traer el arbol y
# apuntar PYTHONPATH a el (AppRun).
# `command -v python3` dentro del shell devuelve el wrapper con nombre
# python3.13; hay que resolverlo al binario real y de ahi subir al root.
PYROOT="$(nix-shell -p "python3.withPackages (ps: [ ps.pygobject3 ps.tkinter ])" \
    --run 'python3 -c "import sys; print(sys.prefix)"' 2>/dev/null | tail -1)"
[[ "$PYROOT" == /nix/store/* ]] || die "no resuelve el python de nix: $PYROOT"
[[ -d "$PYROOT/lib/python3.13/site-packages" ]] \
    || die "no encuentro site-packages en $PYROOT"

mkdir -p "$APPDIR/usr/lib/python"
cp -rL "$PYROOT/lib/python3.13" "$APPDIR/usr/lib/python/python3.13" 2>/dev/null \
    || cp -r "$PYROOT"/lib/python3.* "$APPDIR/usr/lib/python/" 2>/dev/null \
    || die "no se pudo copiar el arbol de python"
find "$APPDIR/usr/lib/python" -type d -exec chmod u+w {} + 2>/dev/null || true

# gi/_gi*.so y el resto de la extension deben existir como modulos reales.
if [[ ! -d "$APPDIR/usr/lib/python/python3.13/site-packages/gi" ]]; then
    die "site-packages/gi no llego al AppDir"
fi
say "site-packages: $(ls "$APPDIR/usr/lib/python/python3.13/site-packages" | wc -l) modulos"

say "gi (typelibs) y datos GTK/adwaita"
mapfile -t EXTRA < <(nix-shell \
    -p "python3.withPackages (ps: [ ps.pygobject3 ps.tkinter ])" \
    -p gtk4 -p libadwaita -p gobject-introspection -p glib -p pango \
    --run 'ls -d ${GI_TYPELIB_PATH//:/ }; ls -d ${XDG_DATA_DIRS//:/ }' \
    2>/dev/null | grep -E '^/nix/store' | awk '!seen[$0]++')

merge() {
    # Copia el contenido de $1 en $2 respetando permisos y evitando symlinks
    # quecin store (son de solo lectura: fallan al copiarse encima).
    local src="$1" dst="$2"
    [[ -d "$src" && -d "$dst" ]] || return 0
    ( cd "$src" && tar cf - --dereference . ) | ( cd "$dst" && tar xf - --no-same-owner --no-same-permissions )
    find "$dst" -type d -exec chmod u+w {} + 2>/dev/null || true
    find "$dst" -type f -exec chmod u+w {} + 2>/dev/null || true
}

for d in "${EXTRA[@]}"; do
    [[ -d "$d" ]] || continue
    case "$d" in
        */share/girepository-1.0) mkdir -p "$APPDIR/usr/lib/girepository-1.0"
                                merge "$d" "$APPDIR/usr/lib/girepository-1.0" ;;
        */share/glib-2.0)          mkdir -p "$APPDIR/usr/share/glib-2.0"
                                merge "$d" "$APPDIR/usr/share/glib-2.0" ;;
        */share/icons)            mkdir -p "$APPDIR/usr/share/icons"
                                merge "$d" "$APPDIR/usr/share/icons" ;;
        */share/themes)            mkdir -p "$APPDIR/usr/share/themes"
                                merge "$d" "$APPDIR/usr/share/themes" ;;
        */lib/girepository-1.0)   mkdir -p "$APPDIR/usr/lib/girepository-1.0"
                                merge "$d" "$APPDIR/usr/lib/girepository-1.0" ;;
    esac
done

say "icono y .desktop"
# Icono propio: el .desktop traia image-x-generic (no cuenta como icono de AppImage).
if [[ -f "$REPO/icon.png" || -f "$REPO/gifdesk.png" ]]; then
    install -Dm644 "$REPO/icon.png" "$APPDIR/gifdesk.png" 2>/dev/null || \
    install -Dm644 "$REPO/gifdesk.png" "$APPDIR/gifdesk.png"
else
    nix-shell -p imagemagick --run 'convert -size 256x256 xc:none \
        -fill "#3584e4" -draw "circle 128,128 128,48" \
        -fill white -pointsize 42 -gravity center -annotate +0+0 "gif"' \
        "$APPDIR/gifdesk.png" 2>/dev/null || \
    printf '\x89PNG\r\n\x1a\n' >"$APPDIR/gifdesk.png"
fi

sed -e "s|^Exec=.*|Exec=gifdesk-gui|" "$REPO/gifdesk-gui.desktop" \
    >"$APPDIR/gifdesk-gui.desktop"
sed -i "s|^Icon=.*|Icon=gifdesk|" "$APPDIR/gifdesk-gui.desktop"
desktop-file-validate "$APPDIR/gifdesk-gui.desktop" || true
cp "$APPDIR/gifdesk-gui.desktop" "$APPDIR/usr/share/applications/"

say "AppRun"
cat >"$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash
# AppRun de gifdesk: solo prepara el entorno; el nucleo sigue siendo el mismo.
HERE="$(dirname "$(readlink -f "${0}")")"
export PATH="$HERE/usr/bin:$PATH"
export LD_LIBRARY_PATH="$HERE/usr/lib:${LD_LIBRARY_PATH:-}"
export GI_TYPELIB_PATH="$HERE/usr/lib/girepository-1.0:${GI_TYPELIB_PATH:-}"
export XDG_DATA_DIRS="$HERE/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export GSETTINGS_SCHEMA_DIR="$HERE/usr/share/glib-2.0/schemas:${GSETTINGS_SCHEMA_DIR:-}"
# El interprete de nix busca site-packages en el store: hay que dizerselo.
export PYTHONPATH="$HERE/usr/lib/python/python3.13/site-packages${PYTHONPATH:+:$PYTHONPATH}"
export PYTHONDONTWRITEBYTECODE=1
# AppImage montada: se extrae en /tmp/.mount_* (solo lectura y squashfs).
exec "$HERE/usr/lib/gifdesk/gifdesk-gui" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

say "arreglando shebangs (python del AppImage, no el del sistema)"
# Shebang relativo (`/usr/bin/env python3`): el PATH lo pone AppRun, y asi el
# guion sigue funcionando aunque se mueva el AppDir. Con la ruta ABSOLUTA de
# build, el shebang apuntaba a /tmp/opencode/... y no existia ya en el usuario.
for f in "$APPDIR"/usr/lib/gifdesk/gifdesk-gui-*; do
    sed -i "1s|^#!.*|#!/usr/bin/env python3|" "$f"
done

say "compile.sh + AppImage"
cat >"$APPDIR/compile.sh" <<'COMPILE'
#!/usr/bin/env bash
set -eu
HERE="$(dirname "$(readlink -f "$0")")"
MKSQUASHFS="${MKSQUASHFS:-mksquashfs}"
"$MKSQUASHFS" "$HERE" "$HERE/../gifdesk.AppImage" \
    -root-owned -noappend -no-progress -comp gzip -b 262144
cd "$HERE/.."
DESKTOP="$(grep -m1 '^Name=' "$HERE"/*.desktop | cut -d= -f2-)"
UPDATEINFORMATION="${UPDATEINFORMATION:-gh-releases-zsync|$0|latest|$DESKTOP-x86_64.AppImage.zsync}"
appimagetool "$HERE" "$HERE/../gifdesk-1.2.0-x86_64.AppImage"
COMPILE
chmod +x "$APPDIR/compile.sh"

MKSQUASHFS=/nix/store/5kf935kfip9z9x2l5n9dx5f2sws9mid3-squashfs-4.7.5/bin/mksquashfs
export MKSQUASHFS
# appimagetool exige `file` y `mksquashfs` en el PATH.
FILEBIN="$(nix-shell -p file --run 'command -v file' 2>/dev/null | tail -1)"
export PATH="$WORK/squashfs-root/usr/bin:$(dirname "$FILEBIN"):$PATH"
export LD_LIBRARY_PATH="$WORK/squashfs-root/usr/lib:${LD_LIBRARY_PATH:-}"
(cd "$WORK" && ./squashfs-root/usr/bin/appimagetool "$APPDIR" \
    "$OUT/gifdesk-$VERSION-x86_64.AppImage")

say "hecho"
ls -lh "$OUT/gifdesk-$VERSION-x86_64.AppImage"