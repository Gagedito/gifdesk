// gifdesk widgets — motor GNOME Shell (GPL-3.0-or-later).
// Dibuja cada GIF/WebP como un ACTOR Clutter (no como ventana): no aparece
// en el dock/panel, ni en el alt-tab, ni en el taskbar. Siempre encima,
// en todos los escritorios, con opacidad real y arrastre con el ratón.
//
// Los cuadros los pre-extrae `gifdesk` (bash+ffmpeg) a
// ~/.cache/gifdesk/frames/<sha1_WxH>/f*.png + durations.txt; la extensión
// solo los carga (PNG estáticos: fiable con cualquier formato) y anima.
//
// D-Bus: org.gifdesk.Widgets en /org/gifdesk/Widgets
//   Show(id, file, framesDir, durs, pos, w, h, locked, opacity) -> bool
//     durs: "ms ms ..." por cuadro — pos: BR|BL|TR|TL|C|"X,Y"
//     w/h 0 = nativo del PNG
//   Stop(id) -> bool | StopAll() -> bool
//   IsShowing(id) -> bool | List() -> ids o "NONE"
//   Geometry(id|"") -> "ID X Y W H" por línea, o "NONE"
//   SetLocked(id, lock) -> bool  (lock = ignora el ratón)
// El autostart lo dispara `gifdesk --autostart` (XDG), no la extensión.

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const BUS = 'org.gifdesk.Widgets';
const OBJ = '/org/gifdesk/Widgets';
const IFACE = `
<node>
  <interface name="org.gifdesk.Widgets">
    <method name="Show">
      <arg type="s" name="id" direction="in"/>
      <arg type="s" name="file" direction="in"/>
      <arg type="s" name="framesDir" direction="in"/>
      <arg type="s" name="durs" direction="in"/>
      <arg type="s" name="pos" direction="in"/>
      <arg type="i" name="w" direction="in"/>
      <arg type="i" name="h" direction="in"/>
      <arg type="b" name="locked" direction="in"/>
      <arg type="i" name="opacity" direction="in"/>
      <arg type="b" name="ok" direction="out"/>
    </method>
    <method name="Stop">
      <arg type="s" name="id" direction="in"/>
      <arg type="b" name="ok" direction="out"/>
    </method>
    <method name="StopAll">
      <arg type="b" name="ok" direction="out"/>
    </method>
    <method name="IsShowing">
      <arg type="s" name="id" direction="in"/>
      <arg type="b" name="showing" direction="out"/>
    </method>
    <method name="List">
      <arg type="s" name="ids" direction="out"/>
    </method>
    <method name="Geometry">
      <arg type="s" name="id" direction="in"/>
      <arg type="s" name="rects" direction="out"/>
    </method>
    <method name="SetLocked">
      <arg type="s" name="id" direction="in"/>
      <arg type="b" name="lock" direction="in"/>
      <arg type="b" name="ok" direction="out"/>
    </method>
  </interface>
</node>`;

const MARGIN = 16;
const MAX_FRAMES = 300;

function resolveXY(pos, w, h) {
    const mon = Main.layoutManager.primaryMonitor;
    const p = (pos || 'BR').toUpperCase();
    let x = mon.x + mon.width - w - MARGIN;
    let y = mon.y + mon.height - h - MARGIN;
    if (p === 'BL') {
        x = mon.x + MARGIN;
        y = mon.y + mon.height - h - MARGIN;
    } else if (p === 'TR') {
        x = mon.x + mon.width - w - MARGIN;
        y = mon.y + MARGIN;
    } else if (p === 'TL') {
        x = mon.x + MARGIN;
        y = mon.y + MARGIN;
    } else if (p === 'C' || p === 'CENTER' || p === '') {
        x = mon.x + Math.round((mon.width - w) / 2);
        y = mon.y + Math.round((mon.height - h) / 2);
    } else if (p.includes(',')) {
        const [sx, sy] = p.split(',');
        x = mon.x + Math.max(0, parseInt(sx, 10) || 0);
        y = mon.y + Math.max(0, parseInt(sy, 10) || 0);
    }
    return [Math.round(x), Math.round(y)];
}

