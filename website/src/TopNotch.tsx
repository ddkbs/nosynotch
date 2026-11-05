import { AnimatePresence, motion } from "motion/react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { formatStars, INSTALL_COMMAND, OPEN_INSTALL, RELEASES_URL, REPO_URL, useRepoInfo } from "./lib";
import { Confetti, DrawnCheck } from "./notch/Confetti";
import { AGENT_COLOR, CodexGlyph, CursorGlyph, Spark } from "./notch/Glyphs";

// The app's geometry: a 185 × 32 notch, 46 pt wings, 460 pt when it opens.
const H = 32;
const COMPACT_W = 185 + 2 * 46;
const WIDE = 460;
import { cardTransition, expandedTransition, NotchShell } from "./notch/NotchShell";

type Stage =
  | "idle"
  | "open"
  | "copied"
  | "download"
  | "star"
  | "thanks"
  | "denied"
  | "welcome"
  | "sleep"
  | "wake"
  | "peek";

const STAR_AFTER_MS = 45_000;
const SLEEP_AFTER_MS = 20_000;
const SELECTION_LINES = [
  "ooh, juicy. copying that?",
  "I'm reading over your shoulder.",
  "highlighting things? I'm telling Claude.",
  "nice pick. very quotable.",
  "⌘C is right there. just saying.",
  "you missed a spot. kidding.",
];

function useNarrow() {
  const [narrow, setNarrow] = useState(() => matchMedia("(max-width: 639px)").matches);
  useEffect(() => {
    const mq = matchMedia("(max-width: 639px)");
    const on = () => setNarrow(mq.matches);
    mq.addEventListener("change", on);
    return () => mq.removeEventListener("change", on);
  }, []);
  return narrow;
}

/** Text that types itself out when `active` turns on. */
function useTyped(text: string, active: boolean, speed = 38) {
  const [n, setN] = useState(0);
  useEffect(() => {
    if (!active) {
      setN(0);
      return;
    }
    let i = 0;
    const id = setInterval(() => {
      i++;
      setN(i);
      if (i >= text.length) clearInterval(id);
    }, speed);
    return () => clearInterval(id);
  }, [active, text, speed]);
  return text.slice(0, n);
}

/** How far down the page you are, as a ring: the page's "context fill". */
function ScrollRing() {
  const [p, setP] = useState(0);
  useEffect(() => {
    const on = () => {
      const max = document.documentElement.scrollHeight - innerHeight;
      setP(max > 0 ? Math.min(1, scrollY / max) : 0);
    };
    on();
    window.addEventListener("scroll", on, { passive: true });
    return () => window.removeEventListener("scroll", on);
  }, []);
  const r = 6.5;
  const c = 2 * Math.PI * r;
  return (
    <svg viewBox="0 0 18 18" className="size-4 -rotate-90" aria-hidden>
      <circle cx="9" cy="9" r={r} fill="none" stroke="rgba(255,255,255,0.14)" strokeWidth="2.2" />
      <circle cx="9" cy="9" r={r} fill="none" stroke="#A78BFA" strokeWidth="2.2" strokeLinecap="round" strokeDasharray={c} strokeDashoffset={c * (1 - p)} />
    </svg>
  );
}

type EyeMood = "look" | "read" | "sleep" | "wide" | "offended";

