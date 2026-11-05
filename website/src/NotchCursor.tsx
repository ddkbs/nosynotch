import { useEffect, useRef } from "react";

/**
 * The cursor is a small notch: a dark pill with a soft ring and the agent's spark inside. Over
 * anything clickable (`.cursor-target`) it springs open and wraps the element, the way the
 * notch slides open while an agent works. Over text it narrows to a caret. Only for mice and
 * trackpads; touch keeps the system behaviour.
 */
export default function NotchCursor() {
  const shell = useRef<HTMLDivElement>(null);
  const dot = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!matchMedia("(pointer: fine)").matches) return;
    const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
    document.documentElement.classList.add("nosy-cursor");
    const el = shell.current!;
    const d = dot.current!;

    // Spring state for the shell's centre and size.
    const s = { x: -100, y: -100, w: 22, h: 22, r: 11, vx: 0, vy: 0, vw: 0, vh: 0 };
    const target = { x: -100, y: -100, w: 22, h: 22, r: 11 };
    const mouse = { x: -100, y: -100 };
    let hovered: Element | null = null;
    let mode: "idle" | "target" | "text" = "idle";
    let pressed = false;
    let shown = false;

    const pick = (x: number, y: number) => {
      const hit = document.elementFromPoint(x, y);
      const t = hit?.closest(".cursor-target") ?? null;
      if (t) return { t, m: "target" as const };
      const txt = hit?.closest("p, h1, h2, h3, li, pre, code, td, input, textarea");
      return { t: null, m: txt ? ("text" as const) : ("idle" as const) };
    };

    const onMove = (e: PointerEvent) => {
      mouse.x = e.clientX;
      mouse.y = e.clientY;
      if (!shown) {
        shown = true;
        s.x = mouse.x;
        s.y = mouse.y;
        el.style.opacity = "1";
        d.style.opacity = "1";
      }
      const { t, m } = pick(e.clientX, e.clientY);
      hovered = t;
      mode = m;
    };
    const onDown = () => (pressed = true);
    const onUp = () => (pressed = false);
    const onLeave = () => {
      shown = false;
      el.style.opacity = "0";
      d.style.opacity = "0";
    };
    window.addEventListener("pointermove", onMove, { passive: true });
    window.addEventListener("pointerdown", onDown, { passive: true });
    window.addEventListener("pointerup", onUp, { passive: true });
    document.documentElement.addEventListener("pointerleave", onLeave);

    let raf = 0;
    let last = performance.now();
    const step = (now: number) => {
      raf = requestAnimationFrame(step);
      const dt = Math.min(0.033, (now - last) / 1000);
      last = now;

      if (hovered && hovered.isConnected) {
        const r = hovered.getBoundingClientRect();
        const pad = 6;
        // Follow the element, leaning a little towards the pointer.
        target.x = r.left + r.width / 2 + (mouse.x - (r.left + r.width / 2)) * 0.08;
        target.y = r.top + r.height / 2 + (mouse.y - (r.top + r.height / 2)) * 0.12;
        target.w = r.width + pad * 2;
        target.h = r.height + pad * 2;
        const radius = parseFloat(getComputedStyle(hovered).borderTopLeftRadius) || 8;
        target.r = Math.min(target.h / 2, radius + pad);
      } else if (mode === "text") {
        target.x = mouse.x;
        target.y = mouse.y;
        target.w = 4;
        target.h = 26;
        target.r = 2;
      } else {
        target.x = mouse.x;
        target.y = mouse.y;
        target.w = 22;
        target.h = 22;
        target.r = 11;
      }
      if (pressed) {
        target.w *= 0.92;
        target.h *= 0.88;
      }

      if (reduce) {
        Object.assign(s, target);
      } else {
        const k = 520, c = 34; // spring stiffness and damping
        const spring = (p: "x" | "y" | "w" | "h", v: "vx" | "vy" | "vw" | "vh") => {
          const a = k * (target[p] - s[p]) - c * s[v];
          s[v] += a * dt;
          s[p] += s[v] * dt;
        };
        spring("x", "vx");
        spring("y", "vy");
        spring("w", "vw");
        spring("h", "vh");
        s.r += (target.r - s.r) * (1 - Math.exp(-dt * 18));
      }

      el.style.transform = `translate3d(${s.x - s.w / 2}px, ${s.y - s.h / 2}px, 0)`;
      el.style.width = `${s.w}px`;
      el.style.height = `${s.h}px`;
      el.style.borderRadius = `${s.r}px`;
      el.dataset.mode = hovered ? "target" : mode;
      d.style.transform = `translate3d(${mouse.x - 2}px, ${mouse.y - 2}px, 0)`;
      d.style.opacity = shown && !hovered && mode !== "text" ? "1" : "0";
    };
    raf = requestAnimationFrame(step);

    return () => {
      cancelAnimationFrame(raf);
      document.documentElement.classList.remove("nosy-cursor");
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerdown", onDown);
      window.removeEventListener("pointerup", onUp);
      document.documentElement.removeEventListener("pointerleave", onLeave);
    };
  }, []);

  return (
    <>
      <div
        ref={shell}
        aria-hidden
        className="notch-cursor pointer-events-none fixed left-0 top-0 z-[9999] opacity-0 transition-opacity duration-300"
      >
        <svg viewBox="0 0 24 24" className="notch-cursor-spark" aria-hidden>
          <path d="M12 2c1 5 3 7 10 10-7 3-9 5-10 10-1-5-3-7-10-10 7-3 9-5 10-10Z" fill="currentColor" />
        </svg>
      </div>
      <div
        ref={dot}
        aria-hidden
        className="pointer-events-none fixed left-0 top-0 z-[9999] size-1 rounded-full bg-white opacity-0 mix-blend-difference"
      />
    </>
  );
}
