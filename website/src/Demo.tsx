import { AnimatePresence, motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { ease } from "./lib";

type Moment = {
  id: string;
  title: string;
  hint: string;
  body: string;
  /** Height of the recording at 840 px wide. */
  h: number;
  color: string;
};

/** The moments a session goes through, each with its real recording from the app. */
export const MOMENTS: Moment[] = [
  {
    id: "thinking",
    title: "Thinking",
    hint: "prompt sent",
    body: "The notch slides out. The spark turns, three dots wait with you.",
    h: 270,
    color: "#E0896A",
  },
  {
    id: "tools",
    title: "Working",
    hint: "tool running",
    body: "Terminal, pencil, magnifier, globe: you always see which tool is running.",
    h: 270,
    color: "#E0896A",
  },
  {
    id: "attention",
    title: "Needs you",
    hint: "permission",
    body: "Amber glow, a little shake and the exact command. Allow or deny right here, or just nod.",
    h: 270,
    color: "#F5A524",
  },
  {
    id: "done",
    title: "Done",
    hint: "turn finished",
    body: "A checkmark draws itself, confetti flies, and you read how the answer starts.",
    h: 270,
    color: "#4ADE80",
  },
  {
    id: "unseen",
    title: "Didn't see it?",
    hint: "unseen result",
    body: "A green dot breathes in the notch until you look. One gentle reminder after five minutes.",
    h: 270,
    color: "#4ADE80",
  },
  {
    id: "usage",
    title: "Every session",
    hint: "hover",
    body: "Hover for all sessions, how full their context is, and your 5-hour and weekly limits.",
    h: 374,
    color: "#A78BFA",
  },
  {
    id: "codex",
    title: "Codex & Cursor",
    hint: "mixed agents",
    body: "Blue spark for Codex, silver for Cursor, orange for Claude. Many sessions, one notch.",
    h: 300,
    color: "#80AAFF",
  },
  {
    id: "media",
    title: "Music in between",
    hint: "agents idle",
    body: "When nothing runs, Spotify or Apple Music takes over, with an equalizer that follows the beat.",
    h: 254,
    color: "#F26B9E",
  },
];

/** A row of moments next to a screen that plays the real recording; it moves on by itself. */
export function Demo() {
  const [index, setIndex] = useState(0);
  const [progress, setProgress] = useState(0);
  const [auto, setAuto] = useState(true);
  const video = useRef<HTMLVideoElement>(null);
  const moment = MOMENTS[index];

  useEffect(() => {
    const v = video.current;
    if (!v) return;
    setProgress(0);
    v.currentTime = 0;
    void v.play().catch(() => {});
    const onTime = () => setProgress(v.duration ? v.currentTime / v.duration : 0);
    const onEnd = () => {
      if (auto) setIndex((i) => (i + 1) % MOMENTS.length);
      else {
        v.currentTime = 0;
        void v.play().catch(() => {});
      }
    };
    v.addEventListener("timeupdate", onTime);
    v.addEventListener("ended", onEnd);
    return () => {
      v.removeEventListener("timeupdate", onTime);
      v.removeEventListener("ended", onEnd);
    };
  }, [index, auto]);

  // Only play while the demo is on screen.
  useEffect(() => {
    const v = video.current!;
    const io = new IntersectionObserver(([e]) => {
      if (e.isIntersecting) void v.play().catch(() => {});
      else v.pause();
    });
    io.observe(v);
    return () => io.disconnect();
  }, []);

  return (
    <div className="grid gap-4 md:grid-cols-[260px_minmax(0,1fr)]">
      <div
        role="tablist"
        aria-label="Moments"
        className="flex gap-1.5 overflow-x-auto pb-1 md:flex-col md:overflow-visible md:pb-0"
      >
        {MOMENTS.map((m, i) => {
          const active = i === index;
          return (
            <button
              key={m.id}
              role="tab"
              type="button"
              aria-selected={active}
              onClick={() => {
                setIndex(i);
                setAuto(false);
              }}
              className={`cursor-target group relative shrink-0 overflow-hidden rounded-xl border px-3.5 py-2.5 text-left transition-colors duration-300 ${
                active
                  ? "border-white/14 bg-white/[0.05]"
                  : "border-transparent hover:bg-white/[0.03]"
              }`}
            >
              <span className="flex items-center gap-2.5">
                <span
                  className="size-2 shrink-0 rounded-full transition-all duration-500"
                  style={{
                    background: active ? m.color : "rgb(255 255 255 / 0.18)",
                    boxShadow: active ? `0 0 12px ${m.color}` : "none",
                  }}
                />
                <span
                  className={`whitespace-nowrap text-[14.5px] font-medium transition-colors ${
                    active ? "text-foreground" : "text-muted-foreground group-hover:text-foreground"
                  }`}
                >
                  {m.title}
                </span>
                <span className="ml-auto hidden font-mono text-[10.5px] text-faint md:inline">
                  {m.hint}
                </span>
              </span>
              {active && (
                <span className="absolute inset-x-0 bottom-0 h-px bg-white/5">
                  <span
                    className="block h-full"
                    style={{ width: `${progress * 100}%`, background: m.color }}
                  />
                </span>
              )}
            </button>
          );
        })}
      </div>

      <div className="min-w-0">
        <div className="overflow-hidden rounded-2xl border border-border-strong bg-[#0b0b0e] p-1.5 shadow-[0_30px_80px_-30px_rgba(0,0,0,0.9)]">
          <motion.div
            className="relative overflow-hidden rounded-[11px] bg-black"
            animate={{ aspectRatio: `840 / ${moment.h}` }}
            transition={{ duration: 0.6, ease }}
          >
            <video
              ref={video}
              src={`/demo/${moment.id}.mp4`}
              poster={`/demo/${moment.id}.jpg`}
              muted
              playsInline
              preload="auto"
              className="absolute inset-x-0 top-0 block w-full"
              aria-label={`${moment.title}: ${moment.body}`}
            />
          </motion.div>
        </div>
        <div className="mt-4 min-h-[48px] px-1">
          <AnimatePresence mode="wait" initial={false}>
            <motion.p
              key={moment.id}
              initial={{ opacity: 0, y: 6, filter: "blur(4px)" }}
              animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
              exit={{ opacity: 0, y: -4, filter: "blur(4px)" }}
              transition={{ duration: 0.35, ease }}
              className="text-[15px] leading-relaxed text-muted-foreground"
            >
              <span className="text-foreground">{moment.title}.</span> {moment.body}
            </motion.p>
          </AnimatePresence>
        </div>
      </div>
    </div>
  );
}
