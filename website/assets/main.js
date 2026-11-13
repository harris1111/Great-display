// Great Display website: interactive menu demo, film controls, terminal, reveals.

document.documentElement.classList.remove("no-js");

const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

// ---------- Icons (24 × 24 stroke icons) ----------

const ICONS = {
  sun: '<circle cx="12" cy="12" r="4.2" fill="currentColor"/><path d="M12 2.5v2M12 19.5v2M4.6 4.6l1.4 1.4M18 18l1.4 1.4M2.5 12h2M19.5 12h2M4.6 19.4L6 18M18 6l1.4-1.4"/>',
  sunMin: '<circle cx="12" cy="12" r="3.6" fill="currentColor"/><path d="M12 5v.5M12 18.5v.5M7 7l.4.4M16.6 16.6l.4.4M5 12h.5M18.5 12h.5M7 17l.4-.4M16.6 7.4L17 7"/>',
  resize: '<path d="M14 4h6v6M10 20H4v-6M20 4l-6.5 6.5M4 20l6.5-6.5"/>',
  display: '<rect x="2.5" y="4" width="19" height="13" rx="2"/><path d="M8 21h8M12 17v4"/>',
  laptop: '<rect x="4.5" y="5" width="15" height="10.5" rx="1.5"/><path d="M2 19h20"/>',
  dashed: '<rect x="3" y="5" width="18" height="14" rx="2" stroke-dasharray="3.2 2.6"/>',
  contrast: '<circle cx="12" cy="12" r="8.5"/><path d="M12 3.5a8.5 8.5 0 0 1 0 17z" fill="currentColor"/>',
  speaker: '<path d="M4 9.5v5h3.5L12 18V6L7.5 9.5z" fill="currentColor"/><path d="M15.5 9a4.2 4.2 0 0 1 0 6M18 6.5a8 8 0 0 1 0 11"/>',
  mute: '<path d="M4 9.5v5h3.5L12 18V6L7.5 9.5z" fill="currentColor"/><path d="M16 9.5l5 5M21 9.5l-5 5"/>',
  moon: '<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/>',
  sparkles: '<path d="M11 3l1.7 4.8L17.5 9.5l-4.8 1.7L11 16l-1.7-4.8L4.5 9.5l4.8-1.7zM18 15l.8 2.2L21 18l-2.2.8L18 21l-.8-2.2L15 18l2.2-.8z"/>',
  gear: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>',
  power: '<path d="M12 3v8.5M6.3 6.8a8 8 0 1 0 11.4 0"/>',
  check: '<path d="M5 12.5l4.5 4.5L19 7"/>',
  play: '<path d="M7 4.5v15l13-7.5z" fill="currentColor" stroke="none"/>',
  pause: '<path d="M6.5 4h4v16h-4zM13.5 4h4v16h-4z" fill="currentColor" stroke="none"/>',
  replay: '<path d="M4 12a8 8 0 1 0 2.4-5.7L4 8.5M4 4v4.5h4.5"/>',
  cable: '<path d="M9 2.5v4M15 2.5v4M6.5 6.5h11v4.5a5.5 5.5 0 0 1-11 0zM12 16.5v5"/>',
  reset: '<path d="M4 12a8 8 0 1 0 2.4-5.7L4 8.5M4 4v4.5h4.5"/>',
  filters: '<circle cx="9" cy="9.5" r="5.5"/><circle cx="15" cy="9.5" r="5.5"/><circle cx="12" cy="14.5" r="5.5"/>',
  link: '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
  mirror: '<rect x="2" y="5" width="12" height="9" rx="1.5"/><rect x="10" y="10" width="12" height="9" rx="1.5"/>',
  eye: '<path d="M2 12s3.6-6.5 10-6.5S22 12 22 12s-3.6 6.5-10 6.5S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
  wifi: '<path d="M2.5 9a14 14 0 0 1 19 0M5.5 12.3a9.5 9.5 0 0 1 13 0M8.6 15.5a5 5 0 0 1 6.8 0"/><circle cx="12" cy="18.6" r="1" fill="currentColor"/>',
  battery: '<rect x="2" y="7" width="18" height="10" rx="2.5"/><rect x="4" y="9" width="11" height="6" rx="1" fill="currentColor"/><path d="M22 10.5v3"/>',
};

