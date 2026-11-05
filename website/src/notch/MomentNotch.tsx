import { AnimatePresence, motion } from "motion/react";
import { useEffect, useState, type ReactNode } from "react";
import { Confetti, DrawnCheck } from "./Confetti";
import { AGENT_COLOR, AGENT_NAME, AgentGlyph, Equalizer, Spark, ThinkingDots, ToolIcon, type Agent, type SparkMode, TOOL_ICON } from "./Glyphs";
import { NotchShell } from "./NotchShell";

export type MomentId = "thinking" | "working" | "attention" | "done" | "unseen" | "sessions" | "agents" | "music";

// The app's geometry: a 185 × 32 notch, 46 pt wings, 460 pt when it opens.
const NOTCH_W = 185;
const H = 32;
const WING = 46;
const COMPACT_W = NOTCH_W + 2 * WING;
const WIDE = 460;

const fade = {
  initial: { opacity: 0, scale: 0.92, filter: "blur(6px)" },
  animate: { opacity: 1, scale: 1, filter: "blur(0px)", transition: { delay: 0.12, duration: 0.35 } },
  exit: { opacity: 0, scale: 0.96, filter: "blur(4px)", transition: { duration: 0.15 } },
};

function Wings({ left, right }: { left?: ReactNode; right?: ReactNode }) {
  return (
    <div className="flex items-center justify-between px-1" style={{ height: H }}>
      <span className="grid place-items-center" style={{ width: WING - 14 }}>
        <AnimatePresence mode="popLayout" initial={false}>
          {left}
        </AnimatePresence>
      </span>
      <span className="grid place-items-center" style={{ width: WING - 14 }}>
        <AnimatePresence mode="popLayout" initial={false}>
          {right}
        </AnimatePresence>
      </span>
    </div>
  );
}

const pop = (key: string, node: ReactNode) => (
  <motion.span
    key={key}
    className="grid place-items-center"
    initial={{ scale: 0.2, opacity: 0 }}
    animate={{ scale: 1, opacity: 1 }}
    exit={{ scale: 0.2, opacity: 0 }}
    transition={{ type: "spring", stiffness: 400, damping: 22 }}
  >
    {node}
  </motion.span>
);

function Close({ onClick }: { onClick?: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label="Close"
      className="cursor-target absolute right-3.5 top-2 grid size-[18px] place-items-center rounded-full bg-white/10 text-[9px] text-white/60 transition-colors hover:bg-white/20 hover:text-white"
    >
      ✕
    </button>
  );
}

function Pill({ children, onClick, prominent }: { children: ReactNode; onClick: () => void; prominent?: boolean }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`cursor-target h-[26px] rounded-full px-3.5 text-[12px] font-semibold transition-colors ${
        prominent ? "bg-amber/90 text-black hover:bg-amber" : "bg-white/[0.11] text-white/90 hover:bg-white/20"
      }`}
    >
      {children}
    </button>
  );
}

function ContextRing({ percent, color }: { percent: number; color: string }) {
  const r = 7;
  const c = 2 * Math.PI * r;
  return (
    <svg viewBox="0 0 18 18" className="size-[18px] -rotate-90" aria-hidden>
      <circle cx="9" cy="9" r={r} fill="none" stroke="rgba(255,255,255,0.12)" strokeWidth="2.2" />
      <motion.circle
        cx="9"
        cy="9"
        r={r}
        fill="none"
        stroke={color}
        strokeWidth="2.2"
        strokeLinecap="round"
        strokeDasharray={c}
        initial={{ strokeDashoffset: c }}
        animate={{ strokeDashoffset: c * (1 - percent / 100) }}
        transition={{ duration: 1, delay: 0.3 }}
      />
    </svg>
  );
}

