{ lib
, stdenv
, bash
, makeWrapper
, wrapGAppsHook4
, gobject-introspection
, python3
, gtk4
, libadwaita
, gdk-pixbuf
, glib
, gnome-shell
, mpv
, ffmpeg
}:
let
  pythonGui = python3.withPackages (ps: [ ps.pygobject3 ]);
in
stdenv.mkDerivation {
  pname = "gifdesk";
  version = "1.1.0";

  src = ../.;

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ makeWrapper wrapGAppsHook4 gobject-introspection ];
  buildInputs = [ bash gtk4 libadwaita gdk-pixbuf glib pythonGui ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/applications \
      $out/share/gnome-shell/extensions $out/share/gifdesk

    install -Dm755 gifdesk $out/bin/gifdesk
    install -Dm755 gifdesk-gui $out/bin/gifdesk-gui
    install -Dm755 gifdesk-gui-kde $out/bin/gifdesk-gui-kde
    install -Dm755 gifdesk-gui-gnome $out/bin/gifdesk-gui-gnome
    install -Dm644 input.conf $out/share/gifdesk/input.conf
    cp -r extensions/gifdesk-widgets@gifdesk.local \
      $out/share/gnome-shell/extensions/

    # Intérpretes fijos del store (nada de /usr/bin/env en runtime).
    substituteInPlace $out/bin/gifdesk-gui-gnome \
      --replace-fail '#!/usr/bin/env python3' '#!${pythonGui}/bin/python3'
    substituteInPlace $out/bin/gifdesk-gui-kde \
      --replace-fail '#!/usr/bin/env python3' '#!${python3}/bin/python3'

    # Motor: mpv/ffmpeg + gdbus (glib) + gnome-extensions (gnome-shell).
    wrapProgram $out/bin/gifdesk \
      --prefix PATH : "${lib.makeBinPath [ mpv ffmpeg glib gnome-shell bash ]}"

    # Entradas de menú con rutas absolutas del store.
    for f in gifdesk-gui gifdesk-gui-gnome gifdesk-gui-kde; do
      sed "s|^Exec=.*|Exec=$out/bin/$f|" "$f.desktop" \
        > "$out/share/applications/$f.desktop"
    done

    runHook postInstall
  '';

  meta = with lib; {
    description = "Ventanas flotantes con tus GIF/WebP animados (mpv); GUIs KDE y GNOME + extensión de posicionamiento para Mutter";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    mainProgram = "gifdesk";
  };
}