function svg(name) {
  return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[name] || ""}</svg>`;
}

function fromHTML(html) {
  const t = document.createElement("template");
  t.innerHTML = html.trim();
  return t.content.firstElementChild;
}

// ---------- Capsule slider ----------

function capsuleSlider({ value, icon, label, markers = [], steps = 0, commitOnRelease = false, onInput, onCommit, name }) {
  const el = fromHTML(`<div class="cs" role="slider" tabindex="0" aria-label="${name}" aria-valuemin="0" aria-valuemax="100">
      <span class="lbl"></span><div class="fill"></div><span class="lbl dark"></span>
      ${markers.map((m) => `<i class="mk" data-m="${m.at}" title="${m.label}" style="left:calc(13px + (100% - 26px) * ${m.at} - 0.75px)"></i>`).join("")}
      <span class="ico"></span></div>`);
  const fill = el.querySelector(".fill");
  const light = el.querySelector(".lbl:not(.dark)");
  const dark = el.querySelector(".lbl.dark");
  const ico = el.querySelector(".ico");
  const marks = [...el.querySelectorAll(".mk")];
  let current = value;

  const quantize = (v) => {
    v = Math.min(1, Math.max(0, v));
    return steps ? Math.round(v * steps) / steps : v;
  };

  function paint(v) {
    fill.style.width = `calc(26px + (100% - 26px) * ${v})`;
    const text = label ? label(v) : "";
    light.textContent = text;
    dark.textContent = text;
    const w = el.clientWidth || 300;
    const fillPx = 26 + (w - 26) * v;
    dark.style.left = "0";
    dark.style.right = "10px";
    dark.style.textAlign = "right";
    dark.style.clipPath = `inset(0 ${Math.max(0, w - 10 - fillPx)}px 0 0)`;
    ico.innerHTML = svg(typeof icon === "function" ? icon(v) : icon);
    marks.forEach((m) => m.classList.toggle("on", +m.dataset.m <= v));
    el.setAttribute("aria-valuenow", Math.round(v * 100));
    el.setAttribute("aria-valuetext", text || `${Math.round(v * 100)}%`);
  }

  function fromEvent(e) {
    const r = el.getBoundingClientRect();
    return quantize((e.clientX - r.left - 13) / Math.max(1, r.width - 26));
  }

  let dragging = false;
  el.addEventListener("pointerdown", (e) => {
    dragging = true;
    el.setPointerCapture(e.pointerId);
    el.classList.remove("anim");
    move(e);
  });
  el.addEventListener("pointermove", (e) => { if (dragging) move(e); });
  const end = () => {
    if (!dragging) return;
    dragging = false;
    if (commitOnRelease && onCommit) onCommit(current);
  };
  el.addEventListener("pointerup", end);
  el.addEventListener("pointercancel", end);

  function move(e) {
    const v = fromEvent(e);
    if (v === current) return;
    current = v;
    paint(v);
    onInput && onInput(v);
  }

  el.addEventListener("keydown", (e) => {
    const step = steps ? 1 / steps : 0.05;
    const map = { ArrowRight: step, ArrowUp: step, ArrowLeft: -step, ArrowDown: -step, PageUp: step * 2, PageDown: -step * 2 };
    let v = current;
    if (e.key in map) v = quantize(current + map[e.key]);
    else if (e.key === "Home") v = 0;
    else if (e.key === "End") v = 1;
    else return;
    e.preventDefault();
    current = v;
    paint(v);
    onInput && onInput(v);
    if (commitOnRelease && onCommit) onCommit(v);
  });

  requestAnimationFrame(() => paint(current));
  paint(current);
  return {
    el,
    set(v, animate = true) {
      current = quantize(v);
      el.classList.toggle("anim", animate);
      paint(current);
    },
    repaint() { paint(current); },
  };
}

// ---------- Interactive demo ----------

(function demo() {
  const root = document.getElementById("demo");
  if (!root) return;

  const RES = [
    ["1024 × 665", 1024], ["1147 × 745", 1147], ["1312 × 852", 1312], ["1512 × 982", 1512],
    ["1710 × 1112", 1710], ["1800 × 1169", 1800], ["2056 × 1329", 2056],
  ];
  const RATIOS = {
    "16:9": [16 / 9, ["1280 × 720", "1920 × 1080", "2560 × 1440", "3840 × 2160", "5120 × 2880", "7680 × 4320", "15360 × 8640"]],
    "16:10": [16 / 10, ["1280 × 800", "1680 × 1050", "2560 × 1600", "3840 × 2400", "5120 × 3200", "7680 × 4800"]],
    "21:9": [21 / 9, ["2560 × 1080", "3440 × 1440", "5120 × 2160", "7680 × 3200", "10240 × 4320"]],
    "32:9": [32 / 9, ["3840 × 1080", "5120 × 1440", "7680 × 2160", "10240 × 2880", "15360 × 4320"]],
  };
  const PICTURE = { Standard: "saturate(1)", Vivid: "saturate(1.45)", Cinema: "saturate(0.8) sepia(0.15)", sRGB: "saturate(0.92)" };
  const INPUTS = ["DisplayPort 1", "HDMI 1", "USB-C"];

  const COPY = {
    brightness: ["One slider, three kinds of brightness.",
      "Above the Min HW marker the slider drives the panel itself: natively on Apple displays, over DDC/CI on external monitors. Below it, Great Display keeps going with software dimming, past the hardware minimum. Drag it all the way down."],
    resolution: ["Every scaled mode, one step at a time.",
      "Each step is a real resolution the display supports. The new mode applies when you let go, with a quick fade. The HiDPI row switches between the pixel-doubled and low-density version of the same size."],
    virtual: ["A display that isn't there.",
      "Create virtual screens from aspect-ratio presets or a custom ratio, with about forty sizes each and an optional 16K ceiling. Mirror them, stream them, or connect them automatically when a physical display appears."],
    monitor: ["Your monitor's buttons, without the buttons.",
      "Great Display reads the monitor's DDC/CI capabilities and offers its own controls: contrast, volume and mute, input source, picture modes and colour presets. Try switching the input."],
    colors: ["Colour, at a glance.",
      "Dark Mode, Night Shift and True Tone sit in the same menu, next to per-display image adjustments such as colour temperature and invert."],
  };

  const state = {
    tab: "brightness",
    brightness: 0.8,
    res: 3, hidpi: true, hz: 120,
    vsOn: true, ratio: "21:9", vsSize: 2, vsMirror: false, vsAuto: true,
    contrast: 0.55, volume: 0.35, muted: false, input: "DisplayPort 1", picture: "Standard",
    dark: true, night: false, trueTone: true, invert: false, temperature: 0.5,
  };

  const $ = (sel) => root.querySelector(sel);
  const stage = $(".stage");
  const screenWrap = $(".screen-wrap");
  const desktop = $(".desktop");
  const glass = $(".screen-glass");
  const menu = $(".menu");
  const osd = $(".osd");
  const vscreen = $(".vscreen");
  const ov = (name) => $(".ov-" + name);

  // ----- desktop -----

  function applyScale() {
    const s = 1512 / RES[state.res][1];
    desktop.style.width = `${100 / s}%`;
    desktop.style.height = `${100 / s}%`;
    desktop.style.transform = `scale(${s})`;
  }

  function applyDesktop() {
    const monitor = state.tab === "monitor";
    screenWrap.classList.toggle("external", monitor);
    stage.classList.toggle("with-virtual", state.tab === "virtual");
    $(".screen-wrap .screen-label").textContent = monitor ? "LG UltraFine 5K · DDC/CI" : `Built-in Retina Display · looks like ${RES[state.res][0]}`;

    ov("dim").style.opacity = monitor ? 0 : ((1 - state.brightness) * 0.82).toFixed(3);
    desktop.classList.toggle("lodpi", !state.hidpi && !monitor);
    desktop.classList.toggle("light", !state.dark);
    ov("night").style.opacity = state.night ? 1 : 0;
    ov("truetone").style.opacity = state.trueTone ? 1 : 0;
    const warm = state.temperature < 0.5;
    const tempStrength = Math.abs(state.temperature - 0.5) * 1.6;
    ov("temp").style.background = warm ? "rgba(255,150,40,0.55)" : "rgba(90,160,255,0.55)";
    ov("temp").style.opacity = tempStrength.toFixed(3);

    const filters = [];
    if (monitor) {
      filters.push(`contrast(${(0.45 + state.contrast * 0.95).toFixed(3)})`, PICTURE[state.picture]);
    }
    if (state.invert) filters.push("invert(1) hue-rotate(180deg)");
    glass.style.filter = filters.join(" ");

    const noSignal = monitor && state.input !== "DisplayPort 1";
    ov("nosignal").style.opacity = noSignal ? 1 : 0;
    ov("nosignal").querySelector("strong").textContent = state.input;

    const [ratio, sizes] = RATIOS[state.ratio];
    vscreen.style.aspectRatio = String(ratio);
    vscreen.classList.toggle("off", !state.vsOn);
    vscreen.querySelector("span").textContent = state.vsOn
      ? `${sizes[Math.min(state.vsSize, sizes.length - 1)]} · ${state.ratio}${state.vsMirror ? " · mirroring" : ""}`
      : "Disconnected";
  }

  let osdTimer;
  function showOSD(icon, value) {
    osd.querySelector(".osd-icon").innerHTML = svg(icon);
    osd.querySelector(".bar i").style.width = `${Math.round(value * 100)}%`;
    osd.classList.add("show");
    clearTimeout(osdTimer);
    osdTimer = setTimeout(() => osd.classList.remove("show"), 1300);
  }

  function changeResolution(index) {
    if (index === state.res) return;
    state.res = index;
    if (reduceMotion) { applyScale(); applyDesktop(); refresh(); return; }
    ov("switch").style.opacity = 1;
    setTimeout(() => {
      applyScale();
      applyDesktop();
      refresh();
      ov("switch").style.opacity = 0;
    }, 300);
  }

  // ----- menu building blocks -----

  function header({ icon, name, badge, sub, on, onSwitch, id, onClick }) {
    const el = fromHTML(`<div class="dev">
      <span class="badge-icon${on ? "" : " off"}">${svg(icon)}</span>
      <div class="names"><div class="name">${name}${badge ? `<small>${badge}</small>` : ""}</div><div class="sub" ${id ? `data-sub="${id}"` : ""}>${sub}</div></div>
      <button class="switch" role="switch" aria-checked="${on}" aria-label="Connect ${name}"></button></div>`);
    el.querySelector(".switch").addEventListener("click", (e) => {
      if (!onSwitch) return;
      const next = e.currentTarget.getAttribute("aria-checked") !== "true";
      onSwitch(next);
    });
    if (onClick) {
      el.querySelector(".names").style.cursor = "pointer";
      el.querySelector(".names").addEventListener("click", onClick);
    }
    return el;
  }

  function divider() { return fromHTML('<div class="mdiv"></div>'); }
  function cap(text) { return fromHTML(`<div class="mcap">${text}</div>`); }
  function note(id) { return fromHTML(`<div class="mnote" data-note="${id}" aria-live="polite"></div>`); }

  function checkRow(icon, title, checked, onToggle) {
    const el = fromHTML(`<button class="mrow" role="menuitemcheckbox" aria-checked="${checked}">
      <span class="check">${svg("check")}</span>${svg(icon)}<span>${title}</span></button>`);
    el.addEventListener("click", () => onToggle(el.getAttribute("aria-checked") !== "true"));
    return el;
  }

  function switchRow(icon, title, on, onToggle) {
    const el = fromHTML(`<div class="mrow sw">${svg(icon)}<span>${title}</span>
      <button class="switch" role="switch" aria-checked="${on}" aria-label="${title}"></button></div>`);
    el.querySelector(".switch").addEventListener("click", (e) => onToggle(e.currentTarget.getAttribute("aria-checked") !== "true"));
    return el;
  }

  function radioRow(icon, title, checked, onPick) {
    const el = fromHTML(`<button class="mrow" role="menuitemradio" aria-checked="${checked}">
      <span class="check">${svg("check")}</span>${svg(icon)}<span>${title}</span></button>`);
    el.addEventListener("click", onPick);
    return el;
  }

  function chips(options, current, onPick, label) {
    const el = fromHTML(`<div class="chips" role="group" aria-label="${label}"></div>`);
    for (const o of options) {
      const b = fromHTML(`<button class="chip" aria-pressed="${o === current}">${o}</button>`);
      b.addEventListener("click", () => onPick(o));
      el.append(b);
    }
    return el;
  }

  function bottomBar() {
    return fromHTML(`<div><div class="mdiv"></div><div class="menu-bottom">${svg("gear")}${svg("power")}</div></div>`);
  }

  function set(patch) {
    Object.assign(state, patch);
    applyDesktop();
    refresh();
  }

  // ----- tabs -----

  const builders = {
    brightness() {
      const nodes = [
        header({ icon: "laptop", name: "Built-in Retina Display", badge: "HiDPI", sub: `${RES[state.res][0]} · ${state.hz} Hz`, on: true }),
      ];
      const s = capsuleSlider({
        name: "Brightness", value: state.brightness,
        icon: (v) => (v < 0.3 ? "sunMin" : "sun"),
        label: (v) => `${Math.round(v * 100)}%`,
        markers: [{ at: 0.3, label: "Min HW" }],
        onInput: (v) => { state.brightness = v; applyDesktop(); updateNote(); },
      });
      nodes.push(s.el, note("brightness"));
      const reset = checkRow("reset", "Reset Brightness and Dimming", false, () => {
        state.brightness = 0.8; s.set(0.8); applyDesktop(); updateNote();
      });
      reset.removeAttribute("aria-checked");
      reset.querySelector(".check").remove();
      reset.setAttribute("role", "menuitem");
      nodes.push(reset, divider(),
        header({ icon: "display", name: "LG UltraFine 5K", sub: "5120 × 2880 · DDC/CI", on: true, onClick: () => selectTab("monitor") }),
        divider(),
        header({ icon: "dashed", name: "Virtual Screen", sub: `Virtual screen · ${RATIOS[state.ratio][1][state.vsSize]}`, on: state.vsOn, onClick: () => selectTab("virtual"), onSwitch: (on) => set({ vsOn: on }) }));
      function updateNote() {
        const v = state.brightness;
        const text = v >= 0.3
          ? `Hardware brightness ${Math.round(((v - 0.3) / 0.7) * 100)}% · no software dimming`
          : `Hardware at its minimum · software dimming ${Math.round(((0.3 - v) / 0.3) * 100)}%`;
        menu.querySelector('[data-note="brightness"]').textContent = text;
      }
      return { nodes, after: updateNote };
    },

    resolution() {
      const nodes = [header({ icon: "laptop", name: "Built-in Retina Display", badge: state.hidpi ? "HiDPI" : "", id: "res", sub: `${RES[state.res][0]} · ${state.hz} Hz`, on: true })];
      const s = capsuleSlider({
        name: "Resolution", value: state.res / 6, steps: 6, commitOnRelease: true,
        icon: "resize", label: (v) => RES[Math.round(v * 6)][0],
        markers: [{ at: 3 / 6, label: "Default" }, { at: 1, label: "Native" }],
        onInput: (v) => updateNote(Math.round(v * 6)),
        onCommit: (v) => changeResolution(Math.round(v * 6)),
      });
      nodes.push(s.el, note("res"),
        checkRow("sparkles", "High Resolution (HiDPI)", state.hidpi, (on) => set({ hidpi: on })),
        cap("Refresh rate"),
        chips(["60 Hz", "120 Hz"], `${state.hz} Hz`, (o) => set({ hz: parseInt(o, 10) }), "Refresh rate"));
      function updateNote(index = state.res) {
        const tag = index === 3 ? " · Default" : index === 6 ? " · Native" : "";
        const pending = index !== state.res ? " · release to apply" : "";
        menu.querySelector('[data-note="res"]').textContent = `Looks like ${RES[index][0]}${tag}${pending}`;
      }
      return { nodes, after: () => updateNote() };
    },

    virtual() {
      const sizes = RATIOS[state.ratio][1];
      const nodes = [header({ icon: "dashed", name: "Virtual Screen", sub: `Virtual screen · ${sizes[state.vsSize]}`, on: state.vsOn, onSwitch: (on) => set({ vsOn: on }) })];
      nodes.push(cap("Aspect ratio"),
        chips(Object.keys(RATIOS), state.ratio, (o) => set({ ratio: o, vsSize: Math.min(state.vsSize, RATIOS[o][1].length - 1) }), "Aspect ratio"),
        cap("Size"));
      const s = capsuleSlider({
        name: "Virtual screen size", value: state.vsSize / (sizes.length - 1), steps: sizes.length - 1,
        icon: "resize", label: (v) => sizes[Math.round(v * (sizes.length - 1))],
        onInput: (v) => {
          state.vsSize = Math.round(v * (sizes.length - 1));
          applyDesktop();
          menu.querySelector(".dev .sub").textContent = `Virtual screen · ${sizes[state.vsSize]}`;
        },
      });
      nodes.push(s.el,
        checkRow("mirror", "Mirror Built-in Display", state.vsMirror, (on) => set({ vsMirror: on })),
        checkRow("link", "Connect with LG UltraFine 5K", state.vsAuto, (on) => set({ vsAuto: on })));
      return { nodes };
    },

    monitor() {
      const nodes = [header({ icon: "display", name: "LG UltraFine 5K", sub: "MCCS 2.2 · 34 VCP codes", on: true })];
      const contrast = capsuleSlider({
        name: "Contrast", value: state.contrast, icon: "contrast",
        label: (v) => `Contrast ${Math.round(v * 100)}`,
        onInput: (v) => { state.contrast = v; applyDesktop(); showOSD("contrast", v); },
      });
      const volume = capsuleSlider({
        name: "Volume", value: state.volume, icon: (v) => (state.muted || v === 0 ? "mute" : "speaker"),
        label: (v) => (state.muted ? "Muted" : `Volume ${Math.round(v * 100)}`),
        onInput: (v) => { state.volume = v; state.muted = false; volume.repaint(); muteRow.setAttribute("aria-checked", "false"); showOSD("speaker", v); },
      });
      const muteRow = checkRow("mute", "Mute", state.muted, (on) => {
        state.muted = on; muteRow.setAttribute("aria-checked", String(on)); volume.repaint(); showOSD(on ? "mute" : "speaker", on ? 0 : state.volume);
      });
      nodes.push(contrast.el, volume.el, muteRow, cap("Input source"));
      for (const input of INPUTS) {
        nodes.push(radioRow("cable", input, state.input === input, () => set({ input })));
      }
      nodes.push(cap("Picture mode"), chips(Object.keys(PICTURE), state.picture, (o) => set({ picture: o }), "Picture mode"));
      return { nodes };
    },

    colors() {
      const nodes = [header({ icon: "laptop", name: "Built-in Retina Display", badge: "HiDPI", sub: `${RES[state.res][0]} · ${state.hz} Hz`, on: true }), cap("System colours")];
      nodes.push(
        switchRow("moon", "Dark Mode", state.dark, (on) => set({ dark: on })),
        switchRow("sun", "Night Shift", state.night, (on) => set({ night: on })),
        switchRow("eye", "True Tone", state.trueTone, (on) => set({ trueTone: on })),
        cap("Image adjustments"));
      const t = capsuleSlider({
        name: "Colour temperature", value: state.temperature, icon: "filters",
        markers: [{ at: 0.5, label: "Neutral" }],
        label: (v) => `${Math.round(2700 + v * 6300)} K`,
        onInput: (v) => { state.temperature = Math.abs(v - 0.5) < 0.03 ? 0.5 : v; applyDesktop(); },
      });
      nodes.push(t.el, checkRow("contrast", "Invert Colors", state.invert, (on) => set({ invert: on })));
      return { nodes };
    },
  };

  function refresh() {
    const { nodes, after } = builders[state.tab]();
    menu.replaceChildren(...nodes, bottomBar());
    menu.setAttribute("aria-label", `${state.tab} controls`);
    after && after();
  }

  function selectTab(tab) {
    state.tab = tab;
    root.querySelectorAll(".tab").forEach((t) => {
      const on = t.dataset.tab === tab;
      t.setAttribute("aria-selected", on);
      t.tabIndex = on ? 0 : -1;
    });
    $("#demo-title").textContent = COPY[tab][0];
    $("#demo-text").textContent = COPY[tab][1];
    menu.setAttribute("aria-labelledby", "tab-" + tab);
    applyDesktop();
    refresh();
  }

  root.querySelectorAll(".tab").forEach((t, i, all) => {
    t.addEventListener("click", () => selectTab(t.dataset.tab));
    t.addEventListener("keydown", (e) => {
      const d = e.key === "ArrowRight" ? 1 : e.key === "ArrowLeft" ? -1 : 0;
      if (!d) return;
      const next = all[(i + d + all.length) % all.length];
      next.focus();
      selectTab(next.dataset.tab);
    });
  });

  applyScale();
  selectTab("brightness");
})();

// ---------- Small brightness illustration in the feature grid ----------

(function miniSliders() {
  const host = document.getElementById("mini-sliders");
  if (!host) return;
  const rows = [
    { name: "Brightness", icon: "sun", label: (v) => `${Math.round(v * 100)}%`, value: 0.72, markers: [{ at: 0.3, label: "Min HW" }] },
    { name: "Contrast", icon: "contrast", label: (v) => `Contrast ${Math.round(v * 100)}`, value: 0.5 },
    { name: "Volume", icon: "speaker", label: (v) => `Volume ${Math.round(v * 100)}`, value: 0.35 },
  ];
  const sliders = rows.map((r) => {
    const s = capsuleSlider(r);
    s.el.setAttribute("aria-hidden", "true");
    s.el.tabIndex = -1;
    s.el.style.pointerEvents = "none";
    host.append(s.el);
    return s;
  });
  if (reduceMotion) return;
  let t = 0;
  setInterval(() => {
    t += 1;
    sliders.forEach((s, i) => s.set(0.25 + 0.6 * (0.5 + 0.5 * Math.sin(t * 0.9 + i * 1.7))));
  }, 1400);
})();

// ---------- Film ----------

(function film() {
  const video = document.getElementById("film");
  const toggle = document.getElementById("film-toggle");
  if (!video || !toggle) return;
  const sync = () => {
    const playing = !video.paused && !video.ended;
    toggle.innerHTML = svg(playing ? "pause" : video.ended ? "replay" : "play");
    toggle.setAttribute("aria-label", playing ? "Pause the film" : "Play the film");
  };
  toggle.addEventListener("click", () => (video.paused || video.ended ? video.play() : video.pause()));
  ["play", "pause", "ended"].forEach((e) => video.addEventListener(e, sync));
  if (!reduceMotion) {
    const io = new IntersectionObserver((entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting && video.dataset.userPaused !== "1") video.play().catch(() => {});
        else if (!entry.isIntersecting) video.pause();
      }
    }, { threshold: 0.35 });
    io.observe(video);
  }
  toggle.addEventListener("click", () => { video.dataset.userPaused = video.paused ? "1" : "0"; });
  document.querySelectorAll("[data-watch]").forEach((a) => a.addEventListener("click", () => {
    video.dataset.userPaused = "0";
    video.currentTime = 0;
    video.play().catch(() => {});
  }));
  sync();
})();

// ---------- Terminal ----------

(function terminal() {
  const pre = document.getElementById("terminal-output");
  if (!pre) return;
  const lines = [
    ["cmd", "greatdisplay --probe"],
    ["out", '{\n  <k>"app"</k> : <s>"Great Display"</s>,\n  <k>"ddcSupported"</k> : true,\n  <k>"displayCount"</k> : 2,\n  <k>"displays"</k> : [\n    {\n      <k>"builtIn"</k> : true,\n      <k>"name"</k> : <s>"Built-in Retina Display"</s>,\n      <k>"resolution"</k> : <s>"1512 × 982"</s>,\n      <k>"scale"</k> : <s>"2×"</s>,\n      …'],
    ["cmd", "greatdisplay --set-brightness 2 0.65"],
    ["out", "brightness 0.65 applied to LG UltraFine 5K"],
    ["cmd", "greatdisplay --rotate 2 90"],
    ["out", "rotation now 90°"],
    ["cmd", "open greatdisplay://brighten"],
  ];
  const fmt = (s) => s.replace(/<k>/g, '<span class="k">').replace(/<s>/g, '<span class="s">').replace(/<\/[ks]>/g, "</span>");
  const prompt = '<span class="p">~ %</span> ';
  const full = () => lines.map(([k, s]) => (k === "cmd" ? prompt + s : fmt(s))).join("\n") + '\n' + prompt + '<span class="caret"></span>';
  if (reduceMotion) { pre.innerHTML = full(); return; }
  pre.innerHTML = prompt + '<span class="caret"></span>';
  let started = false;
  const io = new IntersectionObserver(async (entries) => {
    if (started || !entries.some((e) => e.isIntersecting)) return;
    started = true;
    let html = "";
    const wait = (ms) => new Promise((r) => setTimeout(r, ms));
    for (const [kind, text] of lines) {
      if (kind === "cmd") {
        for (let i = 1; i <= text.length; i++) {
          pre.innerHTML = html + prompt + text.slice(0, i) + '<span class="caret"></span>';
          await wait(28 + Math.random() * 40);
        }
        html += prompt + text + "\n";
        await wait(260);
      } else {
        html += fmt(text) + "\n";
        pre.innerHTML = html + '<span class="caret"></span>';
        await wait(650);
      }
    }
    pre.innerHTML = html + prompt + '<span class="caret"></span>';
  }, { threshold: 0.4 });
  io.observe(pre);
})();

// ---------- Copy buttons ----------

document.querySelectorAll("[data-copy]").forEach((button) => {
  button.addEventListener("click", async () => {
    const text = document.getElementById(button.dataset.copy).textContent;
    try {
      await navigator.clipboard.writeText(text);
      button.textContent = "Copied";
    } catch {
      button.textContent = "Select and copy";
    }
    setTimeout(() => { button.textContent = "Copy"; }, 1600);
  });
});

// ---------- Reveal on scroll ----------

(function reveal() {
  const items = document.querySelectorAll(".reveal");
  if (reduceMotion || !("IntersectionObserver" in window)) { items.forEach((i) => i.classList.add("in")); return; }
  const io = new IntersectionObserver((entries) => {
    for (const e of entries) if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); }
  }, { threshold: 0.12, rootMargin: "0px 0px -40px 0px" });
  items.forEach((i) => io.observe(i));
})();