const SESSIONS: { agent: Agent; project: string; status: string; mode: SparkMode; ctx: number; time: string }[] = [
  { agent: "claude", project: "nosynotch", status: "Editing Parser.swift", mode: "working", ctx: 62, time: "2:14" },
  { agent: "codex", project: "api", status: "Running · npm test", mode: "working", ctx: 38, time: "0:41" },
  { agent: "cursor", project: "website", status: "Done · 3 files changed", mode: "done", ctx: 0, time: "" },
];

const USAGE = [
  { label: "Claude", five: 42, week: 18, color: AGENT_COLOR.claude },
  { label: "Codex", five: 23, week: 9, color: AGENT_COLOR.codex },
];

function meterColor(p: number) {
  return p < 60 ? "#4ADE80" : p < 85 ? "#F5A524" : "#F87171";
}

/**
 * One moment of a session, rebuilt from the app's SwiftUI views: same sizes, colours, spring and
 * animations. "Needs you" is live: Allow celebrates, Deny closes, like in the app.
 */
export function MomentNotch({ moment, onSettled }: { moment: MomentId; onSettled?: () => void }) {
  const [tool, setTool] = useState(0);
  const [agentIdx, setAgentIdx] = useState(0);
  const [answer, setAnswer] = useState<"none" | "allowed" | "denied">("none");
  const [shake, setShake] = useState(0);
  const [burst, setBurst] = useState(0);

  useEffect(() => {
    setAnswer("none");
    setTool(0);
    setAgentIdx(0);
    if (moment === "attention") {
      const id = setTimeout(() => setShake((s) => s + 1), 380);
      return () => clearTimeout(id);
    }
    if (moment === "done") {
      const id = setTimeout(() => setBurst((b) => b + 1), 320);
      return () => clearTimeout(id);
    }
    if (moment === "working") {
      const id = setInterval(() => setTool((t) => t + 1), 1300);
      return () => clearInterval(id);
    }
    if (moment === "agents") {
      const id = setInterval(() => setAgentIdx((t) => t + 1), 1900);
      return () => clearInterval(id);
    }
  }, [moment]);

  const decide = (a: "allowed" | "denied") => {
    setAnswer(a);
    if (a === "allowed") setTimeout(() => setBurst((b) => b + 1), 320);
    onSettled?.();
  };

  // What the notch is showing right now.
  const view: "compact" | "attention" | "done" | "sessions" | "media" =
    moment === "attention"
      ? answer === "allowed"
        ? "done"
        : answer === "denied"
          ? "compact"
          : "attention"
      : moment === "done"
        ? "done"
        : moment === "sessions"
          ? "sessions"
          : moment === "music"
            ? "media"
            : "compact";

  const size =
    view === "attention"
      ? { w: WIDE, h: H + 88 + 40, r: 26, f: 14, glow: "#F5A524", o: 0.55 }
      : view === "done"
        ? { w: WIDE, h: H + 104, r: 26, f: 14, glow: "#4ADE80", o: 0.55 }
        : view === "sessions"
          ? { w: WIDE, h: H + 12 + 10 + 3 * 50 + 8 + 2 * 24 + 6, r: 26, f: 14, glow: "#D97757", o: 0.18 }
          : view === "media"
            ? { w: COMPACT_W, h: H, r: 12, f: 6, glow: "#F26B9E", o: 0.22 }
            : { w: COMPACT_W, h: H, r: 12, f: 6, glow: moment === "unseen" ? "#4ADE80" : "#D97757", o: 0.18 };

  const agents: Agent[] = ["claude", "codex", "cursor"];
  const agent = moment === "agents" ? agents[agentIdx % 3] : "claude";
  const tools = Object.keys(TOOL_ICON) as (keyof typeof TOOL_ICON)[];

  // Header wings for every view.
  let left: ReactNode = null;
  let right: ReactNode = null;
  if (view === "media") {
    left = pop("cover", <span className="block size-5 rounded-[5px] bg-[linear-gradient(135deg,#ff9a5a,#f0479b_55%,#5b4bff)]" />);
    right = pop("eq", <Equalizer color="#F26B9E" />);
  } else if (view === "done") {
    left = pop("done", <Spark mode="done" color="#4ADE80" />);
  } else if (view === "attention") {
    left = pop("wait", <Spark mode="waiting" color="#F5A524" />);
  } else if (view === "sessions") {
    left = pop("s", <Spark mode="working" />);
    right = pop("n", <span className="rounded-full bg-white/12 px-1.5 py-px text-[11px] font-bold text-white/70">3</span>);
  } else if (moment === "unseen") {
    left = pop("idle", <Spark mode="idle" />);
    right = pop(
      "dot",
      <span className="relative grid size-3 place-items-center">
        <span className="absolute size-3 rounded-full bg-success/40" style={{ animation: "breathe 2s ease-in-out infinite" }} />
        <span className="size-[7px] rounded-full bg-success shadow-[0_0_8px_#4ADE80]" />
      </span>,
    );
  } else if (answer === "denied") {
    left = pop("idle", <Spark mode="idle" />);
    right = pop("x", <span className="text-[12px] font-bold text-white/50">✕</span>);
  } else if (moment === "agents") {
    const mode: SparkMode = agentIdx % 3 === 2 ? "done" : "working";
    left = pop(`a${agentIdx % 3}`, <AgentGlyph agent={agent} mode={mode} />);
    right =
      mode === "done"
        ? pop(`c${agentIdx}`, <span className="text-[13px] font-bold text-success">✓</span>)
        : pop(`t${agentIdx}`, <ToolIcon tool={tools[agentIdx % tools.length]} color={AGENT_COLOR[agent]} />);
  } else if (moment === "working") {
    left = pop("w", <Spark mode="working" />);
    right = pop(`t${tool % tools.length}`, <ToolIcon tool={tools[tool % tools.length]} color="#fff" />);
  } else {
    left = pop("t", <Spark mode="thinking" />);
    right = pop("dots", <ThinkingDots />);
  }

  return (
    <NotchShell width={size.w} height={size.h} radius={size.r} flare={size.f} glow={size.glow} glowOpacity={size.o} shake={shake}>
      <div style={{ paddingInline: size.f - 6 }}>
        <Wings left={left} right={right} />
      </div>

      <AnimatePresence mode="popLayout">
        {view === "attention" && (
          <motion.div key="attention" {...fade} className="absolute inset-x-0 top-[32px] px-[22px] pt-3">
            <Close onClick={() => decide("denied")} />
            <div className="flex items-center gap-3.5">
              <span className="grid size-11 shrink-0 place-items-center rounded-full bg-amber/20">
                <motion.svg
                  viewBox="0 0 24 24"
                  className="size-5 text-amber"
                  fill="currentColor"
                  animate={{ rotate: [0, 14, -12, 10, -6, 0, 0] }}
                  transition={{ duration: 1.4, times: [0, 0.1, 0.2, 0.3, 0.38, 0.43, 1], repeat: Infinity }}
                  style={{ transformOrigin: "50% 100%" }}
                  aria-hidden
                >
                  <path d="M8 13V5.5a1.5 1.5 0 0 1 3 0V11h.5V3.5a1.5 1.5 0 0 1 3 0V11h.5V5a1.5 1.5 0 0 1 3 0v6.5h.5V8a1.5 1.5 0 0 1 3 0v6a8 8 0 0 1-8 8h-.6a7 7 0 0 1-5.7-3l-3.5-5a1.5 1.5 0 0 1 2.4-1.8L8 15Z" />
                </motion.svg>
              </span>
              <span className="min-w-0 text-left">
                <span className="flex items-center gap-1.5">
                  <span className="text-[15px] font-semibold">Claude needs you</span>
                  <span className="text-[12px] font-medium text-amber">nosynotch</span>
                </span>
                <span className="mt-0.5 block truncate text-[12px] text-white/70">
                  Bash: <span className="font-mono text-[11.5px]">npm test -- --watch=false</span>
                </span>
              </span>
            </div>
            <div className="mt-2.5 flex items-center gap-2">
              <span className="mr-auto text-[11px] text-white/35">or answer in the terminal</span>
              <Pill onClick={() => decide("denied")}>Deny</Pill>
              <Pill onClick={() => decide("allowed")}>Always allow</Pill>
              <Pill prominent onClick={() => decide("allowed")}>
                Allow
              </Pill>
            </div>
          </motion.div>
        )}

        {view === "done" && (
          <motion.div key="done" {...fade} className="absolute inset-x-0 top-[32px] flex items-center gap-4 px-[22px] pt-3.5 text-left">
            <Close />
            <span className="relative grid size-[52px] shrink-0 place-items-center">
              <Confetti burst={burst} />
              <DrawnCheck size={44} />
            </span>
            <span className="min-w-0">
              <span className="flex items-center gap-1.5">
                <span className="text-[17px] font-semibold">Done</span>
                <span className="text-[13px] font-medium text-success">nosynotch</span>
                <span className="font-mono text-[12px] text-white/50">· {answer === "allowed" ? "0:52" : "1m 12s"}</span>
              </span>
              <span className="mt-0.5 line-clamp-2 block text-[12px] leading-snug text-white/75">
                {answer === "allowed"
                  ? "All 48 tests pass. The parser now handles empty input and trailing commas."
                  : "Fixed the flaky parser test and added two cases for empty input. Ready for review."}
              </span>
            </span>
          </motion.div>
        )}

        {view === "sessions" && (
          <motion.div key="sessions" {...fade} className="absolute inset-x-0 top-[32px] px-[14px] pt-3 text-left">
            {SESSIONS.map((s) => (
              <div key={s.project} className="flex h-[50px] items-center gap-3 rounded-xl px-2.5 hover:bg-white/[0.05]">
                <AgentGlyph agent={s.agent} mode={s.mode} size={20} color={s.mode === "done" ? "#4ADE80" : undefined} />
                <span className="min-w-0 flex-1">
                  <span className="flex items-center gap-1.5">
                    <span className="text-[13px] font-semibold">{s.project}</span>
                    {s.agent !== "claude" && (
                      <span className="rounded-[4px] px-1 py-px text-[9.5px] font-bold" style={{ color: AGENT_COLOR[s.agent], background: `${AGENT_COLOR[s.agent]}22` }}>
                        {AGENT_NAME[s.agent]}
                      </span>
                    )}
                  </span>
                  <span className="block truncate text-[11.5px] text-white/55">{s.status}</span>
                </span>
                {s.ctx > 0 && <ContextRing percent={s.ctx} color={AGENT_COLOR[s.agent]} />}
                <span className="w-9 text-right font-mono text-[11px] text-white/45">{s.time || "✓"}</span>
              </div>
            ))}
            <div className="mx-2.5 mt-2 border-t border-white/[0.08] pt-2">
              {USAGE.map((u) => (
                <div key={u.label} className="flex h-6 items-center gap-2.5 text-[10.5px] text-white/55">
                  <span className="w-11 font-medium" style={{ color: u.color }}>
                    {u.label}
                  </span>
                  {[
                    ["5h", u.five],
                    ["week", u.week],
                  ].map(([l, p]) => (
                    <span key={l as string} className="flex flex-1 items-center gap-1.5">
                      <span className="w-7 font-mono">{l}</span>
                      <span className="h-[5px] flex-1 overflow-hidden rounded-full bg-white/10">
                        <motion.span
                          className="block h-full rounded-full"
                          style={{ background: meterColor(p as number) }}
                          initial={{ width: 0 }}
                          animate={{ width: `${p}%` }}
                          transition={{ duration: 1, delay: 0.35 }}
                        />
                      </span>
                      <span className="w-7 text-right font-mono">{p}%</span>
                    </span>
                  ))}
                </div>
              ))}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </NotchShell>
  );
}
