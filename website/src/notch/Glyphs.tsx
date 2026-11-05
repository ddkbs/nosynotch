import { useEffect, useRef } from "react";

export type SparkMode = "idle" | "thinking" | "working" | "waiting" | "compacting" | "done" | "error";
export type Agent = "claude" | "codex" | "cursor";

export const AGENT_COLOR: Record<Agent, string> = {
  claude: "#D97757",
  codex: "#80AAFF",
  cursor: "#D1D6E0",
};
export const AGENT_NAME: Record<Agent, string> = { claude: "Claude", codex: "Codex", cursor: "Cursor" };

const RAYS = [1.0, 0.82, 0.95, 0.78, 1.0, 0.86, 0.93, 0.8, 0.97, 0.84];

/** Claude's spark, drawn like the app's ClaudeSpark: ten rays that breathe, wave and spin by mode. */
export function Spark({ mode = "thinking", color = AGENT_COLOR.claude, size = 18 }: { mode?: SparkMode; color?: string; size?: number }) {
  const ref = useRef<HTMLCanvasElement>(null);
  const live = useRef({ mode, color });
  live.current = { mode, color };

  useEffect(() => {
    const c = ref.current!;
    const ctx = c.getContext("2d")!;
    const dpr = Math.min(3, window.devicePixelRatio || 1);
    c.width = size * dpr;
    c.height = size * dpr;
    let raf = 0;
    const draw = (now: number) => {
      raf = requestAnimationFrame(draw);
      const t = now / 1000;
      const { mode, color } = live.current;
      const r = size / 2;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, size, size);
      ctx.translate(r, r);
      const rot = mode === "thinking" ? t * 0.7 : mode === "working" ? t * 1.6 : mode === "compacting" ? -t * 1.1 : 0;
      ctx.rotate(rot);
      ctx.fillStyle = color;
      RAYS.forEach((base, i) => {
        const phase = (i / RAYS.length) * Math.PI * 2;
        let s: number;
        switch (mode) {
          case "idle": s = 0.82 + 0.05 * Math.sin(t * 1.3 + phase); break;
          case "thinking": s = 0.6 + 0.4 * (0.5 + 0.5 * Math.sin(t * 4.5 - phase)); break;
          case "working": s = 0.55 + 0.45 * (0.5 + 0.5 * Math.sin(t * 8 - phase * 2)); break;
          case "waiting": s = 0.7 + 0.3 * (0.5 + 0.5 * Math.sin(t * 6)); break;
          case "compacting": s = 0.45 + 0.25 * (0.5 + 0.5 * Math.sin(t * 3 + phase)); break;
          case "done": s = 0.95 + 0.05 * Math.sin(t * 2); break;
          default: {
            const flicker = Math.sin(t * 23 + phase * 3) * Math.sin(t * 7.3 + phase);
            s = 0.42 + 0.18 * Math.max(0, flicker);
          }
        }
        const inner = r * 0.16;
        const len = (r - inner) * base * s;
        const w = r * 0.2;
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
    };
    raf = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(raf);
  }, [size]);

  const glow = mode === "idle" ? 0.2 : mode === "done" ? 0.5 : 0.7;
  return (
    <canvas
      ref={ref}
      style={{ width: size, height: size, filter: `drop-shadow(0 0 4px ${color}${Math.round(glow * 255).toString(16).padStart(2, "0")})` }}
      aria-hidden
    />
  );
}

/** Codex: a hexagon that turns with the work and a prompt caret inside. */
export function CodexGlyph({ mode = "thinking", size = 18, color = AGENT_COLOR.codex }: { mode?: SparkMode; size?: number; color?: string }) {
  const speed = mode === "working" ? 2.2 : mode === "thinking" ? 5 : mode === "compacting" ? -5 : 0;
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} style={{ filter: `drop-shadow(0 0 4px ${color}aa)` }} aria-hidden>
      <g style={speed ? { transformOrigin: "12px 12px", animation: `spin-slow ${Math.abs(speed)}s linear infinite ${speed < 0 ? "reverse" : ""}` } : undefined}>
        <path d="M12 2.5 20.2 7.25v9.5L12 21.5 3.8 16.75v-9.5Z" fill="none" stroke={color} strokeWidth="2.2" strokeLinejoin="round" />
      </g>
      <path d="m8.6 9.8 2.4 2.2-2.4 2.2" fill="none" stroke={color} strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" />
      <rect x="12.2" y="13.3" width="3.6" height="1.8" rx=".9" fill={color} className={mode === "waiting" ? "animate-blink" : undefined} />
    </svg>
  );
}

