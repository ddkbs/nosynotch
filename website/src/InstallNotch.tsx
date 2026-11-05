import { AnimatePresence, motion, useAnimationControls } from "motion/react";
import { useEffect, useMemo, useState, type ReactNode } from "react";
import { INSTALL_COMMAND, OPEN_INSTALL, RELEASES_URL, useRepoInfo } from "./lib";

type Stage = "idle" | "ask" | "copied" | "download" | "denied";

const SIZE: Record<Stage, { w: number; h: number; r: number }> = {
  idle: { w: 210, h: 34, r: 14 },
  ask: { w: 580, h: 236, r: 30 },
  copied: { w: 520, h: 178, r: 30 },
  download: { w: 520, h: 178, r: 30 },
  denied: { w: 330, h: 92, r: 26 },
};

/** Phones stack the buttons, so the open notch grows taller there. */
const NARROW_H: Partial<Record<Stage, number>> = { ask: 318, copied: 236, download: 236 };

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

const GLOW: Record<Stage, string> = {
  idle: "rgba(224,137,106,0)",
  ask: "rgba(245,165,36,0.55)",
  copied: "rgba(74,222,128,0.5)",
  download: "rgba(74,222,128,0.5)",
  denied: "rgba(248,113,113,0.35)",
};

const spring = { type: "spring", stiffness: 260, damping: 26, mass: 0.9 } as const;

function Spark({ className = "", spin = false }: { className?: string; spin?: boolean }) {
  return (
    <svg viewBox="0 0 24 24" className={`${className} ${spin ? "animate-[spin-slow_2.6s_linear_infinite]" : ""}`} aria-hidden>
      <path d="M12 2c1 5 3 7 10 10-7 3-9 5-10 10-1-5-3-7-10-10 7-3 9-5 10-10Z" fill="currentColor" />
    </svg>
  );
}

function Clock() {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const id = setInterval(() => setNow(new Date()), 15_000);
    return () => clearInterval(id);
  }, []);
  const day = now.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" });
  const time = now.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
  return (
    <span className="tabular-nums">
      <span className="hidden sm:inline">{day.replace(",", "")}&nbsp;&nbsp;</span>
      {time}
    </span>
  );
}