/** Two little eyes for the notch's moods. */
function Eyes({ mood, size = 1 }: { mood: EyeMood; size?: number }) {
  const w = 14 * size, h = 18 * size;
  if (mood === "sleep") {
    return (
      <span className="flex gap-2" aria-hidden>
        {[0, 1].map((i) => (
          <svg key={i} width={w} height={h * 0.6} viewBox="0 0 14 10">
            <path d="M2 3c2 4 8 4 10 0" stroke="#fff" strokeWidth="2" strokeLinecap="round" fill="none" opacity=".8" />
          </svg>
        ))}
      </span>
    );
  }
  const pupil =
    mood === "read"
      ? { x: [-3, 3, -3], y: [2, 2, 2] }
      : mood === "offended"
        ? { x: [0, -4, -4, 4, 4, 0], y: [0, 2, -2, -2, 2, 0] }
        : mood === "wide"
          ? { x: 0, y: 0 }
          : { x: [0, 3, -3, 0], y: [0, -1, 1, 0] };
  return (
    <span className="flex gap-1.5" aria-hidden>
      {[0, 1].map((i) => (
        <motion.span
          key={i}
          className="relative block overflow-hidden rounded-full bg-white"
          style={{ width: w, height: h }}
          animate={mood === "wide" ? { scale: [0.6, 1.15, 1] } : { scale: 1 }}
          transition={{ duration: 0.5 }}
        >
          <motion.span
            className="absolute left-1/2 top-1/2 block rounded-full bg-black"
            style={{ width: 7 * size, height: 7 * size, marginLeft: -3.5 * size, marginTop: -3.5 * size }}
            animate={pupil}
            transition={{ duration: mood === "read" ? 1.6 : 2.4, repeat: mood === "offended" ? 0 : Infinity, ease: "easeInOut" }}
          />
          <motion.span
            className="absolute inset-x-0 top-0 block bg-[#121212]"
            animate={{ height: mood === "offended" ? ["0%", "0%", "42%", "42%", "0%"] : ["0%", "0%", "100%", "0%"] }}
            transition={
              mood === "offended"
                ? { duration: 2.2, times: [0, 0.6, 0.7, 0.9, 1] }
                : { duration: 3.6, times: [0, 0.92, 0.95, 1], repeat: Infinity }
            }
          />
        </motion.span>
      ))}
    </span>
  );
}

/** Floating z's while the notch sleeps. */
function Zzz() {
  return (
    <span className="relative block h-6 w-6" aria-hidden>
      {[0, 1, 2].map((i) => (
        <motion.span
          key={i}
          className="absolute bottom-0 left-1 font-mono font-bold text-violet"
          style={{ fontSize: 9 + i * 2 }}
          initial={{ opacity: 0, x: 0, y: 0 }}
          animate={{ opacity: [0, 1, 0], x: [0, 6, 10], y: [0, -10, -20] }}
          transition={{ duration: 2.4, delay: i * 0.8, repeat: Infinity, ease: "easeOut" }}
        >
          z
        </motion.span>
      ))}
    </span>
  );
}

function StarIcon({ className = "", style }: { className?: string; style?: React.CSSProperties }) {
  return (
    <svg viewBox="0 0 24 24" className={className} style={style} fill="currentColor" aria-hidden>
      <path d="M10.79 3.21c.45-1.08 1.97-1.08 2.42 0l2.08 5 5.4.44c1.17.1 1.64 1.55.75 2.3l-4.11 3.53 1.25 5.27c.27 1.14-.96 2.03-1.96 1.43L12 18.35 7.37 21.18c-1 .6-2.23-.29-1.96-1.43l1.26-5.27L2.56 10.95c-.89-.76-.42-2.21.75-2.3l5.4-.44 2.08-5Z" />
    </svg>
  );
}

/** A star with sparkles orbiting it. */
function StarBurst() {
  return (
    <span className="relative grid size-12 shrink-0 place-items-center" aria-hidden>
      <motion.span animate={{ rotate: [0, -12, 10, 0], scale: [1, 1.12, 1] }} transition={{ duration: 1.8, repeat: Infinity, ease: "easeInOut" }}>
        <StarIcon className="size-8 text-[#FFD45A] drop-shadow-[0_0_12px_#FFD45A]" />
      </motion.span>
      {[0, 1, 2, 3].map((i) => (
        <motion.span
          key={i}
          className="absolute size-1 rounded-full bg-[#FFE89A]"
          animate={{ rotate: 360 }}
          transition={{ duration: 3 + i * 0.7, repeat: Infinity, ease: "linear" }}
          style={{ left: "50%", top: "50%", transformOrigin: `${-14 - i * 3}px 0px` }}
        />
      ))}
    </span>
  );
}

