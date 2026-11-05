import { motion } from "motion/react";
import { useMemo } from "react";

const COLORS = ["#4ADE80", "#D97757", "#F5A524", "#A78BFA", "#80AAFF", "#F26B9E"];

/** A burst of confetti from one point, like the app's "Done". Change `burst` to fire again. */
export function Confetti({ burst, count = 30, spread = 1 }: { burst: number; count?: number; spread?: number }) {
  const bits = useMemo(
    () =>
      Array.from({ length: count }, (_, i) => {
        const a = Math.random() * Math.PI * 2;
        const d = (40 + Math.random() * 90) * spread;
        return {
          i,
          x: Math.cos(a) * d,
          y: Math.sin(a) * d * 0.8,
          r: Math.random() * 720 - 360,
          c: COLORS[i % COLORS.length],
          w: 3 + Math.random() * 3.5,
          round: Math.random() < 0.35,
          delay: Math.random() * 0.06,
        };
      }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [burst, count, spread],
  );
  if (!burst) return null;
  return (
    <span className="pointer-events-none absolute left-1/2 top-1/2 block" key={burst} aria-hidden>
      {bits.map((b) => (
        <motion.span
          key={b.i}
          className="absolute block"
          style={{ width: b.w, height: b.round ? b.w : b.w * 0.45, background: b.c, borderRadius: b.round ? 99 : 1 }}
          initial={{ x: 0, y: 0, opacity: 1, rotate: 0, scale: 0.4 }}
          animate={{ x: b.x, y: [0, b.y, b.y + 40], opacity: [1, 1, 0], rotate: b.r, scale: 1 }}
          transition={{ duration: 1.3, delay: b.delay, ease: [0.12, 0.7, 0.3, 1] }}
        />
      ))}
    </span>
  );
}

/** The checkmark that draws itself. */
export function DrawnCheck({ size = 40, color = "#4ADE80" }: { size?: number; color?: string }) {
  return (
    <svg viewBox="0 0 48 48" width={size} height={size} fill="none" aria-hidden>
      <motion.circle cx="24" cy="24" r="21" fill={`${color}22`} stroke={color} strokeWidth="2.5" initial={{ pathLength: 0 }} animate={{ pathLength: 1 }} transition={{ duration: 0.5, ease: "easeOut" }} />
      <motion.path d="m15 24.5 6 6 12-13" stroke={color} strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round" initial={{ pathLength: 0 }} animate={{ pathLength: 1 }} transition={{ duration: 0.38, delay: 0.38, ease: "easeOut" }} />
    </svg>
  );
}
