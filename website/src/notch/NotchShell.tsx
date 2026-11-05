import { animate, motion, useMotionValue, useSpring, useTransform } from "motion/react";
import { useEffect, type ReactNode } from "react";

/**
 * The app's notch spring, `.spring(response: 0.42, dampingFraction: 0.74)`:
 * stiffness = (2π / 0.42)² ≈ 224, damping = 2 · 0.74 · √224 ≈ 22.1.
 */
export const NOTCH_SPRING = { type: "spring", stiffness: 224, damping: 22.1, mass: 1 } as const;
const SPRING_CFG = { stiffness: 224, damping: 22.1, mass: 1 };

/** The app's `.blurFade`: a 10 pt blur plus opacity. */
const blurIn = { opacity: 0, filter: "blur(10px)" };
const blurOut = { opacity: 1, filter: "blur(0px)" };

/** Expanded content: `.blurFade.combined(with: .move(edge: .top))`. */
export const expandedTransition = {
  initial: { ...blurIn, y: -18 },
  animate: { ...blurOut, y: 0, transition: NOTCH_SPRING },
  exit: { ...blurIn, y: -18, transition: { duration: 0.18 } },
};
/** Cards: `.blurFade.combined(with: .scale(scale: 0.85, anchor: .top))`. */
export const cardTransition = {
  initial: { ...blurIn, scale: 0.85, transformOrigin: "50% 0%" },
  animate: { ...blurOut, scale: 1, transformOrigin: "50% 0%", transition: NOTCH_SPRING },
  exit: { ...blurIn, scale: 0.85, transformOrigin: "50% 0%", transition: { duration: 0.18 } },
};

/** `NotchShape.path(in:)`: concave quad-curve flares at the top, rounded bottom corners. */
function notchPath(w: number, h: number, top: number, bottom: number) {
  const t = Math.min(top, w / 4);
  const b = Math.max(0, Math.min(bottom, h - t, (w - 2 * t) / 2));
  return `M0 0 Q${t} 0 ${t} ${t} L${t} ${h - b} Q${t} ${h} ${t + b} ${h} L${w - t - b} ${h} Q${w - t} ${h} ${w - t} ${h - b} L${w - t} ${t} Q${w - t} 0 ${w} 0 Z`;
}

/**
 * The notch, drawn and animated like `NotchView`: the exact silhouette, the app's spring on size and
 * radii, the glow (radius 14) plus a soft black shadow, and the decaying sine shake. Content is
 * padded by the top radius, like in the app. `width` includes the flares, like `NotchViewModel.size`.
 */
export function NotchShell({
  width,
  height,
  topRadius,
  bottomRadius,
  glow = "#000000",
  glowOpacity = 0,
  shadow = true,
  shake = 0,
  className = "",
  children,
}: {
  width: number;
  height: number;
  topRadius: number;
  bottomRadius: number;
  glow?: string;
  glowOpacity?: number;
  shadow?: boolean;
  shake?: number;
  className?: string;
  children?: ReactNode;
}) {
  const w = useSpring(width, SPRING_CFG);
  const h = useSpring(height, SPRING_CFG);
  const t = useSpring(topRadius, SPRING_CFG);
  const b = useSpring(bottomRadius, SPRING_CFG);
  useEffect(() => w.set(width), [width, w]);
  useEffect(() => h.set(height), [height, h]);
  useEffect(() => t.set(topRadius), [topRadius, t]);
  useEffect(() => b.set(bottomRadius), [bottomRadius, b]);

  const clip = useTransform([w, h, t, b], ([W, H, T, B]: number[]) => `path("${notchPath(W, H, T, B)}")`);

  // ShakeEffect: dx = sin(p · π · 6) · 7 · (1 − p), over 0.55 s, linear.
  const p = useMotionValue(1);
  const x = useTransform(p, (v) => Math.sin(v * Math.PI * 6) * 7 * (1 - v));
  useEffect(() => {
    if (!shake) return;
    p.set(0);
    void animate(p, 1, { duration: 0.55, ease: "linear" });
  }, [shake, p]);

  const hex = Math.round(glowOpacity * 255).toString(16).padStart(2, "0");
  const filter = `drop-shadow(0 0 14px ${glow}${hex}) drop-shadow(0 4px 10px rgba(0,0,0,${shadow ? 0.35 : 0}))`;

  return (
    <motion.div className={`relative ${className}`} style={{ width: w, height: h, x, filter, transition: "filter 0.45s ease" }}>
      <motion.div className="absolute inset-0 overflow-hidden bg-black text-white" style={{ clipPath: clip }}>
        <motion.div className="h-full" style={{ paddingLeft: t, paddingRight: t }}>
          <div className="relative h-full">{children}</div>
        </motion.div>
      </motion.div>
    </motion.div>
  );
}
