import { motion } from "motion/react";
import { useEffect, useState } from "react";
import { AGENT_COLOR, AgentGlyph, type Agent, type SparkMode } from "../notch/Glyphs";

const CARDS: { agent: Agent; name: string; where: string; features: [string, boolean][] }[] = [
  {
    agent: "claude",
    name: "Claude Code",
    where: "Terminal · VS Code · desktop app",
    features: [["Live status", true], ["Allow in the notch", true], ["Usage limits", true], ["Context fill", true]],
  },
  {
    agent: "codex",
    name: "Codex",
    where: "CLI · ChatGPT app",
    features: [["Live status", true], ["Allow in the notch", true], ["Usage limits", true], ["Context fill", true]],
  },
  {
    agent: "cursor",
    name: "Cursor",
    where: "Cursor's agent",
    features: [["Live status", true], ["Allow in the notch", false], ["Usage limits", false], ["Context fill", false]],
  },
];

const LABEL: Record<SparkMode, string> = {
  idle: "Ready",
  thinking: "Thinking…",
  working: "Running a tool",
  waiting: "Needs you",
  compacting: "Compacting",
  done: "Done",
  error: "Error",
};

/** One card per agent; hovering wakes its mark up: thinking, working, done. */
function Card({ c, i }: { c: (typeof CARDS)[number]; i: number }) {
  const [hover, setHover] = useState(false);
  const [mode, setMode] = useState<SparkMode>("idle");
  useEffect(() => {
    if (!hover) {
      setMode("idle");
      return;
    }
    const seq: SparkMode[] = ["thinking", "working", "done"];
    let k = 0;
    setMode(seq[0]);
    const id = setInterval(() => {
      k = Math.min(seq.length - 1, k + 1);
      setMode(seq[k]);
    }, 1300);
    return () => clearInterval(id);
  }, [hover]);
  const color = AGENT_COLOR[c.agent];

  return (
    <motion.div
      initial={{ opacity: 0, y: 24 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: "-80px" }}
      transition={{ duration: 0.7, delay: i * 0.1, ease: [0.22, 1, 0.36, 1] }}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      className="cursor-target group relative overflow-hidden rounded-[26px] border border-white/[0.08] bg-[#0b0b0e] p-6"
    >
      <div
        className="pointer-events-none absolute -right-16 -top-16 size-56 rounded-full opacity-0 blur-3xl transition-opacity duration-700 group-hover:opacity-100"
        style={{ background: `${color}33` }}
      />
      <div className="flex items-center justify-between">
        <div className="grid size-16 place-items-center rounded-2xl bg-black shadow-[inset_0_0_0_1px_rgba(255,255,255,0.06)]">
          <AgentGlyph agent={c.agent} mode={mode} size={34} color={mode === "done" ? "#4ADE80" : undefined} />
        </div>
        <span className="font-mono text-[11px] transition-colors" style={{ color: mode === "idle" ? "var(--faint)" : mode === "done" ? "#4ADE80" : color }}>
          {LABEL[mode]}
        </span>
      </div>
      <div className="mt-6 text-[20px] font-semibold tracking-[-0.02em]">{c.name}</div>
      <div className="mt-0.5 text-[13px] text-muted-foreground">{c.where}</div>
      <ul className="mt-5 space-y-1.5">
        {c.features.map(([f, ok]) => (
          <li key={f} className={`flex items-center gap-2 text-[13.5px] ${ok ? "text-white/80" : "text-white/30"}`}>
            <span className="grid size-4 place-items-center rounded-full text-[9px] font-bold" style={{ background: ok ? `${color}26` : "transparent", color: ok ? color : "inherit" }}>
              {ok ? "✓" : "–"}
            </span>
            {f}
          </li>
        ))}
      </ul>
    </motion.div>
  );
}

export function Agents() {
  return (
    <div className="grid gap-4 md:grid-cols-3">
      {CARDS.map((c, i) => (
        <Card key={c.agent} c={c} i={i} />
      ))}
    </div>
  );
}
