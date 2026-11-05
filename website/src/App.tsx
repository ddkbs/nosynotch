import { Analytics } from "@vercel/analytics/react";
import { motion } from "motion/react";
import type { ReactNode } from "react";
import GazeField from "./backgrounds/GazeField";
import SpectralDrape from "./backgrounds/SpectralDrape";
import { Demo } from "./Demo";
import { Docs } from "./Docs";
import { InstallNotch } from "./InstallNotch";
import { INSTALL_COMMAND, openInstall, REPO_URL, up, useRepoInfo } from "./lib";
import { LogoMark } from "./Logo";
import { GithubButton, Nav } from "./Nav";
import NotchCursor from "./NotchCursor";
import { NosyEyes } from "./NosyEyes";
import SparkCursor from "./SparkCursor";
import DecryptedText from "./vendor/DecryptedText";
import Magnet from "./vendor/Magnet";

export type Variant = "a" | "b";
export type Page = "home" | "docs";

const DOCS = "/docs/";

/** Primary action: solid white, magnetic, with a warm glow on hover. */
function PrimaryButton({
  onClick,
  children,
  size = "lg",
}: {
  onClick: () => void;
  children: ReactNode;
  size?: "lg" | "sm";
}) {
  const lg = size === "lg";
  return (
    <Magnet padding={lg ? 70 : 30} magnetStrength={lg ? 5 : 8}>
      <button
        type="button"
        onClick={onClick}
        className={`cursor-target group relative inline-flex items-center gap-2.5 overflow-hidden rounded-lg bg-white font-medium text-black transition-shadow duration-500 hover:shadow-[0_0_0_1px_rgba(255,255,255,0.5),0_12px_50px_-6px_var(--accent)] ${
          lg ? "h-12 px-6 text-[15px]" : "h-8 px-3.5 text-[13px]"
        }`}
      >
        <span className="absolute inset-y-0 -left-1/2 w-1/3 -skew-x-12 bg-gradient-to-r from-transparent via-black/10 to-transparent transition-transform duration-700 group-hover:translate-x-[420%]" />
        <svg viewBox="0 0 24 24" className={lg ? "size-[18px]" : "size-4"} fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
          <path d="M12 4v11m0 0-4.5-4.5M12 15l4.5-4.5M5 20h14" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
        {children}
      </button>
    </Magnet>
  );
}

const icon = (d: string) => (
  <svg viewBox="0 0 24 24" className="size-[18px]" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
    <path d={d} />
  </svg>
);

const FEATURES: { title: string; body: string; icon: ReactNode }[] = [
  {
    title: "Live status",
    body: "Thinking, the tool it's running, how long it's been.",
    icon: icon("M4 17l5-5-5-5M12 19h8"),
  },
  {
    title: "Allow in the notch",
    body: "Deny, always allow, allow. Or nod with your AirPods.",
    icon: icon("M5 12.5l4.5 4.5L19 7.5"),
  },
  {
    title: "Every limit",
    body: "Sessions, context fill, 5-hour and weekly usage.",
    icon: icon("M4 19V9M10 19V5M16 19v-7M22 19H2"),
  },
  {
    title: "Music in between",
    body: "Spotify and Apple Music, with a live equalizer.",
    icon: icon("M9 18V6l11-2v12M9 18a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm11-2a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z"),
  },
];

const AGENTS = [
  { name: "Claude Code", where: "terminal · VS Code · desktop app", color: "#E0896A" },
  { name: "Codex", where: "CLI · ChatGPT app", color: "#80AAFF" },
  { name: "Cursor", where: "agent", color: "#D1D6E0" },
];

function Hero() {
  const { version } = useRepoInfo();
  return (
    <section className="relative isolate min-h-[100svh] overflow-hidden">
      <div className="absolute inset-0 -z-10">
        <SpectralDrape />
      </div>
      <div className="pointer-events-none absolute inset-0 -z-10 bg-[radial-gradient(ellipse_55%_42%_at_50%_46%,rgb(6_6_7/0.78),transparent_75%)]" />
      <div className="pointer-events-none absolute inset-x-0 bottom-0 -z-10 h-56 bg-gradient-to-b from-transparent to-background" />

      <div className="mx-auto flex min-h-[100svh] max-w-[1180px] flex-col items-center justify-center px-5 pb-24 pt-28 text-center">
        <motion.a
          {...up(0)}
          href={DOCS}
          className="cursor-target mb-8 inline-flex items-center gap-2 rounded-full border border-white/12 bg-black/40 py-1 pl-1 pr-3.5 font-mono text-[12px] text-muted-foreground backdrop-blur-md transition-colors hover:text-foreground"
        >
          <span className="rounded-full bg-accent/15 px-2 py-0.5 text-accent">v{version ?? "0.2.0"}</span>
          <DecryptedText
            text="your notch, keeping an eye on your agents"
            animateOn="view"
            sequential
            speed={30}
            className="text-muted-foreground"
            encryptedClassName="text-accent/70"
          />
        </motion.a>

        <motion.h1
          {...up(0.1)}
          className="text-[clamp(46px,8vw,100px)] font-semibold leading-[0.95] tracking-[-0.055em]"
        >
          Agents work.
          <br />
          <span className="text-nosy">The notch watches.</span>
        </motion.h1>
        <motion.p
          {...up(0.2)}
          className="mt-7 max-w-[56ch] text-[clamp(15px,1.5vw,18px)] leading-relaxed text-muted-foreground"
        >
          Free and open source: Nosy Notch turns your MacBook's notch into a live display for Claude
          Code, Codex and Cursor. See what they're doing, allow a command with a click, and get your
          music back while they rest.
        </motion.p>
        <motion.div {...up(0.3)} className="mt-10 flex flex-wrap items-center justify-center gap-3">
          <PrimaryButton onClick={openInstall}>Get Nosy Notch</PrimaryButton>
          <Magnet padding={70} magnetStrength={5}>
            <GithubButton className="h-12 px-5 text-[15px]" />
          </Magnet>
        </motion.div>
        <motion.p {...up(0.4)} className="mt-6 font-mono text-[11.5px] tracking-wide text-faint">
          MIT · macOS 14+ · {INSTALL_COMMAND} · no account, no App Store
        </motion.p>
      </div>
    </section>
  );
}

