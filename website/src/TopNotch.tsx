import { AnimatePresence, motion } from "motion/react";
import { useEffect, useState, type ReactNode } from "react";
import { INSTALL_COMMAND, OPEN_INSTALL, RELEASES_URL, useRepoInfo } from "./lib";
import { Confetti, DrawnCheck } from "./notch/Confetti";
import { Spark } from "./notch/Glyphs";
import { NotchShell } from "./notch/NotchShell";

type Stage = "idle" | "peek" | "ask" | "copied" | "download" | "denied";

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

/** Two eyes that look around, offended, and blink. */
function Eyes() {
  return (
    <span className="flex gap-1.5" aria-hidden>
      {[0, 1].map((i) => (
        <span key={i} className="relative block h-5 w-4 overflow-hidden rounded-full bg-white">
          <motion.span
            className="absolute left-1/2 top-1/2 -ml-1 -mt-1 block size-2 rounded-full bg-black"
            animate={{ x: [0, -4, -4, 4, 4, 0], y: [0, 2, -2, -2, 2, 0] }}
            transition={{ duration: 2.2, ease: "easeInOut" }}
          />
          <motion.span
            className="absolute inset-x-0 top-0 block bg-[#151515]"
            animate={{ height: ["0%", "0%", "45%", "45%", "0%"] }}
            transition={{ duration: 2.2, times: [0, 0.6, 0.7, 0.9, 1] }}
          />
        </span>
      ))}
    </span>
  );
}

function Btn({ children, onClick, href, kind = "ghost" }: { children: ReactNode; onClick?: () => void; href?: string; kind?: "ghost" | "primary" | "plain" }) {
  const cls = {
    ghost: "bg-white/[0.1] text-white/90 hover:bg-white/[0.18]",
    plain: "text-white/55 hover:text-white",
    primary: "bg-amber text-black hover:shadow-[0_0_24px_-2px_#F5A524]",
  }[kind];
  const className = `cursor-target inline-flex h-[30px] items-center rounded-full px-4 text-[12.5px] font-semibold transition-all ${cls}`;
  return href ? (
    <a href={href} onClick={onClick} className={className}>
      {children}
    </a>
  ) : (
    <button type="button" onClick={onClick} className={className}>
      {children}
    </button>
  );
}

const fade = {
  initial: { opacity: 0, filter: "blur(6px)" },
  animate: { opacity: 1, filter: "blur(0px)", transition: { delay: 0.14, duration: 0.3 } },
  exit: { opacity: 0, filter: "blur(4px)", transition: { duration: 0.12 } },
};

/**
 * The site's own notch, hanging from the top of the window wherever you are on the page. It
 * reads along (a ring for how far you've scrolled), peeks on hover, and opens into the install
 * request like the app asks for permission: Deny / Download / Allow.
 */
