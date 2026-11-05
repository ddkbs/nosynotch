import { useEffect, useRef } from "react";

export type CursorKind = "notch" | "spark" | "eye" | "swarm" | "system";

export const CURSORS: { id: CursorKind; label: string; hint: string }[] = [
  { id: "notch", label: "Notch", hint: "a pill that wraps buttons" },
  { id: "spark", label: "Spark", hint: "Claude's spark with a trail" },
  { id: "eye", label: "Eye", hint: "it looks where you go" },
  { id: "swarm", label: "Swarm", hint: "drape dots that follow" },
  { id: "system", label: "System", hint: "the normal arrow" },
];

/** Shared pointer state for every cursor: position, velocity, hovered target, pressed. */
function usePointer(enabled: boolean) {
  const s = useRef({ x: -100, y: -100, vx: 0, vy: 0, shown: false, pressed: false, target: null as Element | null, text: false });
  useEffect(() => {
    if (!enabled) return;
    const p = s.current;
    let lt = performance.now();
    const move = (e: PointerEvent) => {
      const now = performance.now();
      const dt = Math.max(1, now - lt);
      lt = now;
      p.vx = p.vx * 0.6 + ((e.clientX - p.x) / dt) * 0.4;
      p.vy = p.vy * 0.6 + ((e.clientY - p.y) / dt) * 0.4;
      p.x = e.clientX;
      p.y = e.clientY;
      p.shown = true;
      const hit = document.elementFromPoint(e.clientX, e.clientY);
      p.target = hit?.closest(".cursor-target") ?? null;
      p.text = !p.target && !!hit?.closest("p, h1, h2, h3, li, input, textarea");
    };
    const down = () => (p.pressed = true);
    const up = () => (p.pressed = false);
    const leave = () => (p.shown = false);
    window.addEventListener("pointermove", move, { passive: true });
    window.addEventListener("pointerdown", down, { passive: true });
    window.addEventListener("pointerup", up, { passive: true });
    document.documentElement.addEventListener("pointerleave", leave);
    return () => {
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerdown", down);
      window.removeEventListener("pointerup", up);
      document.documentElement.removeEventListener("pointerleave", leave);
    };
  }, [enabled]);
  return s;
}

/** A full-window canvas that redraws every frame. */
function useCanvasLoop(draw: (ctx: CanvasRenderingContext2D, dt: number, t: number) => void) {
  const ref = useRef<HTMLCanvasElement>(null);
  const drawRef = useRef(draw);
  drawRef.current = draw;
  useEffect(() => {
    const c = ref.current!;
    const ctx = c.getContext("2d")!;
    let dpr = 1;
    const resize = () => {
      dpr = Math.min(2, window.devicePixelRatio || 1);
      c.width = innerWidth * dpr;
      c.height = innerHeight * dpr;
    };
    resize();
    window.addEventListener("resize", resize);
    let raf = 0;
    let last = performance.now();
    const loop = (now: number) => {
      raf = requestAnimationFrame(loop);
      const dt = Math.min(0.033, (now - last) / 1000);
      last = now;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, innerWidth, innerHeight);
      drawRef.current(ctx, dt, now / 1000);
    };
    raf = requestAnimationFrame(loop);
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener("resize", resize);
    };
  }, []);
  return <canvas ref={ref} aria-hidden className="pointer-events-none fixed inset-0 z-[9999] h-screen w-screen" />;
}

const PALETTE = ["#6D5BFF", "#B04DFF", "#FF4F9A", "#FF9A5A"];
function paletteAt(t: number) {
  const n = PALETTE.length;
  const x = (((t % 1) + 1) % 1) * n;
  const i = Math.floor(x);
  const f = x - i;
  const hex = (h: string) => [1, 3, 5].map((k) => parseInt(h.slice(k, k + 2), 16));
  const a = hex(PALETTE[i]), b = hex(PALETTE[(i + 1) % n]);
  return a.map((v, k) => Math.round(v + (b[k] - v) * f)) as [number, number, number];
}