function loadStills(dir, dursCsv, W, H) {
    // PNGs pre-extraidos (fNNN.png) + duraciones "ms ms ...".
    // Solo rutas: las pinta St.Icon (el widget de imagen del propio Shell,
    // con caché de texturas integrada). Nada de Canvas ni decodificadores.
    const pngs = [];
    let durs = String(dursCsv || '').trim().split(/\s+/).map(x => {
        const n = parseInt(x, 10);
        return n >= 20 && n <= 2000 ? n : 100;
    });
    try {
        const d = Gio.File.new_for_path(dir);
        const en = d.enumerate_children('standard::name',
            Gio.FileQueryInfoFlags.NONE, null);
        const names = [];
        let info;
        while ((info = en.next_file(null)) !== null) {
            const nm = info.get_name();
            if (/^f\d+\.png$/.test(nm))
                names.push(nm);
        }
        names.sort();
        for (const nm of names.slice(0, MAX_FRAMES)) {
            const p = GLib.build_filenamev([dir, nm]);
            if (GLib.file_test(p, GLib.FileTest.EXISTS))
                pngs.push(p);
        }
    } catch (e) {
        return null;
    }
    if (!pngs.length || !(W > 0 && H > 0))
        return null;
    while (durs.length < pngs.length)
        durs.push(100);
    durs = durs.slice(0, pngs.length);
    return { pngs, durs, w: W, h: H };
}

export default class GifdeskWidgetsExtension {
    enable() {
        this._live = new Map();
        this._impl = {
            Show: (id, file, framesDir, durs, pos, w, h, locked, opacity) =>
                this._show(id, file, framesDir, durs, pos, w, h, locked, opacity),
            Stop: id => this._stop(id),
            StopAll: () => {
                for (const id of [...this._live.keys()])
                    this._stop(id);
                return true;
            },
            IsShowing: id => this._live.has(id),
            List: () => {
                const ids = [...this._live.keys()];
                return ids.length ? ids.join('\n') : 'NONE';
            },
            Geometry: id => this._geometry(id),
            SetLocked: (id, lock) => {
                const inst = this._live.get(id);
                if (!inst)
                    return false;
                try {
                    inst.actor.reactive = !lock;
                    return true;
                } catch (e) {
                    return false;
                }
            },
        };
        this._dbus = Gio.DBusExportedObject.wrapJSObject(IFACE, this._impl);
        this._dbus.export(Gio.DBus.session, OBJ);
        this._busName = Gio.bus_own_name_on_connection(
            Gio.DBus.session, BUS, Gio.BusNameOwnerFlags.NONE, null, null);
        // Sin autostart propio: `gifdesk --autostart` (XDG) levanta cada
        // instancia via Show tras cargar la sesión.
    }

    disable() {
        for (const id of [...this._live.keys()]) {
            try {
                this._stop(id);
            } catch (e) {
                log(`gifdesk: error al detener ${id}: ${e}`);
            }
        }
        this._live = new Map();
        if (this._busName) {
            try {
                Gio.bus_unown_name(this._busName);
            } catch (e) {
                log(`gifdesk: error al liberar D-Bus: ${e}`);
            }
            this._busName = 0;
        }
        if (this._dbus) {
            try {
                this._dbus.unexport();
            } catch (e) {
                log(`gifdesk: error al retirar D-Bus: ${e}`);
            }
            this._dbus = null;
        }
        this._impl = null;
    }

