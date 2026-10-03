# gifdesk

Ventanas flotantes que muestran **solo tus GIF / WebP animados**, siempre visibles,
cada uno independiente, con **bajo consumo** (mpv + decodificacion por hardware) y
**transparencia real**. Autostart en cualquier distro y entorno grafico.

![Debian](https://img.shields.io/badge/Debian-ok-A81D33?logo=debian)
![Ubuntu](https://img.shields.io/badge/Ubuntu-ok-E95420?logo=ubuntu)
![Arch](https://img.shields.io/badge/Arch-ok-1793D1?logo=archlinux)
![Artix](https://img.shields.io/badge/Artix-ok-10A0CC?logo=artixlinux)
![Fedora](https://img.shields.io/badge/Fedora-ok-294172?logo=fedora)
![KDE](https://img.shields.io/badge/KDE-ok-1abc9c)
![Hyprland](https://img.shields.io/badge/Hyprland-ok-00e5cc)
![XFCE](https://img.shields.io/badge/XFCE-ok-07a3e0)

> Probado en Artix Linux (runit, Plasma Wayland) con mpv 0.41.

- [Requisitos](#requisitos)
- [Instalacion](#instalacion)
- [Inicio rapido](#inicio-rapido)
- [Interfaz grafica](#interfaz-grafica)
- [Instancias (varios GIFs)](#instancias-varios-gifs)
- [Linea de comandos](#linea-de-comandos)
- [Ficheros](#ficheros)
- [Como funciona](#como-funciona)
- [Transparencia](#transparencia)
- [Consumo](#consumo)
- [Autostart por entorno](#autostart-por-entorno)
- [Limitaciones conocidas](#limitaciones-conocidas)
- [Solucion de problemas](#solucion-de-problemas)
- [Desinstalacion](#desinstalacion)
- [Licencia](#licencia)

---

## Requisitos

- `mpv`, `ffmpeg`, `python3` + `tkinter` (el instalador los pone por ti).
- En KDE Wayland: `kwriteconfig6`, `kreadconfig6` y `qdbus6` (vienen con Plasma)
  para colocar y recordar tamano/posicion/opacidad via regla KWin.

## Instalacion

```bash
cd ~/gifdesk
chmod +x gifdesk install.sh uninstall.sh
./install.sh --file ~/Descargas/rem.gif
```

| Flag | Descripcion |
|------|-------------|
| `--file RUTA` | GIF/WebP a mostrar (defecto: `~/Descargas/rem.gif` si existe) |
| `--with-hypr` | Ademas registra autostart en Hyprland (`execs.lua`) |
| `--with-systemd` | Ademas instala la unidad de usuario systemd |
| `-y, --yes` | No preguntar |

Que hace:

1. Detecta la familia de distro (arch/artix, debian, fedora, suse, void) e instala
   `mpv` + `ffmpeg` (+ `tkinter` para la GUI) si faltan.
2. Copia `gifdesk` y `gifdesk-gui` a `~/.local/bin/`, e `input.conf` a su config.
3. Importa tu GIF/WebP a la libreria `~/.local/share/gifdesk/library/` y lo deja
   configurado (primera vez en la config clasica; la GUI lo adopta a instancia).
4. Registra `~/.config/autostart/gifdesk.desktop` (KDE, XFCE, MATE, LXQt, GNOME,
   Openbox...) y "gifdesk gestor" en el menu de aplicaciones.
5. Si hay Hyprland, te dice como (o lo hace con `--with-hypr`).
6. Corre `gifdesk --check` como verificacion.

## Inicio rapido

```bash
gifdesk-gui   # o "gifdesk gestor" en el menu de aplicaciones
```

1. **Anadir** tus GIF/WebP a la galeria.
2. Selecciona uno y pulsa **Mostrar** (o doble clic).
3. En el editor ajusta tamano/posicion/opacidad y **Aplicar cambios**.
4. **Bloquear** cuando quede como quieres (ignora el raton).

## Interfaz grafica

Ventana con dos paneles (tkinter, sin dependencias extra). **Cierra y vuelve a
abrirla tras actualizar**, para no usar codigo viejo.

### Galeria (libreria)

- Lista `~/.local/share/gifdesk/library/` con dimensiones, cuadros y estado
  (`[on]` = mostrandose), mas vista previa (GIF; WebP sin vista previa).
- **Anadir**: copia el archivo a la libreria (tu original no se toca; si el
  nombre existe y el contenido difiere, se guarda como `nombre_1.ext`).
- **Borrar**: pide confirmacion y elimina archivo + su instancia.
- **Mostrar** (o doble clic): lo pone en pantalla como instancia independiente.

### Editor (por GIF seleccionado)

Todo lo que cambies aqui afecta **solo al GIF seleccionado** (mira
`Archivo actual [instancia: ...]`):

- **Resolucion**: ancho x alto directos, boton **Nativo** (rellena con la
  resolucion real y la aplica al instante) o slider **%** (100 = real; rellena
  los campos y luego **Aplicar cambios**). El slider siempre refleja lo guardado.
- **Posicion**: esquinas (`TL TR BL BR C`) o `X,Y` personalizado.
- **Opacidad**: slider 0-100 (100 = opaco, 0 = invisible pero sigue corriendo).
- **Aplicar cambios**: guarda y relanza esa instancia con lo nuevo. Si no
  cambiaste nada, no hace nada (para no devolverlo a su sitio en vano). Se
  bloquea mientras trabaja para evitar dobles pulsaciones.
- **Bloquear/Desbloquear posicion**: congela la ventana **donde esta** (ignora
  el raton) o la libera, **en vivo y sin relanzar**. Nombra la instancia
  (`Bloqueado rem donde esta`). Si el seleccionado no se muestra, avisa cual
  si lo esta (mira `[on]`).
- **Iniciar/Detener**: muestra o quita el seleccionado.

> Regla de oro: **desbloqueado = editable** (mover, rueda si la configuras,
> editor), **bloqueado = congelado** (el raton lo atraviesa).

### Edicion con el raton, sobre el propio GIF (desbloqueado)

**Arrastra** para moverlo (lo gestiona el compositor; vive la sesion: al
relanzar o reiniciar vuelve a su sitio configurado).

## Instancias (varios GIFs)

Cada GIF mostrado es una **instancia independiente**: proceso, config
(`~/.config/gifdesk/instances/<id>.conf`), socket IPC (`socket-<id>`),
titulo de ventana (`gifdesk-<id>`) y regla KWin (`[gifdesk-<id>]`) propios.
El id sale del nombre del archivo (`Mi Gif.webp` → `mi-gif`; colisiones se
sufijan `_1`, `_2`; `main` esta reservado para la clasica).

- En autostart (`gifdesk --autostart` sin `--id`) vuelven **todas** solas.
- `gifdesk --list` muestra cada una con su estado y archivo.
- `gifdesk --stop-all` las detiene todas.
- La config clasica (`gifdesk.conf`) se vacia al adoptar desde galeria para no
  duplicar ventanas.

## Linea de comandos

```bash
gifdesk --id rem --file ~/anim.gif --size 320x200 --pos TR --save
gifdesk --id rem --file anim.webp --mode wallpaper   # pantalla completa
gifdesk --list
gifdesk --id rem --status
gifdesk --id rem --stop
gifdesk --stop-all
gifdesk --check --file ~/Descargas/rem.gif
gifdesk --dry-run --file rem.gif          # ver el comando mpv sin abrir ventana
```

| Opcion | Descripcion |
|--------|-------------|
| `--id NOMBRE` | Instancia independiente (`[A-Za-z0-9_-]`, max 32, `main` reservado). Sin `--id` se usa la clasica |
| `--file RUTA` | Archivo `.gif` / `.webp` a mostrar |
| `--save` | Guarda FILE/MODE/SIZE/POS/LOCKED/OPACITY en su config (para autostart) |
| `--mode widget\|wallpaper` | `widget` (defecto): flotante sin bordes, siempre encima. `wallpaper`: pantalla completa |
| `--size WxH` | Tamano (defecto: nativo del archivo) |
| `--pos GEOM` | `X,Y` o `TL TR BL BR C` (defecto: `BR`, margen 16px). En Wayland la posicion final la decide el compositor + regla KWin |
| `--opacity PCT` | 0-100 (defecto 100). Requiere KWin (va por regla) |
| `--click-through` | Solo esa vez: ignora el raton |
| `--autostart` | Sin `--id`: clasica + todas las instancias. Con `--id`: solo esa, segun su config |
| `--check` | Valida archivo y entorno sin abrir ventana |
| `--dry-run` | Muestra el comando mpv sin ejecutarlo |
| `--stop` / `--stop-all` | Detiene una / todas |
| `--status` | Dice si esa instancia corre (codigo 0/1) |
| `--list` | Tabla de instancias, estado y archivo |
| `--rule-only` | Sincroniza la regla KWin desde la config, sin lanzar (uso interno de la GUI) |

## Ficheros

| Ruta | Que es |
|------|--------|
| `~/.local/bin/gifdesk`, `gifdesk-gui` | Binarios instalados |
| `~/.local/share/gifdesk/library/` | Tus GIF/WebP (copias de trabajo) |
| `~/.config/gifdesk/gifdesk.conf` | Config clasica (legado; la GUI la vacia al adoptar) |
| `~/.config/gifdesk/instances/<id>.conf` | Config por instancia: `FILE MODE SIZE POS LOCKED REV OPACITY` |
| `~/.config/gifdesk/input.conf` | Atajos extra de mpv (editable; por defecto sin atajos activos) |
| `~/.config/autostart/gifdesk.desktop` | Autostart XDG |
| `~/.local/share/applications/gifdesk-gui.desktop` | Entrada del menu |
| `~/.config/systemd/user/gifdesk.service` | Unidad systemd (solo con `--with-systemd`) |
| `~/.cache/gifdesk/` | `gifdesk[-id].pid`, `socket[-id]`, `gifdesk.log` |

## Como funciona

- **Motor**: un proceso `mpv` por GIF (libavcodec): `--no-audio`, sin OSD ni
  atajos, loop infinito respetando el timing original, `--vo=gpu-next` con
  `hwdec=auto-safe`, instancia unica por pidfile (si ya corre, se reemplaza).
- **KDE Wayland**: posicion/tamano/opacidad se imponen con una **regla KWin**
  por instancia (titulo exacto `^gifdesk-id$`, politica aplicar-al-inicio).
  Un marcador `REV` hace que la regla solo se reescriba ante ordenes
  explicitas (Aplicar/Mostrar/guardar).
- **Bloqueo**: `input-cursor-passthrough` (+ `input-cursor=no`); en vivo por IPC
  desde la GUI, o por flags al arrancar.
- **X11**: vale `--geometry`/`--autofit` directo, sin reglas.

## Transparencia

Dos cosas distintas:

1. **Alfa del GIF/WebP**: el widget usa fondo `#00000000`, asi lo transparente
   se ve recortado. Requiere compositor con alfa (en Wayland casi siempre hay;
   en X11 necesitas Picom/Compton o el de tu DE; sin el se vera negro).
2. **Opacidad de la ventana** (slider 0-100): la aplica KWin por regla. Al 0 %
   es invisible pero sigue corriendo e interactuando (salvo bloqueado).

## Consumo

Medido con 2 GIFs (mpv 0.41, Artix):

| Instancia | CPU | RAM |
|---|---|---|
| `rem` 480x476 ~16fps | ~6,6 % de un nucleo | ~114 MB (1,4 %) |
| `ram` 168x112 | ~7,0 % de un nucleo | ~115 MB (1,4 %) |

El GIF se decodifica por CPU siempre (no hay decodificador GPU para GIF/WebP
animado en ningun reproductor); el ahorro esta en lo demas (sin audio/OSD, un
proceso por GIF, compositing en GPU). La GUI cerrada consume cero. Para bajarlo:
tamano menor, menos fps, o Detener cuando no mires.

## Autostart por entorno

| Entorno | Metodo |
|---------|--------|
| KDE, XFCE, MATE, LXQt, GNOME, Cinnamon, Openbox | XDG Autostart (`~/.config/autostart/gifdesk.desktop`) |
| Hyprland | `hl.exec_cmd(... gifdesk --autostart)` en `execs.lua` (con `--with-hypr`) |
| Minimalista / tiling sin XDG | Unidad systemd user (`--with-systemd`, `graphical-session.target`) |

> No actives XDG + systemd a la vez: verias ventanas duplicadas.

## Limitaciones conocidas

- **Arrastrar vive la sesion**: al relanzar/reiniciar vuelve a su sitio
  configurado. KWin no expone la posicion para leerla (sin `kdotool` no hay
  X/Y automatico).
- En Wayland el posicionamiento absoluto lo decide el compositor (+ regla en
  KDE); en otros Wayland sin reglas, la posicion inicial es aproximada.
- Ventana bloqueada = ignora el raton del todo (ni mover, ni rueda, ni nada).
- Opacidad 0 % = invisible pero activo (consume igual).
- `--mode wallpaper` es pantalla completa por encima (fondo falso), no fondo real.

## Solucion de problemas

- **Veo un rectangulo negro**: sin compositor, o tu archivo no tiene alfa.
  Corre `gifdesk --check --file tu.gif`.
- **No aparece al iniciar**: revisa `~/.config/autostart/gifdesk.desktop` y
  `~/.cache/gifdesk/gifdesk.log`. En Hyprland, confirma `execs.lua`.
- **mpv muere al instante**: mira el log (ruta mala o archivo corrupto).
- **Ventanas duplicadas**: XDG + systemd (o Hyprland) a la vez; o config
  clasica con FILE + instancia del mismo archivo (la GUI lo evita sola).
- **Bloquear "no hace nada"**: confirma que seleccionaste el que marca `[on]`
  y que la GUI es la actual (cierrala y abrela tras actualizar). Revisa
  `LOCKED=` en su `instances/<id>.conf`.
- **Aplicar no cambia opacidad/tamano**: espera a que el boton se reactive
  (trabaja en hilo); no pulses dos veces. Revisa el log.
- **Sospechas de regla atascada**: compara tu `instances/<id>.conf` con el
  grupo `[gifdesk-<id>]` en `~/.config/kwinrulesrc` (posicion, tamano,
  `opacityactive`, `gifdeskrev`).
- **GUI rara tras actualizar**: cierra todas sus ventanas y abre de nuevo
  (una GUI vieja abierta usa codigo viejo).

## Desinstalacion

```bash
./uninstall.sh          # conserva config y libreria
./uninstall.sh --purge  # borra tambien config y libreria
```

`uninstall.sh` detiene todo (incluido `pkill` de respaldo), quita binarios,
autostart, unidad systemd y cache. Las reglas KWin `[gifdesk-*]` se conservan
(inofensivas; se reutilizan si vuelve el id).

## Licencia

GPL-3.0. Tu GIF/WebP sigue siendo tuyo: al añadirlo se conserva el original y
la app trabaja con una copia en `~/.local/share/gifdesk/library/`.