function springTo(s: { x: number; v: number }, target: number, dt: number, k = 520, c = 34) {
  s.v += (k * (target - s.x) - c * s.v) * dt;
  s.x += s.v * dt;
}

/** A small notch: a ring with a spark that springs open around buttons, a caret over text. */
function NotchCursor() {
  const p = usePointer(true);
  const st = useRef({ x: { x: -100, v: 0 }, y: { x: -100, v: 0 }, w: { x: 22, v: 0 }, h: { x: 22, v: 0 }, r: 11 });
  return useCanvasLoop((ctx, dt, t) => {
    const q = p.current;
    if (!q.shown) return;
    const s = st.current;
    let tx = q.x, ty = q.y, tw = 22, th = 22, tr = 11;
    if (q.target?.isConnected) {
      const r = q.target.getBoundingClientRect();
      const pad = 6;
      tx = r.left + r.width / 2 + (q.x - (r.left + r.width / 2)) * 0.08;
      ty = r.top + r.height / 2 + (q.y - (r.top + r.height / 2)) * 0.12;
      tw = r.width + pad * 2;
      th = r.height + pad * 2;
      tr = Math.min(th / 2, (parseFloat(getComputedStyle(q.target).borderTopLeftRadius) || 8) + pad);
    } else if (q.text) {
      tw = 3;
      th = 24;
      tr = 1.5;
    }
    if (q.pressed) {
      tw *= 0.9;
      th *= 0.86;
    }
    springTo(s.x, tx, dt);
    springTo(s.y, ty, dt);
    springTo(s.w, tw, dt);
    springTo(s.h, th, dt);
    s.r += (tr - s.r) * (1 - Math.exp(-dt * 18));
    const [r, g, b] = paletteAt(t / 14);
    const x = s.x.x - s.w.x / 2, y = s.y.x - s.h.x / 2;
    ctx.beginPath();
    ctx.roundRect(x, y, Math.max(1, s.w.x), Math.max(1, s.h.x), Math.max(0, Math.min(s.r, s.h.x / 2, s.w.x / 2)));
    ctx.shadowColor = `rgba(${r},${g},${b},0.9)`;
    ctx.shadowBlur = 16;
    if (q.text && !q.target) {
      ctx.fillStyle = "rgba(255,255,255,0.9)";
      ctx.fill();
    } else {
      ctx.fillStyle = q.target ? "rgba(0,0,0,0)" : "rgba(0,0,0,0.3)";
      ctx.fill();
      ctx.lineWidth = 1.5;
      ctx.strokeStyle = q.target ? "rgba(255,255,255,0.35)" : "rgba(255,255,255,0.6)";
      ctx.stroke();
    }
    ctx.shadowBlur = 0;
    if (!q.text || q.target) {
      // The spark: centred while idle, sitting on the top-left corner over a target.
      const sx = q.target ? x : s.x.x, sy = q.target ? y : s.y.x;
      star(ctx, sx, sy, q.target ? 6 : 4.5, t * 2.2, `rgb(${r},${g},${b})`);
    }
    if (!q.target && !q.text) {
      ctx.fillStyle = "#fff";
      ctx.beginPath();
      ctx.arc(q.x, q.y, 1.6, 0, Math.PI * 2);
      ctx.fill();
    }
  });
}

/** A four-pointed star with curved sides. */
function star(ctx: CanvasRenderingContext2D, x: number, y: number, r: number, a: number, fill: string) {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(a);
  ctx.beginPath();
  for (let i = 0; i < 4; i++) {
    const ang = (i * Math.PI) / 2;
    if (i === 0) ctx.moveTo(Math.cos(ang) * r, Math.sin(ang) * r);
    ctx.quadraticCurveTo(0, 0, Math.cos(ang + Math.PI / 2) * r, Math.sin(ang + Math.PI / 2) * r);
  }
  ctx.closePath();
  ctx.fillStyle = fill;
  ctx.fill();
  ctx.restore();
}

const RAYS = [1.0, 0.82, 0.95, 0.78, 1.0, 0.86, 0.93, 0.8, 0.97, 0.84];