/** Confetti from the notch, like the app's "Done". */
function Confetti({ burst }: { burst: number }) {
  const bits = useMemo(
    () =>
      Array.from({ length: 34 }, (_, i) => {
        const a = (Math.PI * (0.1 + 0.8 * Math.random())) as number;
        const d = 120 + Math.random() * 190;
        return {
          i,
          x: Math.cos(a) * d * (Math.random() < 0.5 ? -1 : 1),
          y: Math.sin(a) * d * 0.55 + 40,
          r: Math.random() * 540 - 270,
          c: ["#4ADE80", "#E0896A", "#DC6F9C", "#8F7CFF", "#6C9BFF", "#F5A524"][i % 6],
          w: 4 + Math.random() * 4,
          delay: Math.random() * 0.08,
        };
      }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [burst],
  );
  if (!burst) return null;
  return (
    <div className="pointer-events-none absolute left-0 z-20" style={{ top: 150 }} key={burst}>
      {bits.map((b) => (
        <motion.span
          key={b.i}
          className="absolute block rounded-[1px]"
          style={{ width: b.w, height: b.w * 0.45, background: b.c }}
          initial={{ x: 0, y: 0, opacity: 1, rotate: 0 }}
          animate={{ x: b.x, y: [0, b.y - 60, b.y + 90], opacity: [1, 1, 0], rotate: b.r }}
          transition={{ duration: 1.5, delay: b.delay, ease: [0.15, 0.6, 0.35, 1] }}
        />
      ))}
    </div>
  );
}

function Button({
  children,
  onClick,
  href,
  kind = "ghost",
}: {
  children: ReactNode;
  onClick?: () => void;
  href?: string;
  kind?: "ghost" | "primary" | "plain";
}) {
  const cls = {
    ghost: "bg-white/[0.08] text-white/85 hover:bg-white/[0.14]",
    plain: "bg-transparent text-white/55 hover:text-white/90",
    primary:
      "bg-white text-black hover:shadow-[0_0_0_1px_rgba(255,255,255,0.6),0_10px_40px_-8px_#F5A524]",
  }[kind];
  const props = {
    className: `cursor-target inline-flex h-9 items-center justify-center gap-1.5 rounded-full px-4 text-[13.5px] font-medium transition-all duration-300 ${cls}`,
  };
  return href ? (
    <a href={href} onClick={onClick} {...props}>
      {children}
    </a>
  ) : (
    <button type="button" onClick={onClick} {...props}>
      {children}
    </button>
  );
}

function Check() {
  return (
    <svg viewBox="0 0 24 24" className="size-6 text-[#4ADE80]" fill="none" aria-hidden>
      <motion.circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="1.8" initial={{ pathLength: 0 }} animate={{ pathLength: 1 }} transition={{ duration: 0.5 }} />
      <motion.path
        d="m7.5 12.5 3 3 6-7"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        initial={{ pathLength: 0 }}
        animate={{ pathLength: 1 }}
        transition={{ duration: 0.4, delay: 0.35 }}
      />
    </svg>
  );
}

/** Two eyes that look around, offended. */
function Eyes() {
  return (
    <span className="flex gap-1.5" aria-hidden>
      {[0, 1].map((i) => (
        <span key={i} className="relative block h-5 w-4 overflow-hidden rounded-full bg-white">
          <motion.span
            className="absolute left-1/2 top-1/2 block size-2 -translate-x-1/2 -translate-y-1/2 rounded-full bg-black"
            animate={{ x: [0, -4, -4, 4, 4, 0], y: [0, 2, -2, -2, 2, 0] }}
            transition={{ duration: 2.2, ease: "easeInOut" }}
          />
          <motion.span
            className="absolute inset-x-0 top-0 block bg-[#111]"
            animate={{ height: ["0%", "0%", "45%", "45%", "0%"] }}
            transition={{ duration: 2.2, times: [0, 0.6, 0.7, 0.9, 1] }}
          />
        </span>
      ))}
    </span>
  );
}

/**
 * The download menu is a notch. It hangs from the top of a Mac screen, and when you ask for it,
 * it opens the way the app does when an agent needs you: amber glow, a little shake, the exact
 * command, and Deny / Download / Allow. Allow copies the command and throws confetti.
 */
export function InstallNotch() {
  const [stage, setStage] = useState<Stage>("idle");
  const [burst, setBurst] = useState(0);
  const shake = useAnimationControls();
  const { archive, version } = useRepoInfo();
  const narrow = useNarrow();
  const size = { ...SIZE[stage], h: (narrow && NARROW_H[stage]) || SIZE[stage].h };

  const ask = () => {
    setStage("ask");
    void shake.start({ x: [0, -7, 6, -4, 3, 0], transition: { duration: 0.5, delay: 0.25 } });
  };

  useEffect(() => {
    const open = () => window.setTimeout(ask, 450);
    window.addEventListener(OPEN_INSTALL, open);
    return () => window.removeEventListener(OPEN_INSTALL, open);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (stage !== "denied") return;
    const id = window.setTimeout(() => setStage("idle"), 2600);
    return () => clearTimeout(id);
  }, [stage]);

  const allow = async () => {
    try {
      await navigator.clipboard.writeText(INSTALL_COMMAND);
    } catch {
      /* the command is on screen anyway */
    }
    setStage("copied");
    setBurst((b) => b + 1);
  };

  return (
    <div className="relative">
      {/* The screen: wallpaper, menu bar, and the notch in the middle. */}
      <div className="mac-wallpaper relative h-[340px] overflow-hidden rounded-t-[22px] border border-b-0 border-white/10 [mask-image:linear-gradient(to_bottom,black_80%,transparent)] sm:h-[360px]">
        <div className="absolute inset-0 bg-black/10" />
        <div className="relative flex h-8 items-center justify-between px-4 text-[13px] font-medium text-white/90">
          <span className="flex items-center gap-4">
            <span className="font-semibold">Terminal</span>
            <span className="hidden text-white/80 sm:inline">Shell</span>
            <span className="hidden text-white/80 sm:inline">Edit</span>
          </span>
          <span className="flex items-center gap-3.5">
            <Spark className="size-3.5 text-white" />
            <svg viewBox="0 0 24 24" className="hidden size-4 sm:block" fill="currentColor" aria-hidden>
              <path d="M12 18.5a1.6 1.6 0 1 1 0 3.2 1.6 1.6 0 0 1 0-3.2Zm0-5c2 0 3.8.8 5.1 2.1l-1.6 1.6A5 5 0 0 0 12 15.7a5 5 0 0 0-3.5 1.5l-1.6-1.6A7.2 7.2 0 0 1 12 13.5Zm0-5c3.4 0 6.4 1.3 8.7 3.5l-1.6 1.6A10 10 0 0 0 12 10.7a10 10 0 0 0-7.1 2.9l-1.6-1.6A12.3 12.3 0 0 1 12 8.5Z" />
            </svg>
            <Clock />
          </span>
        </div>

        <motion.div
          animate={shake}
          className="absolute left-1/2 top-0 z-10 w-0"
        >
          <motion.div
            role="dialog"
            aria-label="Install Nosy Notch"
            className="absolute left-0 top-0 -translate-x-1/2 overflow-hidden bg-black text-white"
            initial={false}
            animate={{
              width: stage === "idle" ? `min(${size.w}px, 42vw)` : `min(${size.w}px, calc(100vw - 48px))`,
              height: size.h,
              borderBottomLeftRadius: size.r,
              borderBottomRightRadius: size.r,
              boxShadow: `0 18px 60px -10px ${GLOW[stage]}, 0 0 0 1px rgba(255,255,255,${stage === "idle" ? 0.04 : 0.08})`,
            }}
            transition={spring}
          >
            <AnimatePresence mode="popLayout" initial={false}>
              {stage === "idle" && (
                <motion.button
                  key="idle"
                  type="button"
                  onClick={ask}
                  className="cursor-target group absolute inset-0 flex items-center justify-between px-3.5"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0, transition: { duration: 0.1 } }}
                  aria-label="Open the install notch"
                >
                  <Spark className="size-3.5 text-accent" spin />
                  <span className="font-mono text-[11px] text-white/45 transition-colors group-hover:text-white/90">
                    get me
                  </span>
                  <span className="flex items-end gap-[2px]" aria-hidden>
                    {[0, 1, 2, 3].map((i) => (
                      <span
                        key={i}
                        className="w-[2.5px] rounded-full bg-[#F26B9E]"
                        style={{ height: 7, animation: `nav-eq 0.9s ${i * 0.15}s ease-in-out infinite alternate` }}
                      />
                    ))}
                  </span>
                </motion.button>
              )}

              {stage === "ask" && (
                <motion.div
                  key="ask"
                  className="absolute inset-0 flex flex-col px-6 pb-5 pt-10"
                  initial={{ opacity: 0, filter: "blur(6px)" }}
                  animate={{ opacity: 1, filter: "blur(0px)", transition: { delay: 0.15 } }}
                  exit={{ opacity: 0, filter: "blur(6px)", transition: { duration: 0.12 } }}
                >
                  <div className="flex items-center gap-2.5">
                    <motion.span
                      className="text-[18px]"
                      animate={{ rotate: [0, 18, -8, 18, 0] }}
                      transition={{ duration: 1.1, repeat: Infinity, repeatDelay: 1.4 }}
                      aria-hidden
                    >
                      👋
                    </motion.span>
                    <span className="mr-auto text-[13px] font-semibold text-[#F5A524] sm:mr-0">Nosy Notch needs you</span>
                    <span className="ml-auto hidden font-mono text-[11px] text-white/35 sm:inline">
                      {version ? `v${version}` : "latest"} · macOS 14+
                    </span>
                    <button
                      type="button"
                      onClick={() => setStage("idle")}
                      className="cursor-target grid size-6 place-items-center rounded-full bg-white/10 text-[12px] text-white/60 hover:bg-white/20 hover:text-white"
                      aria-label="Close"
                    >
                      ✕
                    </button>
                  </div>
                  <p className="mt-2.5 text-[15px] text-white/85">
                    Install Nosy Notch on this Mac? It wants to run:
                  </p>
                  <div className="mt-2.5 flex items-center gap-2 rounded-xl bg-white/[0.06] px-3.5 py-2.5 font-mono text-[13.5px]">
                    <span className="text-white/35">$</span>
                    <span>{INSTALL_COMMAND}</span>
                    <span className="h-4 w-[7px] animate-blink bg-white/70" aria-hidden />
                    <span className="ml-auto hidden text-[11px] text-white/35 sm:inline">needs Node.js 18+</span>
                  </div>
                  <div className="mt-auto flex flex-wrap items-center justify-end gap-2 pt-3">
                    <Button kind="plain" onClick={() => setStage("denied")}>
                      Deny
                    </Button>
                    <Button href={archive ?? RELEASES_URL} onClick={() => setStage("download")}>
                      Download .app
                    </Button>
                    <Button kind="primary" onClick={allow}>
                      Allow · copy command
                    </Button>
                  </div>
                </motion.div>
              )}

              {(stage === "copied" || stage === "download") && (
                <motion.div
                  key="done"
                  className="absolute inset-0 flex flex-col px-6 pb-5 pt-10"
                  initial={{ opacity: 0, filter: "blur(6px)" }}
                  animate={{ opacity: 1, filter: "blur(0px)", transition: { delay: 0.15 } }}
                  exit={{ opacity: 0, transition: { duration: 0.12 } }}
                >
                  <div className="flex items-center gap-3">
                    <Check />
                    <span className="text-[15px] font-semibold">
                      {stage === "copied" ? "Copied. Paste it into Terminal." : "Downloading Nosy Notch…"}
                    </span>
                    <button
                      type="button"
                      onClick={() => setStage("idle")}
                      className="cursor-target ml-auto grid size-6 place-items-center rounded-full bg-white/10 text-[12px] text-white/60 hover:bg-white/20 hover:text-white"
                      aria-label="Close"
                    >
                      ✕
                    </button>
                  </div>
                  <p className="mt-3 text-[13.5px] leading-relaxed text-white/60">
                    {stage === "copied" ? (
                      <>
                        It downloads the app, connects Claude Code, Codex and Cursor and starts watching.
                        Restart agent sessions that were already running.
                      </>
                    ) : (
                      <>
                        Unpack it, move <span className="text-white/85">Nosy Notch.app</span> to Applications
                        and open it. Settings → Agents connects your agents with one click.
                      </>
                    )}
                  </p>
                  <p className="mt-auto font-mono text-[11px] text-white/35">
                    Codex? Trust the new hooks once: Codex → Settings → Hooks
                  </p>
                </motion.div>
              )}

              {stage === "denied" && (
                <motion.div
                  key="denied"
                  className="absolute inset-0 flex items-center gap-3.5 px-6 pt-5"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1, transition: { delay: 0.12 } }}
                  exit={{ opacity: 0, transition: { duration: 0.1 } }}
                >
                  <Eyes />
                  <span className="text-[13.5px] text-white/75">Fine. I'll just keep watching.</span>
                </motion.div>
              )}
            </AnimatePresence>
          </motion.div>
          <Confetti burst={burst} />
        </motion.div>
      </div>
    </div>
  );
}