/** Version B: the page is nosy. A notch with eyes follows you, the field looks where you look. */
function HeroB() {
  const { version } = useRepoInfo();
  return (
    <section className="relative isolate min-h-[100svh] overflow-hidden">
      <div className="absolute inset-0 -z-10">
        <GazeField />
      </div>
      <div className="pointer-events-none absolute inset-0 -z-10 bg-[radial-gradient(ellipse_50%_38%_at_50%_55%,rgb(6_6_7/0.85),transparent_80%)]" />
      <div className="pointer-events-none absolute inset-x-0 bottom-0 -z-10 h-56 bg-gradient-to-b from-transparent to-background" />

      <div className="absolute left-1/2 top-0 z-[60] -translate-x-1/2">
        <NosyEyes onPoke={openInstall} />
      </div>

      <div className="mx-auto flex min-h-[100svh] max-w-[1180px] flex-col items-center justify-center px-5 pb-24 pt-40 text-center">
        <motion.a
          {...up(0)}
          href={DOCS}
          className="cursor-target mb-8 inline-flex items-center gap-2 rounded-full border border-white/12 bg-black/40 py-1 pl-1 pr-3.5 font-mono text-[12px] text-muted-foreground backdrop-blur-md transition-colors hover:text-foreground"
        >
          <span className="rounded-full bg-accent/15 px-2 py-0.5 text-accent">v{version ?? "0.2.0"}</span>
          <DecryptedText
            text="psst. it's watching your agents"
            animateOn="view"
            sequential
            speed={30}
            className="text-muted-foreground"
            encryptedClassName="text-accent/70"
          />
        </motion.a>
        <motion.h1
          {...up(0.1)}
          className="text-[clamp(46px,8vw,100px)] font-semibold leading-[0.95] tracking-[-0.055em]"
        >
          Nosy about
          <br />
          <span className="text-nosy">your agents.</span>
        </motion.h1>
        <motion.p
          {...up(0.2)}
          className="mt-7 max-w-[56ch] text-[clamp(15px,1.5vw,18px)] leading-relaxed text-muted-foreground"
        >
          Free and open source: your MacBook's notch keeps an eye on Claude Code, Codex and Cursor. It
          shows what they're doing, asks when they need you, and plays your music while they rest.
        </motion.p>
        <motion.div {...up(0.3)} className="mt-10 flex flex-wrap items-center justify-center gap-3">
          <PrimaryButton onClick={openInstall}>Get Nosy Notch</PrimaryButton>
          <Magnet padding={70} magnetStrength={5}>
            <GithubButton className="h-12 px-5 text-[15px]" />
          </Magnet>
        </motion.div>
        <motion.p {...up(0.4)} className="mt-6 font-mono text-[11.5px] tracking-wide text-faint">
          MIT · macOS 14+ · {INSTALL_COMMAND} · no account, no App Store
        </motion.p>
      </div>
    </section>
  );
}