function Tile({
  children,
  onClick,
  href,
  primary,
  hint,
}: {
  children: ReactNode;
  onClick?: () => void;
  href?: string;
  primary?: boolean;
  hint?: ReactNode;
}) {
  const cls = `cursor-target group relative flex h-[46px] flex-1 items-center justify-center gap-2 overflow-hidden rounded-[14px] text-[13px] font-semibold transition-all duration-300 hover:-translate-y-0.5 ${
    primary
      ? "bg-white text-black shadow-[0_8px_30px_-8px_rgba(176,77,255,0.9)] hover:shadow-[0_10px_40px_-6px_rgba(255,79,154,0.9)]"
      : "bg-white/[0.07] text-white/90 ring-1 ring-white/10 hover:bg-white/[0.12] hover:ring-white/20"
  }`;
  const inner = (
    <>
      {primary && (
        <span className="absolute inset-y-0 -left-1/2 w-1/3 -skew-x-12 bg-gradient-to-r from-transparent via-black/10 to-transparent transition-transform duration-700 group-hover:translate-x-[420%]" />
      )}
      {children}
      {hint && <span className={`font-mono text-[10.5px] font-normal ${primary ? "text-black/40" : "text-white/35"}`}>{hint}</span>}
    </>
  );
  return href ? (
    <a href={href} target={href.startsWith("http") ? "_blank" : undefined} rel="noreferrer" onClick={onClick} className={cls}>
      {inner}
    </a>
  ) : (
    <button type="button" onClick={onClick} className={cls}>
      {inner}
    </button>
  );
}

function formatAway(ms: number) {
  const s = Math.round(ms / 1000);
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  return m < 60 ? `${m}m ${s % 60}s` : `${Math.floor(m / 60)}h ${m % 60}m`;
}


/** The strip at notch height: something on the left wing, something on the right, like `claudeHeader`. */
function Wings({ left, right }: { left?: ReactNode; right?: ReactNode }) {
  const pop = (node: ReactNode, key: string) => (
    <motion.span
      key={key}
      className="grid place-items-center"
      initial={{ scale: 0.2, opacity: 0 }}
      animate={{ scale: 1, opacity: 1 }}
      exit={{ scale: 0.2, opacity: 0 }}
      transition={{ type: "spring", stiffness: 224, damping: 22.1 }}
    >
      {node}
    </motion.span>
  );
  return (
    <div className="flex items-center justify-between px-1" style={{ height: H }}>
      <span className="grid w-8 place-items-center">
        <AnimatePresence mode="popLayout" initial={false}>
          {left && pop(left, (left as { key?: string }).key ?? "l")}
        </AnimatePresence>
      </span>
      <span className="grid w-8 place-items-center">
        <AnimatePresence mode="popLayout" initial={false}>
          {right && pop(right, (right as { key?: string }).key ?? "r")}
        </AnimatePresence>
      </span>
    </div>
  );
}

function Pill({ children, onClick, href, kind = "quiet" }: { children: ReactNode; onClick?: () => void; href?: string; kind?: "quiet" | "gold" }) {
  const cls = `cursor-target inline-flex h-[26px] items-center gap-1.5 rounded-full px-3.5 text-[12px] font-semibold transition-colors ${
    kind === "gold" ? "bg-[#FFD45A]/90 text-black hover:bg-[#FFD45A]" : "bg-white/[0.11] text-white/90 hover:bg-white/20"
  }`;
  return href ? (
    <a href={href} target="_blank" rel="noreferrer" onClick={onClick} className={cls}>
      {children}
    </a>
  ) : (
    <button type="button" onClick={onClick} className={cls}>
      {children}
    </button>
  );
}

/**
 * The site's own notch, behaving like the app: compact at rest, open the moment the pointer is
 * over it (its rect plus 6 pt), closed the moment it leaves, on the app's spring, with the app's
 * transitions. Opened from a button it stays until closed. It also asks for a star, says welcome
 * back, falls asleep when you idle and gets curious when you select text.
 */
