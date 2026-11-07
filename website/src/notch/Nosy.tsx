import { useEffect, useId, useState } from "react";

/** Nosy, drawn like in the app (Sources/NosyNotch/Nosy/NosyFigure.swift): 60 × 76 design box. */

export type NosyMood = "idle" | "happy" | "needs" | "working" | "sleeping" | "giggle";

export type NosyColor = "obsidian" | "midnight" | "plum" | "lavender" | "peach" | "mint" | "pearl" | "jelly";

export const NOSY_COLORS: Record<NosyColor, { top: string; bottom: string; rim?: string; ink: string; label: string }> = {
  obsidian: { top: "#333333", bottom: "#080808", ink: "rgba(255,255,255,0.85)", label: "Obsidian" },
  midnight: { top: "#40479e", bottom: "#0f1238", rim: "#8fa8ff", ink: "rgba(255,255,255,0.85)", label: "Midnight" },
  plum: { top: "#75409e", bottom: "#210d38", rim: "#e08cff", ink: "rgba(255,255,255,0.85)", label: "Plum" },
  lavender: { top: "#d1c4ff", bottom: "#8f78f2", rim: "#ffffff", ink: "#3b1a29", label: "Lavender" },
  peach: { top: "#ffccad", bottom: "#ff8570", rim: "#ffd980", ink: "#3b1a29", label: "Peach" },
  mint: { top: "#d1f7e3", bottom: "#61cc9e", rim: "#ffffff", ink: "#1a402e", label: "Mint" },
  pearl: { top: "#ffffff", bottom: "#d1cfe6", rim: "#b8adff", ink: "#3b1a29", label: "Pearl" },
  jelly: { top: "rgba(255,140,199,0.8)", bottom: "rgba(128,97,255,0.88)", rim: "#ffffff", ink: "#3b1a29", label: "Jelly" },
};

const BEAN = "M30 14 C49 14 55 32 55 49.6 C55 64.8 47 68 30 68 C13 68 5 64.8 5 49.6 C5 32 11 14 30 14 Z";

function useBlink() {
  const [blink, setBlink] = useState(false);
  useEffect(() => {
    let t: ReturnType<typeof setTimeout>;
    const loop = () => {
      t = setTimeout(() => {
        setBlink(true);
        setTimeout(() => setBlink(false), 130);
        loop();
      }, 2200 + Math.random() * 2600);
    };
    loop();
    return () => clearTimeout(t);
  }, []);
  return blink;
}

export function NosyEyes({ mood, look, ink, cx, cy, r, gap }: {
  mood: NosyMood; look: { x: number; y: number }; ink: string; cx: number; cy: number; r: number; gap: number;
}) {
  const blink = useBlink();
  const style = mood === "sleeping" || (blink && mood !== "happy" && mood !== "giggle") ? "closed" : mood;
  const lx = mood === "working" ? 0.3 : mood === "needs" ? 0.6 : look.x;
  const ly = mood === "working" ? -0.55 : mood === "needs" ? 0.5 : look.y;
  return (
    <>
      {[-1, 1].map((side) => {
        const x = cx + side * gap;
        if (style === "closed")
          return <path key={side} d={`M${x - r * 0.8} ${cy} Q${x} ${cy + r * 0.9} ${x + r * 0.8} ${cy}`} stroke={ink} strokeWidth={r * 0.28} fill="none" strokeLinecap="round" />;
        if (style === "happy")
          return <path key={side} d={`M${x - r * 0.8} ${cy + r * 0.25} Q${x} ${cy - r * 1.1} ${x + r * 0.8} ${cy + r * 0.25}`} stroke={ink} strokeWidth={r * 0.3} fill="none" strokeLinecap="round" />;
        if (style === "giggle") {
          const d = side < 0 ? `M${x - r * 0.4} ${cy - r * 0.6} L${x + r * 0.45} ${cy} L${x - r * 0.4} ${cy + r * 0.6}` : `M${x + r * 0.4} ${cy - r * 0.6} L${x - r * 0.45} ${cy} L${x + r * 0.4} ${cy + r * 0.6}`;
          return <path key={side} d={d} stroke={ink} strokeWidth={r * 0.3} fill="none" strokeLinecap="round" strokeLinejoin="round" />;
        }
        const rr = mood === "needs" ? r * 1.12 : r;
        const iris = rr * 0.78;
        const travel = rr - iris + rr * 0.08;
        const ix = x + lx * travel, iy = cy + ly * travel;
        return (
          <g key={side}>
            <circle cx={x} cy={cy} r={rr} fill="#fff" />
            <circle cx={ix} cy={iy} r={iris} fill="#7a3d14" />
            <circle cx={ix + rr * 0.32} cy={iy - rr * 0.32} r={rr * 0.3} fill="#fff" />
            <circle cx={ix - rr * 0.24} cy={iy + rr * 0.3} r={rr * 0.13} fill="#fff" opacity="0.9" />
          </g>
        );
      })}
    </>
  );
}

