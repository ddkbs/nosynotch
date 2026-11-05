import { motion, useAnimationControls } from "motion/react";
import { useEffect, type ReactNode } from "react";

/** The app's notch spring: response 0.42, damping 0.74. */
export const NOTCH_SPRING = { type: "spring", stiffness: 230, damping: 22, mass: 1 } as const;

/**
 * The notch silhouette: black, rounded at the bottom, with concave flares where it meets the
 * top edge. Size, radius and glow animate with the app's spring; `shake` bumps a wiggle.
 */
export function NotchShell({
  width,
  height,
  radius,
  flare = 6,
  glow = "transparent",
  glowOpacity = 0,
  shake = 0,
  className = "",
  children,
}: {
  width: number | string;
  height: number;
  radius: number;
  flare?: number;
  glow?: string;
  glowOpacity?: number;
  shake?: number;
  className?: string;
  children?: ReactNode;
}) {
  const controls = useAnimationControls();
  useEffect(() => {
    if (!shake) return;
    void controls.start({ x: [0, -7, 6.5, -5, 3.5, -2, 0], transition: { duration: 0.55 } });
  }, [shake, controls]);

  const hex = Math.round(glowOpacity * 255).toString(16).padStart(2, "0");
  return (
    <motion.div animate={controls} className={`relative ${className}`} style={{ ["--flare" as string]: `${flare}px` }}>
      <motion.div
        className="relative overflow-hidden bg-black text-white"
        initial={false}
        animate={{
          width,
          height,
          borderBottomLeftRadius: radius,
          borderBottomRightRadius: radius,
          boxShadow: `0 0 28px ${glow.startsWith("#") ? glow + hex : "transparent"}, 0 8px 20px rgba(0,0,0,${glowOpacity ? 0.35 : 0})`,
        }}
        transition={NOTCH_SPRING}
      >
        {children}
      </motion.div>
      <span className="notch-flare notch-flare-l" />
      <span className="notch-flare notch-flare-r" />
    </motion.div>
  );
}
