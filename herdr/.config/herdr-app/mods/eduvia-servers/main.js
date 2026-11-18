// Serveurs Eduvia: the front, back and Histoire dev servers of the Eduvia checkout the
// shown space works in, on this computer or on another machine (`hc machine ls`).
//
// One mod, three roles (props.role):
// - bar (default): a button in the tab bar row with a dot per server. It folds its own
//   layout block (props.block) when the shown space isn't in an Eduvia checkout.
// - popover: each server's state, start / restart / stop, its URL and its logs.
// - logs: the title bar of a log window (a server's terminal, or its log file followed).
//
// The work is in eduvia.sh, run on the checkout's machine: detection, status, and
// actions that run in a terminal of their own, so they finish when the popover closes.

import { View, div, svg } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { spaces, panes, focused, layout, theme, props, run, openOverlay, closeOverlay, terminals, hc, exec, checking, nextCommand } from "herdr";
import { SERVERS, icon, findRoot, readStatus, describe, url, openUrl, control, logSource, openLogs, slotColor } from "./servers.js";

const POPOVER_WIDTH = 400, ROW = 58, HEADER = 50;

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

// Where the shown space works: its machine, and the focused terminal's folder, its
// panes' folders, then where it was made.
function shownPlace() {
  const space = spaces().find((s) => s.active);
  if (!space) return { machine: null, folders: [] };
  const tabs = new Set(space.tabs.map((c) => c.id)), f = focused();
  const list = [f?.space === space.id ? f.cwd : null, ...panes().filter((p) => tabs.has(p.tab)).map((p) => p.cwd), space.folder];
  return { machine: space.machine ?? null, folders: [...new Set(list.filter(Boolean))] };
}

const same = (a, b) => (a?.machine ?? null) === (b?.machine ?? null) && a?.root === b?.root;
const ACTIONS = { start: "Démarrage", stop: "Arrêt", restart: "Redémarrage" };

// The address a browser here uses for a machine's Histoire: its ssh host.
const hosts = new Map();
async function hostOf(machine) {
  if (!machine) return null;
  if (!hosts.has(machine)) {
    const target = await hc(["machine", "ls", "--json"])
      .then((r) => JSON.parse(r.stdout).machines.find((m) => m.name === machine)?.target ?? machine)
      .catch(() => machine);
    const alias = target.replace(/^[^@]*@/, "").replace(/:\d+$/, "");
    const resolved = await exec("ssh", ["-G", alias]).then((r) => /^hostname (.+)$/m.exec(r.stdout)?.[1]).catch(() => null);
    hosts.set(machine, resolved || alias);
  }
  return hosts.get(machine);
}

export default class EduviaServers extends View {
  init(_p, cx) {
    // props() is only set while Herdr runs this copy's own callbacks, not after an await.
    const p = this.props = props() ?? {};
    this.role = p.role ?? "bar";
    // { machine, root } of the checkout shown; the bar follows the shown space.
    this.where = this.role === "bar" ? null : { machine: p.machine ?? null, root: p.root };
    this.status = null;
    this.optimistic = {};
    if (this.role === "logs") return;
    if (this.role === "popover") {
      this.refresh(cx);
      cx.spawn(async (cx) => { this.host = await hostOf(this.where.machine); cx.notify(); });
    }
    cx.timer.every(this.role === "popover" ? 1000 : 3000, (cx) => this.refresh(cx));
    // keys.json: "ctrl-alt-e": "eduvia-servers.servers" (or herdr-app do eduvia-servers.servers);
    // eduvia-servers.logs opens the log windows of every server that has some.
    if (this.role === "bar" && !checking()) cx.spawn(async (cx) => {
      for (;;) {
        const c = await nextCommand();
        if (c === "servers") this.open(null);
        if (c === "logs" && this.where) for (const s of this.servers()) await openLogs(this.where, s, this.slug()).catch(() => null);
      }
    });
  }

  // Under the button when clicked; centred when opened from a key.
  open(bounds) {
    if (!this.where) return;
    const height = HEADER + SERVERS.length * ROW + 12 + (this.error ? 24 : 0);
    openOverlay({
      mod: "eduvia-servers", kind: bounds ? "popup" : "dialog", width: POPOVER_WIDTH, height,
      ...(bounds ? { at: { x: Math.max(8, bounds.x + bounds.width - POPOVER_WIDTH), y: bounds.y + bounds.height + 6 } } : {}),
      props: { role: "popover", machine: this.where.machine, root: this.where.root },
    });
  }

  // A log window's own `tail -F`: ends with the window.
  async close() {
    const tail = this.props?.tail;
    if (this.role === "logs" && tail) await exec("hc", ["kill", tail]).catch(() => null);
  }

  locate(cx) {
    const place = shownPlace(), key = JSON.stringify(place);
    if (key === this.placeKey) return;
    this.placeKey = key;
    cx.spawn(async (cx) => {
      const root = await findRoot(place.machine, place.folders).catch(() => null);
      if (key !== this.placeKey) return;
      const where = root ? { machine: place.machine, root } : null;
      if (!same(where, this.where)) { this.where = where; this.status = null; this.error = null; }
      this.showBlock();
      this.refresh(cx);
      cx.notify();
    });
  }

