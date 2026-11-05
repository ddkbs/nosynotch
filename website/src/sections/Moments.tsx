import { AnimatePresence, motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { MenuBarContent } from "../MenuBar";
import { MomentNotch, type MomentId } from "../notch/MomentNotch";

const MOMENTS: { id: MomentId; title: string; color: string; ms: number }[] = [
  { id: "thinking", title: "Thinking", color: "#D97757", ms: 4200 },
  { id: "working", title: "Working", color: "#D97757", ms: 5600 },
  { id: "attention", title: "Needs you", color: "#F5A524", ms: 9000 },
  { id: "done", title: "Done", color: "#4ADE80", ms: 5200 },
  { id: "unseen", title: "Didn't see it?", color: "#4ADE80", ms: 4200 },
  { id: "sessions", title: "Every session", color: "#A78BFA", ms: 6400 },
  { id: "agents", title: "Claude, Codex, Cursor", color: "#80AAFF", ms: 6000 },
  { id: "music", title: "Music in between", color: "#F26B9E", ms: 4600 },
];

/**
 * A strip of Mac screen with the notch rebuilt in the browser: sharp at any size, at the display's
 * frame rate, and live (answer the permission request). A switch shows the real recording instead.
 */
export function Moments() {
  const [index, setIndex] = useState(0);
  const [round, setRound] = useState(0);
  const [progress, setProgress] = useState(0);
  // When the current moment ends; an answer in "Needs you" shortens it to a short look at the result.
  const span = useRef({ start: 0, end: 0 });
  const [onScreen, setOnScreen] = useState(false);
  const box = useRef<HTMLDivElement>(null);
  const m = MOMENTS[index];

  useEffect(() => {
    const io = new IntersectionObserver(([e]) => setOnScreen(e.isIntersecting), { threshold: 0.3 });
    io.observe(box.current!);
    return () => io.disconnect();
  }, []);

  // Always move on after the moment's time, also after picking one (only while on screen).
  useEffect(() => {
    setProgress(0);
    if (!onScreen) return;
    const start = performance.now();
    span.current = { start, end: start + m.ms };
    const id = setInterval(() => {
      const now = performance.now();
      const { start: s0, end } = span.current;
      setProgress(Math.min(1, (now - s0) / (end - s0)));
      if (now >= end) setIndex((i) => (i + 1) % MOMENTS.length);
    }, 50);
    return () => clearInterval(id);
  }, [index, round, onScreen, m.ms]);

  const pick = (i: number) => {
    setIndex(i);
    setRound((r) => r + 1);
  };

  return (
    <div ref={box}>
      <div className="relative overflow-hidden rounded-[22px] border border-white/10 bg-black p-1.5 shadow-[0_40px_120px_-40px_rgba(155,123,255,0.45)]">
        <div className="mac-wallpaper relative h-[340px] overflow-hidden rounded-[16px] md:h-[440px]">
          <div className="absolute inset-0 bg-black/10" />
          <MenuBarContent app="Terminal" />
          <div className="absolute left-1/2 top-0 z-10 origin-top -translate-x-1/2 scale-[0.78] sm:scale-100 md:scale-[1.28]">
            <MomentNotch
                key={m.id}
                moment={m.id}
                onSettled={() => {
                  // After an answer, show the result for a moment, then carry on.
                  const now = performance.now();
                  span.current = { start: span.current.start, end: Math.min(span.current.end, now + 2800) };
                }}
              />
          </div>
          {/* Terminal window peeking in from below, so the strip reads as a real desktop. */}
          <div className="absolute inset-x-[8%] bottom-[-40px] h-[150px] rounded-t-xl border border-white/15 bg-black/70 p-4 font-mono text-[12px] text-white/70 backdrop-blur-xl sm:inset-x-[18%]">
            <div className="mb-3 flex gap-1.5">
              <span className="size-2.5 rounded-full bg-[#ff5f57]" />
              <span className="size-2.5 rounded-full bg-[#febc2e]" />
              <span className="size-2.5 rounded-full bg-[#28c840]" />
            </div>
            <AnimatePresence mode="wait">
              <motion.div key={m.id} initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.25 }}>
                <span className="text-white/35">~/nosynotch $</span> {TERMINAL[m.id]}
                <span className="ml-1 inline-block h-3.5 w-[7px] translate-y-0.5 animate-blink bg-white/60" />
              </motion.div>
            </AnimatePresence>
          </div>
        </div>
      </div>

      <div className="mt-5 flex flex-wrap items-center justify-center gap-1.5">
        {MOMENTS.map((x, i) => {
          const active = i === index;
          return (
            <button
              key={x.id}
              type="button"
              onClick={() => pick(i)}
              aria-pressed={active}
              className="cursor-target relative overflow-hidden rounded-full p-px"
            >
              {active && <motion.span layoutId="moment-beam" className="beam absolute inset-0 rounded-full" style={{ ["--beam" as string]: x.color }} />}
              <span
                className={`relative flex items-center gap-2 rounded-full px-3.5 py-1.5 text-[13px] font-medium transition-colors ${
                  active ? "bg-[#0d0d10] text-foreground" : "bg-white/[0.04] text-muted-foreground hover:text-foreground"
                }`}
              >
                <span className="size-1.5 rounded-full" style={{ background: active ? x.color : "rgb(255 255 255 / 0.25)", boxShadow: active ? `0 0 10px ${x.color}` : "none" }} />
                {x.title}
              </span>
              {active && (
                <span className="absolute inset-x-3 bottom-0 h-px">
                  <span className="block h-full" style={{ width: `${progress * 100}%`, background: x.color }} />
                </span>
              )}
            </button>
          );
        })}
      </div>

    </div>
  );
}

const TERMINAL: Record<MomentId, string> = {
  thinking: "claude \"why does the parser drop the last line?\"",
  working: "claude  ⏺ Read Parser.swift  ⏺ Edit Parser.swift",
  attention: "claude  ⏺ Bash(npm test -- --watch=false)  waiting…",
  done: "claude  ✓ Fixed the flaky parser test",
  unseen: "# you were in Slack. The notch kept the result for you.",
  sessions: "claude · codex · cursor  — 3 sessions",
  agents: "codex \"add rate limiting to /login\"",
  music: "# nothing running. ♪",
};