export function TopNotch() {
  const [stage, setStage] = useState<Stage>("idle");
  const [shake, setShake] = useState(0);
  const [burst, setBurst] = useState(0);
  const narrow = useNarrow();
  const { archive, version } = useRepoInfo();

  const ask = () => {
    setStage("ask");
    setTimeout(() => setShake((s) => s + 1), 300);
  };

  useEffect(() => {
    window.addEventListener(OPEN_INSTALL, ask);
    return () => window.removeEventListener(OPEN_INSTALL, ask);
  }, []);

  useEffect(() => {
    if (stage !== "denied") return;
    const id = setTimeout(() => setStage("idle"), 2600);
    return () => clearTimeout(id);
  }, [stage]);

  useEffect(() => {
    if (stage === "idle" || stage === "peek") return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setStage("idle");
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [stage]);

  const allow = async () => {
    try {
      await navigator.clipboard.writeText(INSTALL_COMMAND);
    } catch {
      /* the command is on screen anyway */
    }
    setStage("copied");
    setTimeout(() => setBurst((b) => b + 1), 250);
  };

  const wide = narrow ? "calc(100vw - 20px)" : 520;
  const size = {
    idle: { w: 236, h: 32, r: 12, f: 6, glow: "#A78BFA", o: 0.25 },
    peek: { w: 300, h: 40, r: 16, f: 8, glow: "#A78BFA", o: 0.45 },
    ask: { w: wide, h: narrow ? 236 : 182, r: 26, f: 14, glow: "#F5A524", o: 0.55 },
    copied: { w: wide, h: narrow ? 176 : 150, r: 26, f: 14, glow: "#4ADE80", o: 0.55 },
    download: { w: wide, h: narrow ? 176 : 150, r: 26, f: 14, glow: "#4ADE80", o: 0.55 },
    denied: { w: 300, h: 70, r: 22, f: 10, glow: "#F87171", o: 0.35 },
  }[stage];

  return (
    <NotchShell width={size.w} height={size.h} radius={size.r} flare={size.f} glow={size.glow} glowOpacity={size.o} shake={shake}>
      <AnimatePresence mode="popLayout" initial={false}>
        {(stage === "idle" || stage === "peek") && (
          <motion.button
            key="idle"
            type="button"
            onClick={ask}
            onMouseEnter={() => setStage("peek")}
            onMouseLeave={() => setStage("idle")}
            aria-label="Install Nosy Notch"
            className="cursor-target absolute inset-0 flex items-center justify-between px-3"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0, transition: { duration: 0.08 } }}
          >
            <Spark mode={stage === "peek" ? "working" : "idle"} color="#A78BFA" size={16} />
            <AnimatePresence>
              {stage === "peek" && (
                <motion.span
                  className="whitespace-nowrap font-mono text-[11.5px] text-white/85"
                  initial={{ opacity: 0, y: 3 }}
                  animate={{ opacity: 1, y: 0, transition: { delay: 0.1 } }}
                  exit={{ opacity: 0 }}
                >
                  psst… get me
                </motion.span>
              )}
            </AnimatePresence>
            <ScrollRing />
          </motion.button>
        )}

        {stage === "ask" && (
          <motion.div key="ask" {...fade} className="absolute inset-0 flex flex-col px-5 pb-4 pt-9 text-left sm:px-6">
            <div className="flex items-center gap-2.5">
              <motion.span className="text-[17px]" animate={{ rotate: [0, 18, -8, 18, 0] }} transition={{ duration: 1.1, repeat: Infinity, repeatDelay: 1.3 }} aria-hidden>
                👋
              </motion.span>
              <span className="text-[14px] font-semibold">Nosy Notch needs you</span>
              <span className="hidden font-mono text-[11px] text-amber sm:inline">{version ? `v${version}` : "latest"}</span>
              <button
                type="button"
                onClick={() => setStage("idle")}
                aria-label="Close"
                className="cursor-target ml-auto grid size-6 place-items-center rounded-full bg-white/10 text-[11px] text-white/60 hover:bg-white/20 hover:text-white"
              >
                ✕
              </button>
            </div>
            <p className="mt-2 text-[13.5px] text-white/70">Install Nosy Notch on this Mac? It wants to run:</p>
            <div className="mt-2 flex items-center gap-2 rounded-xl bg-white/[0.07] px-3.5 py-2 font-mono text-[13px]">
              <span className="text-white/35">$</span>
              {INSTALL_COMMAND}
              <span className="h-4 w-[7px] animate-blink bg-white/70" aria-hidden />
              <span className="ml-auto hidden text-[10.5px] text-white/35 sm:inline">macOS 14+ · Node 18+</span>
            </div>
            <div className="mt-auto flex flex-wrap items-center justify-end gap-1.5 pt-2.5">
              <span className="mr-auto hidden text-[11px] text-white/35 sm:inline">or press Esc</span>
              <Btn kind="plain" onClick={() => setStage("denied")}>
                Deny
              </Btn>
              <Btn href={archive ?? RELEASES_URL} onClick={() => setStage("download")}>
                Download .app
              </Btn>
              <Btn kind="primary" onClick={allow}>
                Allow · copy
              </Btn>
            </div>
          </motion.div>
        )}

        {(stage === "copied" || stage === "download") && (
          <motion.div key="done" {...fade} className="absolute inset-0 flex items-start gap-4 px-5 pb-4 pt-10 text-left sm:px-6">
            <span className="relative grid size-11 shrink-0 place-items-center">
              <Confetti burst={burst} count={36} spread={1.4} />
              <DrawnCheck size={42} />
            </span>
            <span className="min-w-0">
              <span className="block text-[15px] font-semibold">{stage === "copied" ? "Copied. Paste it into Terminal." : "Downloading Nosy Notch…"}</span>
              <span className="mt-1 block text-[12.5px] leading-relaxed text-white/60">
                {stage === "copied"
                  ? "It installs the app, connects Claude Code, Codex and Cursor, and starts watching. Restart agent sessions that were already running."
                  : "Unpack it, move Nosy Notch.app to Applications and open it. Settings → Agents connects everything with one click."}
              </span>
            </span>
            <button
              type="button"
              onClick={() => setStage("idle")}
              aria-label="Close"
              className="cursor-target absolute right-4 top-3 grid size-6 place-items-center rounded-full bg-white/10 text-[11px] text-white/60 hover:bg-white/20 hover:text-white"
            >
              ✕
            </button>
          </motion.div>
        )}

        {stage === "denied" && (
          <motion.div key="denied" {...fade} className="absolute inset-0 flex items-center justify-center gap-3 pt-3">
            <Eyes />
            <span className="text-[13px] text-white/80">Fine. I'll just keep watching.</span>
          </motion.div>
        )}
      </AnimatePresence>
    </NotchShell>
  );
}