function Landing({ variant }: { variant: Variant }) {
  return (
    <>
      {variant === "b" ? <HeroB /> : <Hero />}

      <section id="demo" className="relative mx-auto -mt-16 max-w-[1080px] scroll-mt-24 px-4">
        <div className="mb-5 flex items-end justify-between px-1">
          <div>
            <div className="font-mono text-[11px] uppercase tracking-[0.18em] text-accent">Live demo</div>
            <div className="mt-1 text-[22px] font-semibold tracking-[-0.03em]">
              Pick a moment. Watch the notch.
            </div>
          </div>
          <div className="hidden font-mono text-[11px] text-faint sm:block">real recordings from the app</div>
        </div>
        <Demo />
      </section>

      <section className="mx-auto mt-24 max-w-[1080px] px-4">
        <div className="grid grid-cols-2 gap-px overflow-hidden rounded-2xl border border-border bg-border md:grid-cols-4">
          {FEATURES.map((f) => (
            <div key={f.title} className="cursor-target group bg-background p-5 transition-colors hover:bg-white/[0.02]">
              <div className="mb-4 grid size-9 place-items-center rounded-lg border border-border-strong text-muted-foreground transition-colors group-hover:border-accent/50 group-hover:text-accent">
                {f.icon}
              </div>
              <div className="text-[15px] font-medium">{f.title}</div>
              <div className="mt-1 text-[13.5px] leading-snug text-muted-foreground">{f.body}</div>
            </div>
          ))}
        </div>
      </section>

      <section className="mx-auto mt-24 max-w-[1080px] px-4">
        <div className="grid gap-8 px-1 md:grid-cols-[minmax(0,1fr)_minmax(0,1.15fr)] md:items-center">
          <div>
            <div className="font-mono text-[11px] uppercase tracking-[0.18em] text-accent">Works with</div>
            <h2 className="mt-1 text-[clamp(26px,3.4vw,36px)] font-semibold leading-tight tracking-[-0.035em]">
              Every agent gets its own spark.
            </h2>
            <p className="mt-4 text-[15px] leading-relaxed text-muted-foreground">
              Run several sessions at once, mixed across agents. The notch always shows the one that
              matters most, and a hover shows them all. Everything stays on your Mac: the hooks only
              talk to <span className="font-mono text-[13px] text-foreground">127.0.0.1</span>.
            </p>
          </div>
          <div className="flex flex-col gap-2">
            {AGENTS.map((a) => (
              <div
                key={a.name}
                className="cursor-target group flex items-center gap-4 rounded-xl border border-border bg-white/[0.02] px-4 py-3.5 transition-colors hover:border-white/15"
              >
                <svg viewBox="0 0 24 24" className="size-5 transition-transform duration-700 group-hover:rotate-180" style={{ color: a.color, filter: `drop-shadow(0 0 8px ${a.color}88)` }} aria-hidden>
                  <path d="M12 2c1 5 3 7 10 10-7 3-9 5-10 10-1-5-3-7-10-10 7-3 9-5 10-10Z" fill="currentColor" />
                </svg>
                <span className="text-[15px] font-medium">{a.name}</span>
                <span className="ml-auto font-mono text-[11.5px] text-faint">{a.where}</span>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section id="install" className="mx-auto mt-28 max-w-[1080px] scroll-mt-24 px-4 pb-10">
        <div className="mb-8 text-center">
          <h2 className="text-[clamp(28px,4vw,44px)] font-semibold tracking-[-0.04em]">Let it watch.</h2>
          <p className="mx-auto mt-3 max-w-[46ch] text-muted-foreground">
            One command, then it just sits there and pays attention. Ask the notch.
          </p>
        </div>
        <InstallNotch />
        <p className="-mt-2 text-center font-mono text-[11.5px] text-faint">
          or in any terminal: <span className="text-muted-foreground">{INSTALL_COMMAND}</span> ·{" "}
          <a href={DOCS} className="cursor-target hover:text-foreground">
            read the docs →
          </a>
        </p>
      </section>
    </>
  );
}

function Footer() {
  return (
    <footer className="mx-auto flex max-w-[1080px] flex-col items-center justify-between gap-3 px-5 py-10 text-[13px] text-faint sm:flex-row">
      <span className="flex items-center gap-2">
        <LogoMark className="size-4 text-muted-foreground" /> Nosy Notch · MIT License
      </span>
      <span className="flex flex-wrap justify-center gap-5">
        <a href={DOCS} className="cursor-target hover:text-foreground">Docs</a>
        <a href={`${REPO_URL}/releases`} className="cursor-target hover:text-foreground">Releases</a>
        <a href={REPO_URL} className="cursor-target hover:text-foreground">GitHub</a>
        <a href="https://davidkubus.dev/impressum" className="cursor-target hover:text-foreground">Impressum</a>
        <a href="https://davidkubus.dev/datenschutz" className="cursor-target hover:text-foreground">Datenschutz</a>
      </span>
    </footer>
  );
}

export default function App({ page, variant }: { page: Page; variant: Variant }) {
  const home = variant === "b" ? "/b/" : "/";
  return (
    <>
      <Analytics />
      {variant === "b" ? <SparkCursor /> : <NotchCursor />}
      <Nav
        notch={!(variant === "b" && page === "home")}
        home={home}
        docs={DOCS}
        cta={
          <PrimaryButton onClick={openInstall} size="sm">
            Install
          </PrimaryButton>
        }
      />
      {page === "home" ? (
        <Landing variant={variant} />
      ) : (
        <>
          <div className="pointer-events-none fixed inset-0 -z-10 opacity-35">
            {variant === "b" ? (
              <GazeField />
            ) : (
              <SpectralDrape interactive={false} clickRipples={false} speed={0.5} />
            )}
          </div>
          <div className="pointer-events-none fixed inset-0 -z-10 bg-background/75" />
          <Docs />
          <Footer />
        </>
      )}
      {page === "home" && <Footer />}
    </>
  );
}