/** Cursor: an isometric cube, turning while it works. */
export function CursorGlyph({ mode = "thinking", size = 18, color = AGENT_COLOR.cursor }: { mode?: SparkMode; size?: number; color?: string }) {
  const spin = mode === "working" || mode === "thinking";
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} style={{ filter: `drop-shadow(0 0 4px ${color}88)` }} aria-hidden>
      <g style={spin ? { transformOrigin: "12px 12px", animation: `spin-slow ${mode === "working" ? 2.4 : 4.5}s linear infinite` } : undefined}>
        <path d="M12 2.8 20 7.4v9.2L12 21.2 4 16.6V7.4Z" fill="none" stroke={color} strokeWidth="2" strokeLinejoin="round" />
        <path d="M4 7.4 12 12l8-4.6M12 12v9.2" fill="none" stroke={color} strokeWidth="1.6" strokeLinejoin="round" opacity=".8" />
        <path d="M12 2.8 20 7.4 12 12 4 7.4Z" fill={color} opacity=".25" />
      </g>
    </svg>
  );
}

export function AgentGlyph({ agent, mode, size = 18, color }: { agent: Agent; mode?: SparkMode; size?: number; color?: string }) {
  if (agent === "codex") return <CodexGlyph mode={mode} size={size} color={color} />;
  if (agent === "cursor") return <CursorGlyph mode={mode} size={size} color={color} />;
  return <Spark mode={mode} size={size} color={color ?? AGENT_COLOR.claude} />;
}

/** Tool icons for the right wing while an agent works. */
export const TOOL_ICON: Record<string, string> = {
  bash: "M4 6.5 9 11.5 4 16.5M11 17.5h9",
  edit: "M4 20h4L19 9l-4-4L4 16v4ZM13.5 6.5l4 4",
  grep: "M10.5 17a6.5 6.5 0 1 0 0-13 6.5 6.5 0 0 0 0 13ZM15.5 15.5 20 20",
  read: "M7 3h7l4 4v14H7ZM14 3v4h4M10 12h5M10 16h5",
  web: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM3 12h18M12 3c2.5 3 2.5 15 0 18M12 3c-2.5 3-2.5 15 0 18",
  todo: "M9 6h11M9 12h11M9 18h11M4 6l1 1 2-2M4 12l1 1 2-2M4 18l1 1 2-2",
};

export function ToolIcon({ tool, size = 15, color = "#fff" }: { tool: keyof typeof TOOL_ICON; size?: number; color?: string }) {
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d={TOOL_ICON[tool]} />
    </svg>
  );
}

/** Three dots bouncing in a wave: the agent is thinking. */
export function ThinkingDots({ color = "#fff" }: { color?: string }) {
  return (
    <span className="flex items-center gap-[3px]" aria-hidden>
      {[0, 1, 2].map((i) => (
        <span key={i} className="block size-[4px] rounded-full" style={{ background: color, animation: `bounce-dot 1.1s ${i * 0.15}s ease-in-out infinite` }} />
      ))}
    </span>
  );
}

/** Bars dancing in the cover's colour. */
export function Equalizer({ color = "#F26B9E", bars = 4, height = 14 }: { color?: string; bars?: number; height?: number }) {
  return (
    <span className="flex items-end gap-[2.5px]" style={{ height }} aria-hidden>
      {Array.from({ length: bars }, (_, i) => (
        <span
          key={i}
          className="block w-[3px] origin-bottom rounded-full"
          style={{ height, background: color, animation: `eq ${0.55 + (i % 3) * 0.17}s ${i * 0.11}s ease-in-out infinite alternate` }}
        />
      ))}
    </span>
  );
}
