import { AnimatePresence, motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { MenuBarContent } from "../MenuBar";
import { ease } from "../lib";
import { MomentNotch, type MomentId } from "../notch/MomentNotch";

const MOMENTS: { id: MomentId; title: string; body: string; color: string; clip: string; ms: number }[] = [
  { id: "thinking", title: "Thinking", body: "The notch slides out. The spark turns, three dots wait with you.", color: "#D97757", clip: "thinking", ms: 4200 },
  { id: "working", title: "Working", body: "Terminal, pencil, magnifier, globe: you always see which tool is running.", color: "#D97757", clip: "tools", ms: 5600 },
  { id: "attention", title: "Needs you", body: "Amber glow, a little shake and the exact command. Go on, answer it.", color: "#F5A524", clip: "attention", ms: 9000 },
  { id: "done", title: "Done", body: "A checkmark draws itself, confetti flies, and you read how the answer starts.", color: "#4ADE80", clip: "done", ms: 5200 },
  { id: "unseen", title: "Didn't see it?", body: "A green dot breathes until you look. One gentle reminder after five minutes.", color: "#4ADE80", clip: "unseen", ms: 4200 },
  { id: "sessions", title: "Every session", body: "Hover for all sessions, their context fill and your 5-hour and weekly limits.", color: "#A78BFA", clip: "usage", ms: 6400 },
  { id: "agents", title: "Claude, Codex, Cursor", body: "Each agent has its own mark and colour. Many sessions, one notch.", color: "#80AAFF", clip: "codex", ms: 6000 },
  { id: "music", title: "Music in between", body: "Nothing running? Spotify or Apple Music takes over, until an agent needs the notch again.", color: "#F26B9E", clip: "media", ms: 4600 },
];

/**
 * A strip of Mac screen with the notch rebuilt in the browser: sharp at any size, at the display's
 * frame rate, and live (answer the permission request). A switch shows the real recording instead.
 */
export function Moments() {
  const [index, setIndex] = useState(0);
  const [auto, setAuto] = useState(true);
  const [recorded, setRecorded] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const [onScreen, setOnScreen] = useState(false);
  const box = useRef<HTMLDivElement>(null);
  const m = MOMENTS[index];

  useEffect(() => {
    const io = new IntersectionObserver(([e]) => setOnScreen(e.isIntersecting), { threshold: 0.3 });
    io.observe(box.current!);
    return () => io.disconnect();
  }, []);

  // Progress through the current moment; move on when it is over (only while on screen).
  useEffect(() => {
    setElapsed(0);
    if (!auto || !onScreen) return;
    const start = performance.now();
    const id = setInterval(() => {
      const e = performance.now() - start;
      setElapsed(e);
      if (e >= m.ms) setIndex((i) => (i + 1) % MOMENTS.length);
    }, 50);
    return () => clearInterval(id);
  }, [index, auto, onScreen, m.ms]);

  const pick = (i: number) => {
    setIndex(i);
    setAuto(false);
  };

  return (
    <div ref={box}>
      <div className="relative overflow-hidden rounded-[22px] border border-white/10 bg-black p-1.5 shadow-[0_40px_120px_-40px_rgba(155,123,255,0.45)]">
        <div className="mac-wallpaper relative h-[340px] overflow-hidden rounded-[16px] md:h-[440px]">
          <div className="absolute inset-0 bg-black/10" />
          <MenuBarContent app="Terminal" />
          <div className="absolute left-1/2 top-0 z-10 origin-top -translate-x-1/2 scale-[0.78] sm:scale-100 md:scale-[1.28]">
            {recorded ? null : (
              <MomentNotch
                key={m.id}
                moment={m.id}
                onSettled={() => {
                  // After an answer, give it a moment, then carry on.
                  setAuto(false);
                  setTimeout(() => {
                    setAuto(true);
                    setIndex((i) => (i + 1) % MOMENTS.length);
                  }, 2600);
                }}
              />
            )}
          </div>
          {recorded && (
            <video
              key={m.clip}
              src={`/demo/${m.clip}.mp4`}
              autoPlay
              muted
              loop
              playsInline
              className="absolute inset-x-0 top-0 w-full"
              aria-label={`Recording: ${m.title}`}
            />
          )}
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
              {active && auto && (
                <span className="absolute inset-x-3 bottom-0 h-px">
                  <span className="block h-full" style={{ width: `${Math.min(100, (elapsed / x.ms) * 100)}%`, background: x.color }} />
                </span>
              )}
            </button>
          );
        })}
      </div>

      <div className="mx-auto mt-4 flex min-h-[48px] max-w-[620px] flex-col items-center gap-2 text-center">
        <AnimatePresence mode="wait" initial={false}>
          <motion.p
            key={m.id}
            initial={{ opacity: 0, y: 6, filter: "blur(4px)" }}
            animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
            exit={{ opacity: 0, y: -4, filter: "blur(4px)" }}
            transition={{ duration: 0.3, ease }}
            className="text-[15px] leading-relaxed text-muted-foreground"
          >
            {m.body}
          </motion.p>
        </AnimatePresence>
        <button
          type="button"
          onClick={() => setRecorded((r) => !r)}
          className="cursor-target font-mono text-[11px] text-faint transition-colors hover:text-muted-foreground"
        >
          {recorded ? "● recording from the app · show live" : "● live in your browser · show the real recording"}
        </button>
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