export function TopNotch() {
  const [stage, setStage] = useState<Stage>("idle");
  const [pinned, setPinned] = useState(false);
  const [shake, setShake] = useState(0);
  const [burst, setBurst] = useState(0);
  const [away, setAway] = useState(0);
  const [line, setLine] = useState(SELECTION_LINES[0]);
  const [copiedSel, setCopiedSel] = useState(false);
  const [vw, setVw] = useState(() => window.innerWidth);
  const stageRef = useRef(stage);
  stageRef.current = stage;
  const pinnedRef = useRef(pinned);
  pinnedRef.current = pinned;
  const narrow = useNarrow();
  const { archive, version, stars } = useRepoInfo();
  const typed = useTyped(INSTALL_COMMAND, stage === "open");

  useEffect(() => {
    const on = () => setVw(window.innerWidth);
    window.addEventListener("resize", on);
    return () => window.removeEventListener("resize", on);
  }, []);

  const calm = () => ["idle", "sleep", "welcome", "peek", "wake"].includes(stageRef.current);

  const open = (pin: boolean) => {
    setStage("open");
    if (pin) setPinned(true);
  };
  const close = () => {
    setPinned(false);
    setStage("idle");
  };

  useEffect(() => {
    const on = () => open(true);
    window.addEventListener(OPEN_INSTALL, on);
    return () => window.removeEventListener(OPEN_INSTALL, on);
  }, []);

  // After a while on the page, ask for a star once per visit.
  useEffect(() => {
    let asked = false;
    try {
      asked = sessionStorage.getItem("nosy-star-asked") === "1";
    } catch {
      /* ignore */
    }
    if (asked) return;
    const id = setTimeout(() => {
      if (!calm()) return;
      try {
        sessionStorage.setItem("nosy-star-asked", "1");
      } catch {
        /* ignore */
      }
      setStage("star");
      setShake((s) => s + 1);
    }, STAR_AFTER_MS);
    return () => clearTimeout(id);
  }, []);

  // Welcome back after switching tabs.
  useEffect(() => {
    let left = 0;
    const on = () => {
      if (document.hidden) left = Date.now();
      else if (left && Date.now() - left > 4000 && calm()) {
        setAway(Date.now() - left);
        setStage("welcome");
      }
    };
    document.addEventListener("visibilitychange", on);
    return () => document.removeEventListener("visibilitychange", on);
  }, []);

  // Fall asleep when nothing happens; wake up on any activity.
  useEffect(() => {
    let timer = 0;
    const arm = () => {
      clearTimeout(timer);
      timer = window.setTimeout(() => {
        if (stageRef.current === "idle") setStage("sleep");
      }, SLEEP_AFTER_MS);
    };
    const activity = () => {
      if (stageRef.current === "sleep") setStage("wake");
      arm();
    };
    arm();
    const evs = ["pointermove", "scroll", "keydown", "pointerdown"] as const;
    evs.forEach((e) => window.addEventListener(e, activity, { passive: true }));
    return () => {
      clearTimeout(timer);
      evs.forEach((e) => window.removeEventListener(e, activity));
    };
  }, []);

  // Curious about selected text.
  useEffect(() => {
    let i = Math.floor(Math.random() * SELECTION_LINES.length);
    let last = "";
    const on = () => {
      const text = document.getSelection()?.toString().trim() ?? "";
      if (text.length >= 3 && text !== last) {
        last = text;
        if (calm()) {
          i = (i + 1) % SELECTION_LINES.length;
          setLine(SELECTION_LINES[i]);
          setCopiedSel(false);
          setStage("peek");
        }
      } else if (!text) {
        last = "";
        if (stageRef.current === "peek") setStage("idle");
      }
    };
    document.addEventListener("selectionchange", on);
    return () => document.removeEventListener("selectionchange", on);
  }, []);

  // Flashes fold away by themselves, like the app's flash(for:).
  useEffect(() => {
    const after: Partial<Record<Stage, [number, Stage]>> = {
      denied: [2600, "idle"],
      welcome: [3600, "idle"],
      wake: [1500, "idle"],
      thanks: [3200, "idle"],
      copied: [3200, "star"],
      download: [3600, "star"],
    };
    const a = after[stage];
    if (!a) return;
    const id = setTimeout(() => {
      if (a[1] === "star") {
        try {
          if (sessionStorage.getItem("nosy-starred") === "1") return setStage("idle");
          sessionStorage.setItem("nosy-star-asked", "1");
        } catch {
          /* ignore */
        }
      }
      setPinned(false);
      setStage(a[1]);
    }, a[0]);
    return () => clearTimeout(id);
  }, [stage]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && !calm() && close();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(INSTALL_COMMAND);
    } catch {
      /* the command is on screen anyway */
    }
    setStage("copied");
    setTimeout(() => setBurst((b) => b + 1), 200);
  };
  const starred = () => {
    try {
      sessionStorage.setItem("nosy-starred", "1");
    } catch {
      /* ignore */
    }
    setStage("thanks");
    setTimeout(() => setBurst((b) => b + 1), 150);
  };

  // NotchViewModel.size: compact = notch + wings; everything else opens to 460 pt.
  const wide = Math.min(WIDE, vw - 16);
  const S: Record<Stage, { w: number; h: number; t: number; b: number; glow: string; o: number }> = {
    idle: { w: COMPACT_W, h: H, t: 6, b: 12, glow: "#A78BFA", o: 0.18 },
    sleep: { w: COMPACT_W, h: H, t: 6, b: 12, glow: "#A78BFA", o: 0 },
    wake: { w: COMPACT_W, h: H, t: 6, b: 12, glow: "#A78BFA", o: 0.45 },
    open: { w: wide, h: H + (narrow ? 308 : 202), t: 14, b: 26, glow: "#000000", o: 0 },
    copied: { w: wide, h: H + 104, t: 14, b: 26, glow: "#4ADE80", o: 0.55 },
    download: { w: wide, h: H + 104, t: 14, b: 26, glow: "#4ADE80", o: 0.55 },
    star: { w: wide, h: H + 88 + 40, t: 14, b: 26, glow: "#FFD45A", o: 0.55 },
    thanks: { w: wide, h: H + 88, t: 14, b: 26, glow: "#FFD45A", o: 0.55 },
    denied: { w: wide, h: H + 88, t: 14, b: 26, glow: "#F87171", o: 0.55 },
    welcome: { w: wide, h: H + 88, t: 14, b: 26, glow: "#4ADE80", o: 0.55 },
    peek: { w: wide, h: H + 88, t: 14, b: 26, glow: "#A78BFA", o: 0.55 },
  };
  const size = S[stage];

  // The wings, per state, like the app's header.
  const wings: Record<Stage, [ReactNode, ReactNode]> = {
    idle: [<Spark key="s-idle" mode="idle" color="#A78BFA" />, <ScrollRing key="ring" />],
    sleep: [<Zzz key="zzz" />, <Eyes key="sleep" mood="sleep" size={0.55} />],
    wake: [<Spark key="s-work" mode="working" color="#A78BFA" />, <Eyes key="wide" mood="wide" size={0.55} />],
    open: [<Spark key="s-think" mode="thinking" color="#B04DFF" />, <ScrollRing key="ring" />],
    copied: [<Spark key="s-done" mode="done" color="#4ADE80" />, null],
    download: [<Spark key="s-done" mode="done" color="#4ADE80" />, null],
    star: [<StarIcon key="star" className="size-[15px] text-[#FFD45A]" />, null],
    thanks: [<StarIcon key="star" className="size-[15px] text-[#FFD45A]" />, null],
    denied: [<Spark key="s-err" mode="error" color="#F87171" />, null],
    welcome: [<Spark key="s-idle" mode="idle" color="#A78BFA" />, <span key="dot" className="size-[7px] rounded-full bg-success shadow-[0_0_8px_#4ADE80]" />],
    peek: [<Spark key="s-think" mode="thinking" color="#A78BFA" />, null],
  };

  const card = (key: string, children: ReactNode, className = "") => (
    <motion.div key={key} {...cardTransition} className={`absolute inset-x-0 top-[32px] px-[22px] pt-3 text-left ${className}`}>
      {children}
    </motion.div>
  );

  return (
    // Hover area: the notch plus 6 pt around it, like NotchWindow.updateHover().
    <div
      className="-m-1.5 p-1.5"
      onMouseEnter={() => calm() && open(false)}
      onMouseLeave={() => {
        if (stageRef.current === "open" && !pinnedRef.current) setStage("idle");
      }}
    >
      <div className="relative">
        <NotchShell width={size.w} height={size.h} topRadius={size.t} bottomRadius={size.b} glow={size.glow} glowOpacity={size.o} shake={shake}>
          <button
            type="button"
            onClick={() => (stage === "open" ? undefined : open(true))}
            aria-label="Install Nosy Notch"
            className="cursor-target block w-full"
          >
            <Wings left={wings[stage][0]} right={wings[stage][1]} />
          </button>

          <AnimatePresence initial={false}>
            {stage === "open" && (
              <motion.div key="open" {...expandedTransition} className="absolute inset-x-0 top-[32px] px-2 pt-3 text-left">
                <div className="flex items-center gap-3">
                  <span className="relative grid size-10 shrink-0 place-items-center rounded-[12px] bg-gradient-to-b from-[#1b1b22] to-[#0b0b0f] shadow-[inset_0_0_0_1px_rgba(255,255,255,0.1),0_6px_20px_-6px_rgba(176,77,255,0.7)]">
                    <span className="absolute left-1/2 top-0 h-[8px] w-[20px] -translate-x-1/2 rounded-b-[5px] bg-black shadow-[0_0_0_1px_rgba(255,255,255,0.08)]" />
                    <span className="mt-1.5">
                      <Spark mode="thinking" color="#B04DFF" size={18} />
                    </span>
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="flex items-center gap-1.5">
                      <span className="text-[15px] font-semibold">Nosy Notch</span>
                      <span className="text-[12px] font-medium text-violet">v{version ?? "0.2.0"}</span>
                    </span>
                    <span className="block truncate text-[12px] text-white/55">Your notch, keeping an eye on your agents.</span>
                  </span>
                  <span className="hidden items-center gap-1.5 sm:flex" title="Works with Claude Code, Codex and Cursor">
                    <Spark mode="idle" size={14} color={AGENT_COLOR.claude} />
                    <CodexGlyph mode="idle" size={14} />
                    <CursorGlyph mode="idle" size={14} />
                  </span>
                  {pinned && (
                    <button
                      type="button"
                      onClick={close}
                      aria-label="Close"
                      className="cursor-target grid size-[18px] place-items-center rounded-full bg-white/10 text-[9px] text-white/60 hover:bg-white/20 hover:text-white"
                    >
                      ✕
                    </button>
                  )}
                </div>

                <button
                  type="button"
                  onClick={copy}
                  className="cursor-target group mt-2.5 flex h-10 w-full items-center gap-2 rounded-xl bg-white/[0.06] px-3.5 text-left font-mono text-[13px] transition-colors hover:bg-white/[0.1]"
                >
                  <span className="text-white/35">$</span>
                  <span>{typed}</span>
                  <span className="-ml-1 h-4 w-[7px] animate-blink bg-white/80" aria-hidden />
                  <span className="ml-auto text-[10.5px] text-white/35 transition-colors group-hover:text-white/80">click to copy</span>
                </button>

                <div className={`mt-2.5 flex gap-2 ${narrow ? "flex-col" : ""}`}>
                  <Tile primary onClick={copy}>
                    <svg viewBox="0 0 24 24" className="size-4" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
                      <path d="m5 7 5 5-5 5M12.5 17H19" />
                    </svg>
                    Copy & install
                  </Tile>
                  <Tile href={archive ?? RELEASES_URL} onClick={() => setStage("download")}>
                    <svg viewBox="0 0 24 24" className="size-4" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
                      <path d="M12 4v11m0 0-4.5-4.5M12 15l4.5-4.5M5 20h14" />
                    </svg>
                    Download
                  </Tile>
                  <Tile href={REPO_URL} onClick={starred} hint={stars ? formatStars(stars) : undefined}>
                    <StarIcon className="size-4 text-[#FFD45A] transition-transform duration-500 group-hover:rotate-[72deg] group-hover:scale-125" />
                    Star
                  </Tile>
                </div>

                <div className="mt-2.5 flex items-center justify-between font-mono text-[10.5px] text-white/35">
                  <span>macOS 14+ · Node 18+ · free</span>
                  <button type="button" onClick={() => setStage("denied")} className="cursor-target transition-colors hover:text-white/80">
                    nah, not today
                  </button>
                </div>
              </motion.div>
            )}

            {(stage === "copied" || stage === "download") &&
              card(
                "done",
                <div className="flex items-center gap-4 pt-0.5">
                  <DrawnCheck size={46} />
                  <span className="min-w-0">
                    <span className="flex items-center gap-1.5">
                      <span className="text-[17px] font-semibold">{stage === "copied" ? "Copied" : "Downloading"}</span>
                      <span className="text-[13px] font-medium text-success">nosynotch</span>
                    </span>
                    <span className="mt-0.5 block text-[12px] leading-snug text-white/75">
                      {stage === "copied"
                        ? "Paste it into Terminal. It installs, connects your agents and starts watching."
                        : "Unpack it, move it to Applications and open it. Settings → Agents does the rest."}
                    </span>
                  </span>
                </div>,
              )}

            {stage === "star" &&
              card(
                "star",
                <>
                  <div className="flex items-center gap-3.5">
                    <StarBurst />
                    <span className="min-w-0">
                      <span className="flex items-center gap-1.5">
                        <span className="text-[15px] font-semibold">Nosy Notch needs you</span>
                        <span className="text-[12px] font-medium text-[#FFD45A]">GitHub</span>
                      </span>
                      <span className="mt-0.5 block text-[12px] text-white/70">A star helps other devs find me. I'll watch extra closely.</span>
                    </span>
                  </div>
                  <div className="mt-2.5 flex items-center gap-2">
                    <span className="mr-auto text-[11px] text-white/35">or press Esc</span>
                    <Pill onClick={close}>Maybe later</Pill>
                    <Pill kind="gold" href={REPO_URL} onClick={starred}>
                      <StarIcon className="size-3" /> Star {stars ? <span className="font-mono text-[11px] text-black/50">{formatStars(stars)}</span> : null}
                    </Pill>
                  </div>
                </>,
              )}

            {stage === "thanks" &&
              card(
                "thanks",
                <div className="flex items-center gap-3.5 pt-1">
                  <StarIcon className="size-9 text-[#FFD45A] drop-shadow-[0_0_12px_#FFD45A]" />
                  <span className="text-[13.5px] font-medium">You're the best. Watching extra closely now.</span>
                  <Eyes mood="look" size={0.75} />
                </div>,
              )}

            {stage === "denied" &&
              card(
                "denied",
                <div className="flex items-center gap-3.5 pt-1.5">
                  <Eyes mood="offended" />
                  <span className="text-[14px] text-white/85">Fine. I'll just keep watching.</span>
                </div>,
              )}

            {stage === "welcome" &&
              card(
                "welcome",
                <div className="flex items-center gap-3.5 pt-1.5">
                  <span className="relative grid size-11 place-items-center rounded-full bg-success/15">
                    <span className="absolute size-5 rounded-full bg-success/30" style={{ animation: "breathe 2s ease-in-out infinite" }} />
                    <span className="size-2.5 rounded-full bg-success shadow-[0_0_10px_#4ADE80]" />
                  </span>
                  <span>
                    <span className="block text-[15px] font-semibold">Welcome back</span>
                    <span className="block text-[12px] text-white/70">
                      You were gone <span className="font-mono text-success">{formatAway(away)}</span>. I kept watching.
                    </span>
                  </span>
                </div>,
              )}

            {stage === "peek" &&
              card(
                "peek",
                <div className="flex items-center gap-3.5 pt-1.5">
                  <Eyes mood="read" size={0.9} />
                  <span className="min-w-0 flex-1 truncate text-[13.5px] text-white/85">{copiedSel ? "copied. our little secret." : line}</span>
                  <Pill
                    onClick={async () => {
                      try {
                        await navigator.clipboard.writeText(document.getSelection()?.toString() ?? "");
                      } catch {
                        /* ignore */
                      }
                      setCopiedSel(true);
                    }}
                  >
                    {copiedSel ? "✓" : "Copy"}
                  </Pill>
                </div>,
              )}
          </AnimatePresence>
        </NotchShell>

        {/* Confetti flies out of the notch, not clipped by it. */}
        <span className="pointer-events-none absolute left-1/2" style={{ top: size.h - 40 }}>
          <Confetti burst={burst} count={44} spread={2} />
        </span>
      </div>
    </div>
  );
}
