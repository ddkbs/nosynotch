import { useEffect, useRef } from "react";
import { NOSY_PALETTE } from "./backgrounds/SpectralDrape";

/**
 * The cursor is the agent's spark: it spins, leaves a short glowing trail and changes colour
 * with the page. Over anything clickable it grows and settles on the element's corner, like a
 * sticker. Only for mice and trackpads.
 */
export default function SparkCursor() {
  const canvas = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    if (!matchMedia("(pointer: fine)").matches) return;
    document.documentElement.classList.add("nosy-cursor");
    const c = canvas.current!;
    const ctx = c.getContext("2d")!;
    let dpr = 1;
    const resize = () => {
      dpr = Math.min(2, window.devicePixelRatio || 1);
      c.width = innerWidth * dpr;
      c.height = innerHeight * dpr;
    };
    resize();
    window.addEventListener("resize", resize);

    const mouse = { x: -100, y: -100 };
    const s = { x: -100, y: -100, size: 9, angle: 0 };
    const trail: { x: number; y: number; life: number }[] = [];
    let target: Element | null = null;
    let shown = false;
    let pressed = false;

    const onMove = (e: PointerEvent) => {
      mouse.x = e.clientX;
      mouse.y = e.clientY;
      if (!shown) {
        shown = true;
        s.x = mouse.x;
        s.y = mouse.y;
      }
      target = document.elementFromPoint(e.clientX, e.clientY)?.closest(".cursor-target") ?? null;
    };
    const onDown = () => (pressed = true);
    const onUp = () => (pressed = false);
    const onLeave = () => (shown = false);
    window.addEventListener("pointermove", onMove, { passive: true });
    window.addEventListener("pointerdown", onDown, { passive: true });
    window.addEventListener("pointerup", onUp, { passive: true });
    document.documentElement.addEventListener("pointerleave", onLeave);

    const rgb = NOSY_PALETTE.map((h) => {
      const n = parseInt(h.slice(1), 16);
      return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
    });
    const colour = (t: number) => {
      const n = rgb.length;
      const x = (((t % 1) + 1) % 1) * n;
      const i = Math.floor(x);
      const f = x - i;
      const a = rgb[i], b = rgb[(i + 1) % n];
      return a.map((v, k) => Math.round(v + (b[k] - v) * f));
    };

    const spark = (x: number, y: number, r: number, a: number, fill: string) => {
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(a);
      ctx.beginPath();
      // Four-pointed star with curved sides, like the app's spark.
      for (let i = 0; i < 4; i++) {
        const ang = (i * Math.PI) / 2;
        const px = Math.cos(ang) * r, py = Math.sin(ang) * r;
        const nx = Math.cos(ang + Math.PI / 2) * r, ny = Math.sin(ang + Math.PI / 2) * r;
        if (i === 0) ctx.moveTo(px, py);
        ctx.quadraticCurveTo(0, 0, nx, ny);
      }
      ctx.closePath();
      ctx.fillStyle = fill;
      ctx.fill();
      ctx.restore();
    };

    let raf = 0;
    let last = performance.now();
    const step = (now: number) => {
      raf = requestAnimationFrame(step);
      const dt = Math.min(0.033, (now - last) / 1000);
      last = now;
      let tx = mouse.x, ty = mouse.y, size = 8;
      if (target?.isConnected) {
        const r = target.getBoundingClientRect();
        tx = r.left + 2;
        ty = r.top + 2;
        size = 12;
      }
      if (pressed) size *= 0.7;
      const k = 1 - Math.exp(-dt * (target ? 16 : 30));
      s.x += (tx - s.x) * k;
      s.y += (ty - s.y) * k;
      s.size += (size - s.size) * (1 - Math.exp(-dt * 14));
      s.angle += dt * (target ? 1.2 : 3.2);

      if (shown && !target) trail.push({ x: s.x, y: s.y, life: 1 });
      for (const p of trail) p.life -= dt * 3.2;
      while (trail.length && trail[0].life <= 0) trail.shift();

      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, innerWidth, innerHeight);
      if (!shown) return;
      const [r, g, b] = colour(now / 1000 / 12);
      for (const p of trail) {
        ctx.fillStyle = `rgba(${r},${g},${b},${p.life * 0.35})`;
        ctx.beginPath();
        ctx.arc(p.x, p.y, 1 + p.life * 1.8, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.shadowColor = `rgba(${r},${g},${b},0.9)`;
      ctx.shadowBlur = 14;
      spark(s.x, s.y, s.size, s.angle, `rgb(${r},${g},${b})`);
      ctx.shadowBlur = 0;
      spark(s.x, s.y, s.size * 0.45, s.angle, "rgba(255,255,255,0.95)");
      // A precise point where the click lands.
      if (!target) {
        ctx.fillStyle = "#fff";
        ctx.beginPath();
        ctx.arc(mouse.x, mouse.y, 1.3, 0, Math.PI * 2);
        ctx.fill();
      }
    };
    raf = requestAnimationFrame(step);

    return () => {
      cancelAnimationFrame(raf);
      document.documentElement.classList.remove("nosy-cursor");
      window.removeEventListener("resize", resize);
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerdown", onDown);
      window.removeEventListener("pointerup", onUp);
      document.documentElement.removeEventListener("pointerleave", onLeave);
    };
  }, []);

  return <canvas ref={canvas} aria-hidden className="pointer-events-none fixed inset-0 z-[9999] h-screen w-screen" />;
}