  // Folded to 0 px rather than hidden: a hidden block never starts its mod, so after
  // a restart nothing would be left to show it again. layout() keeps the file's size,
  // not one set by a resize: the mod resizes on every change of checkout, and once
  // when it starts.
  showBlock() {
    const id = this.props.block;
    if (!id || checking() || !find(layout(), id)) return;
    const px = this.where ? (this.props.width ?? 196) : 0;
    if (this.shownPx === px) return;
    this.shownPx = px;
    run("layout.resize", { id, px });
  }

  refresh(cx) {
    const where = this.where;
    if (!where || this.loading) return;
    this.loading = true;
    cx.spawn(async (cx) => {
      try {
        const status = await readStatus(where);
        if (!same(where, this.where)) return;
        this.status = status;
        this.error = status.missing.length ? `Manque sur ${where.machine ?? "cette machine"} : ${status.missing.join(", ")}` : null;
        // An action shows as pending from the click until eduvia.sh reports it.
        const now = Date.now();
        for (const id of Object.keys(this.optimistic))
          if (status.pending[id] || now - this.optimistic[id].since > 5000) delete this.optimistic[id];
      } catch (e) { this.error = String(e.message ?? e); }
      finally { this.loading = false; cx.notify(); }
    });
  }

  act(action, s, cx) {
    this.optimistic[s.id] = { action, since: Date.now() };
    cx.spawn(async (cx) => {
      try { await control(action, this.where, s); }
      catch (e) { this.error = `${ACTIONS[action]} de ${s.name} impossible : ${e.message ?? e}`; delete this.optimistic[s.id]; }
      this.refresh(cx);
      cx.notify();
    });
    cx.notify();
  }

  servers() {
    return this.status && this.where ? describe(this.status, this.where, this.optimistic) : [];
  }

  slug() {
    return this.status?.env?.EDUVIA_ENV_SLUG ?? (this.where ? this.where.root.split("/").pop() : "");
  }

  render(cx) {
    if (this.role === "popover") return this.popover();
    if (this.role === "logs") return this.logsBar();
    this.locate(cx);
    return this.bar();
  }

  dot(s, t, size = 7) {
    if (s.state === "pending" || s.state === "starting") return svg(icon("spinner")).size(size + 3).flex_none().text_color(t.working).spin(900);
    const color = { running: t.ansi2, failed: t.ansi1, stopped: t.dim }[s.state];
    return div().size(size).flex_none().rounded(size / 2).bg(color);
  }

  // --- bar -------------------------------------------------------------------------

  bar() {
    const t = theme(), list = this.servers(), w = this.where;
    return h_flex().id("eduvia-servers-bar").size_full().px(6).items_center().justify_end().bg(t.chrome).border_b(1).border_color(t.border)
      .when(Boolean(w), (el) => el.child(h_flex().id("eduvia-servers-button").h(26).px(8).gap(6).flex_none().items_center().rounded(6)
        .text_size(12).text_color(t.muted).hover((s) => s.bg(t.hover).text_color(t.foreground)).cursor_pointer()
        .tooltip(w ? `${w.machine ? `${w.machine}:` : ""}${w.root}` : "")
        .on_mouse_down("left", (e, cx) => { cx.stop_propagation(); this.open(e.bounds ?? null); })
        .child(svg(icon("server")).size(14))
        .child("Serveurs Eduvia")
        .child(h_flex().gap(3).items_center().children(list.map((s) => this.dot(s, t, 6))))));
  }

  // --- popover ---------------------------------------------------------------------

  button(id, name, tip, color, action) {
    const t = theme();
    return div().id(id).size(26).flex_none().flex().items_center().justify_center().rounded(6).text_color(color ?? t.muted)
      .when(Boolean(action), (el) => el.cursor_pointer().hover((s) => s.bg(t.hover).text_color(t.foreground)).on_click(action))
      .when(!action, (el) => el.opacity(0.35))
      .tooltip(tip).child(svg(icon(name)).size(14));
  }