export function Nosy({ mood = "idle", look = { x: 0, y: 0 }, color = "obsidian", tint = "#D97757", hanging = false, className }: {
  mood?: NosyMood; look?: { x: number; y: number }; color?: NosyColor; tint?: string; hanging?: boolean; className?: string;
}) {
  const id = useId().replace(/:/g, "");
  const c = NOSY_COLORS[color];
  const rim = c.rim ?? tint;
  const armAngle = hanging ? 172 : mood === "happy" ? 105 : mood === "needs" ? 24 : mood === "sleeping" ? 8 : 24;
  const rightAngle = mood === "needs" && !hanging ? 118 : armAngle;
  const shoulderX = hanging ? 20 : 19;
  const pivotY = hanging ? 28 : 37.5;
  const armLen = hanging ? 20 : 17;
  const armOffset = hanging ? 19 : armAngle > 60 ? 10.5 : 15.5;

  return (
    <svg viewBox="-6 -6 72 86" className={className} aria-label="Nosy">
      <defs>
        <linearGradient id={`b${id}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={c.top} />
          <stop offset="1" stopColor={c.bottom} />
        </linearGradient>
        <linearGradient id={`r${id}`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor={rim} stopOpacity="0.9" />
          <stop offset="1" stopColor={rim} stopOpacity="0.05" />
        </linearGradient>
        <linearGradient id={`g${id}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity="0.45" />
          <stop offset="1" stopColor="#fff" stopOpacity="0" />
        </linearGradient>
        <radialGradient id={`c${id}`}>
          <stop offset="0" stopColor="#ff8099" stopOpacity={mood === "giggle" ? 0.95 : 0.7} />
          <stop offset="1" stopColor="#ff8099" stopOpacity="0" />
        </radialGradient>
        <radialGradient id={`a${id}`}>
          <stop offset="0" stopColor={rim} stopOpacity="0.75" />
          <stop offset="1" stopColor={rim} stopOpacity="0" />
        </radialGradient>
      </defs>
      {/* feet */}
      {[-1, 1].map((s) => (
        <rect key={s} x={30 + s * 10 - 6} y={62} width={12} height={12} rx={6} fill={`url(#b${id})`} stroke={rim} strokeOpacity="0.25" strokeWidth="0.7"
          className={hanging ? (s < 0 ? "nosy-swing-l" : "nosy-swing-r") : undefined} style={{ transformOrigin: `${30 + s * 10}px 62px` }} />
      ))}
      {/* arms */}
      {[-1, 1].map((s) => (
        <g key={s} transform={`translate(${30 + s * shoulderX} ${pivotY}) rotate(${s < 0 ? armAngle : -rightAngle})`}>
          <rect x={-6} y={armOffset - armLen / 2} width={12} height={armLen} rx={6} fill={`url(#b${id})`} stroke={rim} strokeOpacity="0.3" strokeWidth="0.7"
            className={mood === "needs" && s > 0 && !hanging ? "nosy-wave" : undefined} style={{ transformOrigin: "0px 0px" }} />
        </g>
      ))}
      {/* antenna */}
      <g transform={`rotate(${hanging ? 35 : 0} 30 14)`} className={hanging ? undefined : "nosy-antenna"} style={{ transformOrigin: "30px 14px" }}>
        <rect x={29.2} y={5} width={1.6} height={9} rx={0.8} fill={rim} opacity="0.6" />
        <circle cx={30} cy={4} r={8} fill={`url(#a${id})`} className="nosy-glow" />
        <path d="M30 0 Q31.1 2.9 34 4 Q31.1 5.1 30 8 Q28.9 5.1 26 4 Q28.9 2.9 30 0Z" fill={rim} />
      </g>
      {/* body */}
      <path d={BEAN} fill={`url(#b${id})`} />
      <path d={BEAN} fill="none" stroke={`url(#r${id})`} strokeWidth="1.2" />
      <ellipse cx={37} cy={25} rx={11} ry={5.5} fill={`url(#g${id})`} />
      <circle cx={44} cy={30} r={1.75} fill="#fff" opacity="0.7" />
      {/* face */}
      <ellipse cx={13} cy={52} rx={7} ry={4} fill={`url(#c${id})`} />
      <ellipse cx={47} cy={52} rx={7} ry={4} fill={`url(#c${id})`} />
      <NosyEyes mood={mood} look={look} ink={c.ink} cx={30} cy={42} r={7.5} gap={10} />
      {mood === "happy" ? (
        <path d="M26.5 52.5 L33.5 52.5 Q30 58 26.5 52.5Z" fill={c.ink} />
      ) : mood === "needs" ? (
        <ellipse cx={30} cy={54} rx={2} ry={2.3} fill={c.ink} />
      ) : mood === "sleeping" ? (
        <circle cx={30} cy={54} r={1.3} fill={c.ink} />
      ) : mood === "giggle" ? (
        <path d="M26 53 Q28 56 30 53 Q32 56 34 53" stroke={c.ink} strokeWidth="1.3" fill="none" strokeLinecap="round" />
      ) : (
        <path d="M27 53 Q30 56 33 53" stroke={c.ink} strokeWidth="1.4" fill="none" strokeLinecap="round" />
      )}
    </svg>
  );
}
