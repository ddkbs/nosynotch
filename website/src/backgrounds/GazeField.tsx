import { useEffect, useRef } from "react";
import { NOSY_PALETTE } from "./SpectralDrape";

/**
 * A field of short strokes, like iron filings, that all turn to look at the pointer. With no
 * pointer around they look up at the notch instead. Strokes near the gaze grow and brighten,
 * colours drift slowly through the palette, and a click sends a shock wave across the field.
 */
export default function GazeField({
  spacing = 22,
  palette = NOSY_PALETTE,
  cycle = 40,
  className = "",
}: {
  spacing?: number;
  palette?: string[];
  cycle?: number;
  className?: string;
}) {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = ref.current!;
    const ctx = canvas.getContext("2d")!;
    const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
    const rgb = palette.map((h) => {
      const n = parseInt(h.slice(1), 16);
      return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
    });

    let w = 0, h = 0, dpr = 1;
    type Cell = { x: number; y: number; a: number; seed: number };
    let cells: Cell[] = [];
    const resize = () => {
      const r = canvas.getBoundingClientRect();
      dpr = Math.min(2, window.devicePixelRatio || 1);
      w = r.width;
      h = r.height;
      canvas.width = Math.round(w * dpr);
      canvas.height = Math.round(h * dpr);
      cells = [];
      const cols = Math.ceil(w / spacing) + 1;
      const rows = Math.ceil(h / spacing) + 1;
      const ox = (w - (cols - 1) * spacing) / 2;
      const oy = (h - (rows - 1) * spacing) / 2;
      for (let y = 0; y < rows; y++)
        for (let x = 0; x < cols; x++)
          cells.push({ x: ox + x * spacing, y: oy + y * spacing, a: -Math.PI / 2, seed: Math.random() });
    };
    resize();
    const ro = new ResizeObserver(resize);
    ro.observe(canvas);

    // Where the field looks: the pointer, or the notch at the top when the pointer is away.
    const gaze = { x: 0, y: -60, tx: 0, ty: -60, active: false, last: 0 };
    const waves: { x: number; y: number; t: number }[] = [];
    const local = (e: PointerEvent) => {
      const r = canvas.getBoundingClientRect();
      return [e.clientX - r.left, e.clientY - r.top] as const;
    };
    const onMove = (e: PointerEvent) => {
      const [x, y] = local(e);
      gaze.tx = x;
      gaze.ty = y;
      gaze.active = y > -40 && y < h + 40;
      gaze.last = performance.now();
    };
    const onDown = (e: PointerEvent) => {
      const [x, y] = local(e);
      if (y < 0 || y > h) return;
      waves.push({ x, y, t: performance.now() });
      if (waves.length > 6) waves.shift();
    };
    window.addEventListener("pointermove", onMove, { passive: true });
    window.addEventListener("pointerdown", onDown, { passive: true });

    let visible = true;
    const io = new IntersectionObserver(([e]) => (visible = e.isIntersecting));
    io.observe(canvas);

    const mix = (t: number) => {
      const n = rgb.length;
      const s = (((t % 1) + 1) % 1) * n;
      const i = Math.floor(s);
      const f = s - i;
      const k = f * f * (3 - 2 * f);
      const a = rgb[i], b = rgb[(i + 1) % n];
      return [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k];
    };

    let raf = 0;
    let lastT = performance.now();
    const tick = new URLSearchParams(location.search).has("tick");
    const frame = (now = performance.now()) => {
      raf = tick ? window.setTimeout(() => frame(), 16) : requestAnimationFrame(frame);
      if (!tick && (!visible || document.hidden)) return;
      const dt = Math.min(0.05, (now - lastT) / 1000);
      lastT = now;
      const t = now / 1000;

      // After a few idle seconds the field drifts back to looking at the notch.
      if (now - gaze.last > 3500) gaze.active = false;
      const tx = gaze.active ? gaze.tx : w / 2 + Math.sin(t * 0.4) * 40;
      const ty = gaze.active ? gaze.ty : -70;
      const kg = 1 - Math.exp(-dt * (gaze.active ? 10 : 2.5));
      gaze.x += (tx - gaze.x) * kg;
      gaze.y += (ty - gaze.y) * kg;

      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, w, h);
      ctx.lineCap = "round";
      const reach = Math.max(w, h) * 0.38;
      const turn = reduce ? 1 : 1 - Math.exp(-dt * 7);
      const drift = t / cycle;

      for (const c of cells) {
        const dx = gaze.x - c.x;
        const dy = gaze.y - c.y;
        const d = Math.hypot(dx, dy);
        let target = Math.atan2(dy, dx);
        // Shock waves knock strokes sideways for a moment.
        let shock = 0;
        for (const wv of waves) {
          const age = (now - wv.t) / 1000;
          if (age > 1.6) continue;
          const rd = Math.hypot(c.x - wv.x, c.y - wv.y);
          shock += Math.exp(-(((rd - age * 700) / 60) ** 2)) * (1 - age / 1.6);
        }
        target += shock * 1.6 * (c.seed - 0.5) * 2;
        let da = target - c.a;
        da = Math.atan2(Math.sin(da), Math.cos(da));
        c.a += da * turn * (0.6 + c.seed * 0.6);

        const near = Math.exp(-((d / reach) ** 2));
        const len = 3 + near * 9 + shock * 6;
        const [r, g, b] = mix(drift + c.x / w * 0.35 + c.y / h * 0.2);
        const alpha = 0.1 + near * 0.6 + shock * 0.4;
        const ca = Math.cos(c.a) * len, sa = Math.sin(c.a) * len;
        ctx.strokeStyle = `rgba(${r | 0},${g | 0},${b | 0},${Math.min(1, alpha)})`;
        ctx.lineWidth = 1.2 + near * 0.6;
        ctx.beginPath();
        ctx.moveTo(c.x - ca * 0.5, c.y - sa * 0.5);
        ctx.lineTo(c.x + ca * 0.5, c.y + sa * 0.5);
        ctx.stroke();
      }
    };
    frame();

    return () => {
      cancelAnimationFrame(raf);
      clearTimeout(raf);
      ro.disconnect();
      io.disconnect();
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerdown", onDown);
    };
  }, [spacing, palette, cycle]);

  return <canvas ref={ref} className={`block h-full w-full ${className}`} aria-hidden />;
}