  subtitle(s, t, env) {
    if (s.state === "pending") {
      const secs = Math.max(0, Math.round((Date.now() - s.pending.since) / 1000));
      const what = s.pending.action === "stop" ? "Arrêt" : s.id === "back" ? "Migrations puis démarrage" : ACTIONS[s.pending.action];
      return div().text_color(t.working).child(`${what}… ${secs}s`);
    }
    if (s.error && s.state !== "running") return div().text_color(t.ansi1).truncate().tooltip(s.error).child(s.error);
    if (s.state === "starting") return div().text_color(t.working).child("Démarrage…");
    if (s.state === "stopped") return div().text_color(t.dim).child(s.id === "back" ? `Arrêté · port ${s.port} · db:migrate au démarrage` : `Arrêté · port ${s.port}`);
    const link = url(s, env, this.host);
    return h_flex().gap(6).min_w(0)
      .child(div().id(`url-${s.id}`).truncate().text_color(t.muted).cursor_pointer().hover((st) => st.text_color(t.accent))
        .tooltip("Ouvrir dans le navigateur").on_click(() => openUrl(link)).child(link.replace(/^https?:\/\//, "")))
      .when(s.id === "histoire" && s.exposed === false, (el) => el.child(div().flex_none().text_color(t.ansi3).tooltip("Écoute en local seulement : redémarre-le pour l’exposer sur 0.0.0.0").child("local")))
      .when(s.how === "external", (el) => el.child(div().flex_none().text_color(t.dim).tooltip("Lancé hors de Herdr ou par un agent").child("externe")));
  }

  row(s, t, env) {
    const busy = s.state === "pending";
    const up = s.state === "running" || s.state === "starting";
    const logs = logSource(s);
    const act = (action) => busy ? null : (_e, cx) => this.act(action, s, cx);
    return h_flex().h(ROW).px(12).gap(10).items_center().rounded(8).hover((st) => st.bg(t.hover))
      .child(div().w(12).flex().justify_center().child(this.dot(s, t, 8)))
      .child(v_flex().flex_1().min_w(0).gap(2)
        .child(h_flex().gap(6).items_center().child(div().font_semibold().text_color(t.foreground).child(s.name)))
        .child(div().text_size(11.5).min_w(0).child(this.subtitle(s, t, env))))
      .when(!up, (el) => el.child(this.button(`start-${s.id}`, "play", s.id === "back" ? "Démarrer (rails db:migrate puis rails s)" : "Démarrer", t.ansi2, act("start"))))
      .when(up, (el) => el
        .child(this.button(`restart-${s.id}`, "restart", s.id === "back" ? "Redémarrer (avec rails db:migrate)" : "Redémarrer", null, act("restart")))
        .child(this.button(`stop-${s.id}`, "stop", "Arrêter", t.ansi1, act("stop"))))
      .child(this.button(`logs-${s.id}`, "logs", logs ? "Logs" : "Pas de logs : lancé hors de Herdr", null,
        logs ? (_e, cx) => cx.spawn(async () => { await openLogs(this.where, s, this.slug()).catch(() => null); }) : null));
  }

  popover() {
    const t = theme(), env = this.status?.env ?? {};
    const slot = Number(env.EDUVIA_ENV_SLOT), machine = this.where?.machine;
    return v_flex().size_full().bg(t.popover).p(6).text_size(13).text_color(t.foreground)
      .child(h_flex().h(HEADER - 12).px(10).gap(8).items_center()
        .child(div().size(10).rounded(5).flex_none().bg(slot ? slotColor(slot) : t.accent))
        .child(div().font_semibold().child(this.slug()))
        .when(Boolean(machine), (el) => el.child(div().px(5).rounded(4).border_1().border_color(t.border).text_size(10.5).text_color(t.muted).child(machine)))
        .child(div().flex_1().min_w(0).truncate().text_size(11.5).text_color(t.dim).child(env.EDUVIA_ENV_BRANCH ?? this.where?.root ?? "")))
      .child(div().h(1).mx(4).mb(4).bg(t.border))
      .when(!this.status && !this.error, (el) => el.child(div().p(12).text_color(t.dim).child("Lecture de l’état…")))
      .children(this.servers().map((s) => this.row(s, t, env)))
      .when(Boolean(this.error), (el) => el.child(div().px(12).py(4).text_size(11.5).text_color(t.ansi1).truncate().tooltip(this.error).child(this.error)));
  }

  // --- log window title bar --------------------------------------------------------

  logsBar() {
    const t = theme(), p = props() ?? {};
    const term = terminals().find((x) => x.address === p.terminal);
    const live = term?.state === "live";
    const stop = (_e, cx) => cx.stop_propagation();
    const tool = (id, name, tip, action) => div().id(id).size(24).flex_none().flex().items_center().justify_center().rounded(5)
      .text_color(t.muted).cursor_pointer().hover((s) => s.bg(t.hover).text_color(t.foreground))
      .on_mouse_down("left", stop).on_click(action).tooltip(tip).child(svg(icon(name)).size(13));
    // A server terminal goes to a tab; the shell one is already in a pane.
    const hasPane = panes().some((x) => x.terminal === p.terminal);
    const title = `${p.name} · ${p.title}${p.machine ? ` · ${p.machine}` : ""}`;
    return h_flex().size_full().px(10).gap(8).items_center().bg(t.chrome).border_b(1).border_color(t.border).text_size(12)
      .child(div().size(7).rounded(4).flex_none().bg(live ? t.ansi2 : t.dim))
      .child(div().font_semibold().text_color(t.foreground).child(title))
      .child(div().flex_1().min_w(0).truncate().text_color(t.dim).child(p.file ? p.file.replace(`${p.root}/`, "") : p.terminal))
      .when(!p.tail && live, (el) => el.child(tool("to-tab", "tab", hasPane ? "Aller au terminal" : "Ouvrir dans un onglet", () => {
        closeOverlay(p.overlay);
        if (hasPane) run("pane.focus", { terminal: p.terminal });
        else run("terminal.keep", { terminal: p.terminal });
      })))
      .child(tool("close", "x", "Fermer", () => closeOverlay(p.overlay)));
  }
}