    _show(id, file, framesDir, dursCsv, pos, w, h, locked, opacity) {
        if (!id || !framesDir || !(w > 0 && h > 0))
            return false;
        this._stop(id);
        const data = loadStills(framesDir, dursCsv, w, h);
        if (!data)
            return false;
        const [x, y] = resolveXY(pos, data.w, data.h);
        // St.Icon: el widget de imagen del propio Shell (dash, OSD, avisos
        // lo usan). Por cuadro se cambia el gicon; la caché de texturas
        // evita re-decodificar. El PNG ya viene al tamaño final.
        const icons = data.pngs.map(p =>
            Gio.FileIcon.new(Gio.File.new_for_path(p)));
        const actor = new St.Icon({
            gicon: icons[0],
            icon_size: Math.max(data.w, data.h),
            reactive: !locked,
            track_hover: false,
        });
        actor.set_size(data.w, data.h);
        let op = parseInt(opacity, 10);
        if (!(op >= 0))
            op = 100;
        actor.set_opacity(Math.round(Math.max(0, Math.min(100, op)) * 2.55));
        actor.set_position(x, y);
        // Arrastre siempre conectado: solo responde si está desbloqueado
        // (reactive), para que SetLocked en vivo no pierda el arrastre.
        this._draggable(actor);
        // Capa propia encima de las ventanas (no es una ventana: sin dock,
        // sin alt-tab, sin taskbar). Visible en todos los escritorios.
        Main.uiGroup.add_child(actor);
        Main.uiGroup.set_child_above_sibling(actor, null);
        const inst = {
            id, actor, icons, durs: data.durs, idx: 0, timer: 0,
        };
        this._live.set(id, inst);
        if (data.pngs.length > 1)
            this._schedule(inst);
        return true;
    }

    _schedule(inst) {
        const step = () => {
            if (this._live.get(inst.id) !== inst)
                return GLib.SOURCE_REMOVE;
            inst.idx = (inst.idx + 1) % inst.icons.length;
            try {
                inst.actor.set_gicon(inst.icons[inst.idx]);
            } catch (e) {
                return GLib.SOURCE_REMOVE;
            }
            inst.timer = GLib.timeout_add(GLib.PRIORITY_DEFAULT,
                inst.durs[inst.idx] || 100, step);
            return GLib.SOURCE_REMOVE;
        };
        inst.timer = GLib.timeout_add(GLib.PRIORITY_DEFAULT,
            inst.durs[0] || 100, step);
    }

    _stop(id) {
        const inst = this._live.get(id);
        if (!inst)
            return false;
        try {
            if (inst.timer)
                GLib.source_remove(inst.timer);
        } catch (e) {
            // temporizador ya ido
        }
        try {
            Main.uiGroup.remove_child(inst.actor);
            inst.actor.destroy();
        } catch (e) {
            // actor ya retirado
        }
        this._live.delete(id);
        return true;
    }

    _geometry(id) {
        const lines = [];
        for (const [key, inst] of this._live) {
            if (id && key !== id)
                continue;
            try {
                const [x, y] = inst.actor.get_position();
                const [w, h] = inst.actor.get_size();
                lines.push(`${key} ${Math.round(x)} ${Math.round(y)} ${Math.round(w)} ${Math.round(h)}`);
            } catch (e) {
                // actor a medio destruir
            }
        }
        return lines.length ? lines.join('\n') : 'NONE';
    }

    _draggable(actor) {
        let dragging = false, dx = 0, dy = 0;
        actor.connect('button-press-event', (a, e) => {
            if (!a.reactive)
                return Clutter.EVENT_PROPAGATE;
            const [x, y] = e.get_coords();
            const [ax, ay] = a.get_position();
            dx = x - ax;
            dy = y - ay;
            dragging = true;
            return Clutter.EVENT_STOP;
        });
        actor.connect('motion-event', (a, e) => {
            if (!dragging)
                return Clutter.EVENT_PROPAGATE;
            const [x, y] = e.get_coords();
            a.set_position(Math.round(x - dx), Math.round(y - dy));
            return Clutter.EVENT_STOP;
        });
        const end = () => {
            dragging = false;
            return Clutter.EVENT_STOP;
        };
        actor.connect('button-release-event', end);
        actor.connect('leave-event', () => {
            dragging = false;
            return Clutter.EVENT_PROPAGATE;
        });
    }
}
