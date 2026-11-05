import { AnimatePresence, motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { AGENT_COLOR, AgentGlyph, type Agent } from "../notch/Glyphs";

const AGENTS: Agent[] = ["claude", "codex", "cursor"];
const EVENTS = ["UserPromptSubmit", "PreToolUse", "PermissionRequest", "PostToolUse", "Stop"];

/** A dot that travels along an SVG path once, then fades. */
function Packet({ d, color }: { d: string; color: string }) {
  const path = useRef<SVGPathElement>(null);
  const dot = useRef<SVGCircleElement>(null);
  useEffect(() => {
    const p = path.current!;
    const c = dot.current!;
    const len = p.getTotalLength();
    const start = performance.now();
    let raf = 0;
    const step = (now: number) => {
      const k = Math.min(1, (now - start) / 850);
      const e = k < 0.5 ? 2 * k * k : 1 - (-2 * k + 2) ** 2 / 2;
      const pt = p.getPointAtLength(e * len);
      c.setAttribute("cx", String(pt.x));
      c.setAttribute("cy", String(pt.y));
      c.style.opacity = String(k < 0.1 ? k * 10 : k > 0.9 ? (1 - k) * 10 : 1);
      if (k < 1) raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [d]);
  return (
    <g>
      <path ref={path} d={d} fill="none" stroke="none" />
      <circle ref={dot} r="4.5" fill={color} style={{ filter: `drop-shadow(0 0 6px ${color})`, opacity: 0 }} />
    </g>
  );
}

/**
 * How it works, and why nothing leaves your Mac: hook events travel from the agents through a
 * one-line curl to 127.0.0.1 and into the notch, all inside a dashed "your Mac" boundary.
 * The leak button sends a packet towards the internet; it bounces off the boundary.
 */
export function Pipeline() {
  const [tick, setTick] = useState(0);
  const [leak, setLeak] = useState(0);
  const [log, setLog] = useState<{ id: number; agent: Agent; event: string }[]>([]);

  useEffect(() => {
    const id = setInterval(() => {
      setTick((t) => t + 1);
    }, 900);
    return () => clearInterval(id);
  }, []);
  useEffect(() => {
    if (!tick) return;
    const agent = AGENTS[(tick * 7) % 3];
    const event = EVENTS[tick % EVENTS.length];
    setLog((l) => [{ id: tick, agent, event }, ...l].slice(0, 4));
  }, [tick]);

  // Packet paths in a 720 × 300 box.
  const paths = [
    "M106 70 C 220 70, 240 150, 330 150",
    "M106 150 L 330 150",
    "M106 230 C 220 230, 240 150, 330 150",
  ];

  return (
    <div className="flex flex-col gap-4">
      <div className="relative overflow-hidden rounded-[26px] border border-white/[0.08] bg-[#08080a] p-3 sm:p-5">
        <svg viewBox="0 0 720 300" className="block w-full" aria-label="Hooks travel from the agents through curl to 127.0.0.1 and into the notch, all on your Mac">
          <defs>
            <linearGradient id="wire" x1="0" x2="1">
              <stop offset="0" stopColor="#ffffff" stopOpacity=".05" />
              <stop offset="1" stopColor="#ffffff" stopOpacity=".18" />
            </linearGradient>
          </defs>
          {/* The boundary of your Mac. */}
          <rect x="14" y="14" width="600" height="272" rx="26" fill="none" stroke="rgba(167,139,250,0.45)" strokeDasharray="5 7" />
          <text x="40" y="36" fill="rgba(167,139,250,0.8)" fontFamily="Geist Mono" fontSize="11">your Mac</text>
          <text x="666" y="150" fill="rgba(255,255,255,0.3)" fontFamily="Geist Mono" fontSize="11" textAnchor="middle">internet</text>
          <text x="666" y="166" fill="rgba(255,255,255,0.18)" fontFamily="Geist Mono" fontSize="10" textAnchor="middle">☁</text>

          {paths.map((d) => (
            <path key={d} d={d} fill="none" stroke="url(#wire)" strokeWidth="1.5" />
          ))}
          <path d="M440 150 L 520 150" fill="none" stroke="url(#wire)" strokeWidth="1.5" />

          {/* curl → 127.0.0.1:7823 */}
          <rect x="330" y="128" width="112" height="44" rx="12" fill="#111115" stroke="rgba(255,255,255,0.12)" />
          <text x="386" y="147" fill="#fff" fontFamily="Geist Mono" fontSize="11" textAnchor="middle">curl</text>
          <text x="386" y="162" fill="rgba(255,255,255,0.45)" fontFamily="Geist Mono" fontSize="9.5" textAnchor="middle">127.0.0.1:7823</text>

          {/* Notch */}
          <path d="M520 132 h70 v10 a14 14 0 0 1 -14 14 h-42 a14 14 0 0 1 -14 -14 Z" fill="#000" stroke="rgba(255,255,255,0.15)" />
          <circle cx="532" cy="143" r="3.5" fill="#D97757" />
          <text x="555" y="182" fill="rgba(255,255,255,0.45)" fontFamily="Geist Mono" fontSize="10" textAnchor="middle">notch</text>

          {/* Packets: one per hook event. */}
          {log.slice(0, 1).map((p) => (
            <Packet key={p.id} d={`${paths[AGENTS.indexOf(p.agent)]} L 520 150`} color={AGENT_COLOR[p.agent]} />
          ))}

          {/* Agents on the left. */}
          {AGENTS.map((a, i) => (
            <foreignObject key={a} x="62" y={48 + i * 80} width="44" height="44">
              <div className="grid size-11 place-items-center rounded-xl bg-black shadow-[inset_0_0_0_1px_rgba(255,255,255,0.1)]">
                <AgentGlyph agent={a} mode={log[0]?.agent === a ? "working" : "idle"} size={20} />
              </div>
            </foreignObject>
          ))}

          {/* The leak attempt bounces off the boundary. */}
          <AnimatePresence>
            {leak > 0 && (
              <motion.g key={leak}>
                <motion.circle
                  r="5"
                  fill="#F87171"
                  initial={{ cx: 442, cy: 150, opacity: 1 }}
                  animate={{ cx: [442, 612, 560], cy: [150, 150, 150], opacity: [1, 1, 0] }}
                  transition={{ duration: 1.1, times: [0, 0.55, 1], ease: "easeOut" }}
                />
                <motion.text
                  x="600"
                  y="120"
                  fill="#F87171"
                  fontFamily="Geist Mono"
                  fontSize="12"
                  textAnchor="middle"
                  initial={{ opacity: 0, y: 8 }}
                  animate={{ opacity: [0, 1, 1, 0], y: 0 }}
                  transition={{ duration: 1.6, times: [0, 0.35, 0.8, 1] }}
                >
                  nope.
                </motion.text>
              </motion.g>
            )}
          </AnimatePresence>
        </svg>

      </div>

      <div className="grid gap-4 md:grid-cols-[minmax(0,1fr)_auto] md:items-center">
        <div className="h-[132px] overflow-hidden rounded-2xl border border-white/[0.08] bg-black/60 p-4 font-mono text-[12px]">
          <AnimatePresence initial={false}>
            {log.map((l, i) => (
              <motion.div
                key={l.id}
                layout
                initial={{ opacity: 0, y: -10 }}
                animate={{ opacity: 1 - i * 0.22, y: 0 }}
                exit={{ opacity: 0 }}
                className="flex gap-2 leading-[26px]"
              >
                <span style={{ color: AGENT_COLOR[l.agent] }}>{l.agent.padEnd(6, " ")}</span>
                <span className="text-white/70">{l.event}</span>
                <span className="ml-auto text-white/30">→ 127.0.0.1 · {12 + ((l.id * 5) % 9)} ms</span>
              </motion.div>
            ))}
          </AnimatePresence>
        </div>
        <button
          type="button"
          onClick={() => setLeak((l) => l + 1)}
          className="cursor-target inline-flex h-11 justify-self-start items-center gap-2 rounded-full border border-danger/30 bg-danger/10 px-4 text-[13px] font-medium text-danger transition-colors hover:bg-danger/20"
        >
          Try to send something to the internet
        </button>
      </div>
    </div>
  );
}
