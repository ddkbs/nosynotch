import { motion } from "motion/react";
import { useEffect, useRef, useState } from "react";

/**
 * A big notch hanging from the top of the page with two eyes in it. The eyes follow the pointer,
 * blink now and then, and the notch widens a little when you come close, curious.
 */
export function NosyEyes({ onPoke }: { onPoke?: () => void }) {
  const box = useRef<HTMLButtonElement>(null);
  const pupils = useRef<(HTMLSpanElement | null)[]>([]);
  const [blink, setBlink] = useState(false);
  const [close, setClose] = useState(false);

  useEffect(() => {
    const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
    const target = { x: 0, y: 1 };
    const cur = { x: 0, y: 1 };
    let raf = 0;
    const onMove = (e: PointerEvent) => {
      const r = box.current!.getBoundingClientRect();
      const cx = r.left + r.width / 2;
      const cy = r.top + r.height / 2;
      const dx = e.clientX - cx;
      const dy = e.clientY - cy;
      const d = Math.hypot(dx, dy) || 1;
      const k = Math.min(1, d / 220);
      target.x = (dx / d) * k;
      target.y = (dy / d) * k;
      setClose(d < 260);
    };
    const step = () => {
      raf = requestAnimationFrame(step);
      const f = reduce ? 1 : 0.18;
      cur.x += (target.x - cur.x) * f;
      cur.y += (target.y - cur.y) * f;
      for (const p of pupils.current) {
        if (p) p.style.transform = `translate(${cur.x * 9}px, ${cur.y * 7}px)`;
      }
    };
    raf = requestAnimationFrame(step);
    window.addEventListener("pointermove", onMove, { passive: true });

    let blinkTimer = 0;
    const scheduleBlink = () => {
      blinkTimer = window.setTimeout(() => {
        setBlink(true);
        window.setTimeout(() => setBlink(false), 140);
        scheduleBlink();
      }, 2200 + Math.random() * 3800);
    };
    scheduleBlink();

    return () => {
      cancelAnimationFrame(raf);
      clearTimeout(blinkTimer);
      window.removeEventListener("pointermove", onMove);
    };
  }, []);

  return (
    <motion.button
      ref={box}
      type="button"
      onClick={onPoke}
      aria-label="Install Nosy Notch"
      className="cursor-target group relative flex items-center justify-center gap-5 bg-black shadow-[0_0_0_1px_rgba(255,255,255,0.06),0_30px_90px_-20px_rgba(143,124,255,0.45)]"
      initial={{ width: 120, height: 30, borderBottomLeftRadius: 16, borderBottomRightRadius: 16 }}
      animate={{
        width: close ? 300 : 250,
        height: close ? 96 : 84,
        borderBottomLeftRadius: 34,
        borderBottomRightRadius: 34,
      }}
      transition={{ type: "spring", stiffness: 220, damping: 22 }}
    >
      {[0, 1].map((i) => (
        <span key={i} className="relative block h-[38px] w-[30px] overflow-hidden rounded-full bg-white">
          <span
            ref={(el) => {
              pupils.current[i] = el;
            }}
            className="absolute left-1/2 top-1/2 -ml-[8px] -mt-[8px] block size-4 rounded-full bg-black"
          >
            <span className="absolute left-[3px] top-[3px] block size-[5px] rounded-full bg-white/90" />
          </span>
          <span
            className="absolute inset-x-0 top-0 block bg-black transition-[height] duration-100"
            style={{ height: blink ? "100%" : "0%" }}
          />
        </span>
      ))}
      <span className="pointer-events-none absolute -bottom-7 font-mono text-[11px] text-white/0 transition-colors duration-300 group-hover:text-white/50">
        poke me
      </span>
    </motion.button>
  );
}