/** Claude's spark (the app's ten rays), leaving a fading trail; it works faster over buttons. */
function SparkCursor() {
  const p = usePointer(true);
  const st = useRef({ x: -100, y: -100, size: 10, trail: [] as { x: number; y: number; life: number }[] });
  return useCanvasLoop((ctx, dt, t) => {
    const q = p.current;
    const s = st.current;
    if (!q.shown) return;
    const k = 1 - Math.exp(-dt * 28);
    s.x += (q.x - s.x) * k;
    s.y += (q.y - s.y) * k;
    const target = q.target ? 15 : q.pressed ? 7 : 10;
    s.size += (target - s.size) * (1 - Math.exp(-dt * 14));
    const speed = Math.hypot(q.vx, q.vy);
    if (speed > 0.05) s.trail.push({ x: s.x, y: s.y, life: 1 });
    for (const d of s.trail) d.life -= dt * 2.6;
    s.trail = s.trail.filter((d) => d.life > 0);
    const color = "217,119,87";
    for (const d of s.trail) {
      ctx.fillStyle = `rgba(${color},${d.life * 0.4})`;
      ctx.beginPath();
      ctx.arc(d.x, d.y, 0.6 + d.life * 2, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.save();
    ctx.translate(s.x, s.y);
    const working = !!q.target;
    ctx.rotate(t * (working ? 1.6 : 0.7));
    ctx.shadowColor = `rgba(${color},0.8)`;
    ctx.shadowBlur = 10;
    ctx.fillStyle = `rgb(${color})`;
    const r = s.size;
    RAYS.forEach((base, i) => {
      const phase = (i / RAYS.length) * Math.PI * 2;
      const sc = working ? 0.55 + 0.45 * (0.5 + 0.5 * Math.sin(t * 8 - phase * 2)) : 0.6 + 0.4 * (0.5 + 0.5 * Math.sin(t * 4.5 - phase));
      const inner = r * 0.16, len = (r - inner) * base * sc, w = r * 0.2;
      ctx.save();
      ctx.rotate(phase);
      ctx.beginPath();
      ctx.roundRect(-w / 2, -(inner + len), w, len, w / 2);
      ctx.fill();
      ctx.restore();
    });
    ctx.beginPath();
    ctx.arc(0, 0, r * 0.22, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  });
}

/** An eye: the pupil looks the way you move, it widens over buttons and blinks on click. */
function EyeCursor() {
  const p = usePointer(true);
  const st = useRef({ x: -100, y: -100, px: 0, py: 0, open: 1, wide: 1, blinkAt: 0 });
  return useCanvasLoop((ctx, dt, t) => {
    const q = p.current;
    const s = st.current;
    if (!q.shown) return;
    const k = 1 - Math.exp(-dt * 24);
    s.x += (q.x + 14 - s.x) * k;
    s.y += (q.y + 16 - s.y) * k;
    const sp = Math.hypot(q.vx, q.vy);
    const lx = sp > 0.02 ? q.vx / sp : 0, ly = sp > 0.02 ? q.vy / sp : 0;
    s.px += (lx * Math.min(1, sp * 2) - s.px) * (1 - Math.exp(-dt * 10));
    s.py += (ly * Math.min(1, sp * 2) - s.py) * (1 - Math.exp(-dt * 10));
    q.vx *= 0.9;
    q.vy *= 0.9;
    if (q.pressed || (t > s.blinkAt && t < s.blinkAt + 0.12)) s.open += (0.05 - s.open) * 0.5;
    else s.open += (1 - s.open) * (1 - Math.exp(-dt * 18));
    if (t > s.blinkAt + 4) s.blinkAt = t + 1 + Math.random() * 3;
    s.wide += ((q.target ? 1.35 : 1) - s.wide) * (1 - Math.exp(-dt * 12));
    const w = 13 * s.wide, h = 9 * s.wide * s.open;
    ctx.save();
    ctx.translate(s.x, s.y);
    ctx.beginPath();
    ctx.ellipse(0, 0, w, Math.max(0.6, h), 0, 0, Math.PI * 2);
    ctx.fillStyle = "#fff";
    ctx.shadowColor = "rgba(167,139,250,0.8)";
    ctx.shadowBlur = 12;
    ctx.fill();
    ctx.shadowBlur = 0;
    ctx.clip();
    const [r, g, b] = paletteAt(t / 12);
    ctx.fillStyle = `rgb(${r},${g},${b})`;
    ctx.beginPath();
    ctx.arc(s.px * 5, s.py * 3.5, 5.2 * s.wide, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#000";
    ctx.beginPath();
    ctx.arc(s.px * 5, s.py * 3.5, 2.6 * s.wide, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
    ctx.fillStyle = "#fff";
    ctx.beginPath();
    ctx.arc(q.x, q.y, 1.8, 0, Math.PI * 2);
    ctx.fill();
  });
}

/** A swarm of drape dots: they trail the pointer and line up around buttons. */
function SwarmCursor() {
  const p = usePointer(true);
  const dots = useRef(
    Array.from({ length: 26 }, (_, i) => ({ x: -100, y: -100, vx: 0, vy: 0, a: (i / 26) * Math.PI * 2, k: 0.5 + Math.random() * 0.8, s: 1 + Math.random() * 1.6 })),
  );
  return useCanvasLoop((ctx, dt, t) => {
    const q = p.current;
    if (!q.shown) return;
    let rect: DOMRect | null = null;
    if (q.target?.isConnected) rect = q.target.getBoundingClientRect();
    dots.current.forEach((d, i) => {
      let tx: number, ty: number;
      if (rect) {
        // Spread around the target's outline.
        const per = 2 * (rect.width + rect.height) + 24;
        let u = (((i / dots.current.length) + t * 0.08) % 1) * per;
        const w = rect.width + 12, h = rect.height + 12;
        const x0 = rect.left - 6, y0 = rect.top - 6;
        if (u < w) { tx = x0 + u; ty = y0; }
        else if ((u -= w) < h) { tx = x0 + w; ty = y0 + u; }
        else if ((u -= h) < w) { tx = x0 + w - u; ty = y0 + h; }
        else { u -= w; tx = x0; ty = y0 + h - Math.min(h, u); }
      } else {
        const r = 8 + 6 * Math.sin(t * 2 + d.a * 3);
        tx = q.x + Math.cos(d.a + t * d.k) * r;
        ty = q.y + Math.sin(d.a + t * d.k) * r;
      }
      const f = rect ? 22 : 10 * d.k;
      d.vx += (tx - d.x) * f * dt;
      d.vy += (ty - d.y) * f * dt;
      d.vx *= 1 - Math.min(1, dt * 7);
      d.vy *= 1 - Math.min(1, dt * 7);
      d.x += d.vx * dt * 10;
      d.y += d.vy * dt * 10;
      const [r, g, b] = paletteAt(t / 10 + i / 26);
      ctx.fillStyle = `rgba(${r},${g},${b},0.9)`;
      ctx.beginPath();
      ctx.arc(d.x, d.y, d.s, 0, Math.PI * 2);
      ctx.fill();
    });
    ctx.fillStyle = "#fff";
    ctx.beginPath();
    ctx.arc(q.x, q.y, 2, 0, Math.PI * 2);
    ctx.fill();
  });
}

/** Renders the chosen cursor and hides the system one for fine pointers. */
export function Cursor({ kind }: { kind: CursorKind }) {
  const fine = typeof window !== "undefined" && matchMedia("(pointer: fine)").matches;
  useEffect(() => {
    const on = fine && kind !== "system";
    document.documentElement.classList.toggle("custom-cursor", on);
    return () => document.documentElement.classList.remove("custom-cursor");
  }, [kind, fine]);
  if (!fine || kind === "system") return null;
  if (kind === "spark") return <SparkCursor />;
  if (kind === "eye") return <EyeCursor />;
  if (kind === "swarm") return <SwarmCursor />;
  return <NotchCursor />;
}
