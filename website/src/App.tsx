import { Analytics } from "@vercel/analytics/react";
import { motion } from "motion/react";
import { useEffect, useState, type ReactNode } from "react";
import SpectralDrape from "./backgrounds/SpectralDrape";
import { INSTALL_COMMAND, openInstall, REPO_URL, up } from "./lib";
import { LogoMark } from "./Logo";
import { SiteMenuBar } from "./MenuBar";
import { Agents } from "./sections/Agents";
import { Extras } from "./sections/Extras";
import { MeetNosy } from "./sections/MeetNosy";
import { Moments } from "./sections/Moments";
import { Nod } from "./sections/Nod";
import Magnet from "./vendor/Magnet";
import TargetCursor from "./vendor/TargetCursor";

function PrimaryButton({ onClick, children }: { onClick: () => void; children: ReactNode }) {
  return (
    <Magnet padding={70} magnetStrength={5}>
      <button
        type="button"
        onClick={onClick}
        className="cursor-target group relative inline-flex h-12 items-center gap-2.5 overflow-hidden rounded-full bg-white px-6 text-[15px] font-semibold text-black transition-shadow duration-500 hover:shadow-[0_0_0_1px_rgba(255,255,255,0.5),0_14px_60px_-8px_#b04dff]"
      >
        <span className="absolute inset-y-0 -left-1/2 w-1/3 -skew-x-12 bg-gradient-to-r from-transparent via-black/10 to-transparent transition-transform duration-700 group-hover:translate-x-[420%]" />
        <svg viewBox="0 0 24 24" className="size-[17px] transition-transform duration-500 group-hover:-translate-y-0.5" fill="none" stroke="currentColor" strokeWidth="2.2" aria-hidden>
          <path d="M12 20V7m0 0-5 5m5-5 5 5M5 3.5h14" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
        {children}
      </button>
    </Magnet>
  );
}

function CopyCommand() {
  const [copied, setCopied] = useState(false);
  return (
    <button
      type="button"
      onClick={async () => {
        try {
          await navigator.clipboard.writeText(INSTALL_COMMAND);
        } catch {
          /* visible anyway */
        }
        setCopied(true);
        setTimeout(() => setCopied(false), 1600);
      }}
      className="cursor-target group inline-flex h-12 items-center gap-3 rounded-full border border-white/12 bg-black/40 px-5 font-mono text-[14px] text-white/85 backdrop-blur-md transition-colors hover:border-white/25"
    >
      <span className="text-white/35">$</span>
      {INSTALL_COMMAND}
      <span className={`text-[11px] transition-colors ${copied ? "text-success" : "text-white/35 group-hover:text-white/70"}`}>{copied ? "copied" : "copy"}</span>
    </button>
  );
}

/** A hand-drawn arrow from the hero up to the notch: it's up there. */
function LookUp() {
  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ delay: 1.4, duration: 0.8 }}
      className="pointer-events-none absolute left-1/2 top-[52px] hidden translate-x-[150px] items-start gap-1 md:flex"
    >
      <svg width="64" height="54" viewBox="0 0 64 54" fill="none" className="mt-1 text-white/45" aria-hidden>
        <motion.path
          d="M60 48C44 48 22 40 14 10"
          stroke="currentColor"
          strokeWidth="1.6"
          strokeLinecap="round"
          initial={{ pathLength: 0 }}
          animate={{ pathLength: 1 }}
          transition={{ delay: 1.6, duration: 0.9, ease: "easeInOut" }}
        />
        <motion.path
          d="M7 17 14 9l7 7"
          stroke="currentColor"
          strokeWidth="1.6"
          strokeLinecap="round"
          strokeLinejoin="round"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 2.4 }}
        />
      </svg>
      <span className="mt-9 whitespace-nowrap font-mono text-[11.5px] text-white/50">
        psst, that's me.
        <br />
        hover me.
      </span>
    </motion.div>
  );
}

function Hero() {
  return (
    <section id="top" className="relative isolate min-h-[100svh] overflow-hidden">
      <div className="absolute inset-0 -z-10">
        <SpectralDrape />
      </div>
      <div className="pointer-events-none absolute inset-0 -z-10 bg-[radial-gradient(ellipse_50%_40%_at_50%_55%,rgb(5_5_6/0.72),transparent_78%)]" />
      <div className="pointer-events-none absolute inset-x-0 bottom-0 -z-10 h-64 bg-gradient-to-b from-transparent to-background" />
      <LookUp />

      <div className="mx-auto flex min-h-[100svh] max-w-[1100px] flex-col items-center justify-center px-5 pb-20 pt-28 text-center">
        <motion.h1 {...up(0.12)} className="text-[clamp(50px,9vw,120px)] font-semibold leading-[0.9] tracking-[-0.06em]">
          Agents work.
          <br />
          <span className="text-drape">Your notch watches.</span>
        </motion.h1>
        <motion.p {...up(0.22)} className="mt-7 max-w-[52ch] text-[clamp(15px,1.5vw,18.5px)] leading-relaxed text-white/60">
          Nosy Notch turns your MacBook's notch into a tiny live display – with Nosy, a little helper who
          lives in it: what your agents are doing, a click to allow or reply, and your music while they rest.
        </motion.p>
        <motion.div {...up(0.32)} className="mt-10 flex flex-wrap items-center justify-center gap-3">
          <PrimaryButton onClick={openInstall}>Get Nosy Notch</PrimaryButton>
          <CopyCommand />
        </motion.div>
        <motion.a
          {...up(0.5)}
          href="#moments"
          className="cursor-target mt-16 flex flex-col items-center gap-2 font-mono text-[11px] text-white/35 transition-colors hover:text-white/70"
        >
          watch it work
          <motion.span animate={{ y: [0, 5, 0] }} transition={{ duration: 1.6, repeat: Infinity }}>
            ↓
          </motion.span>
        </motion.a>
      </div>
    </section>
  );
}

function SectionHead({ kicker, title, body, color }: { kicker: string; title: ReactNode; body?: ReactNode; color: string }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20, filter: "blur(6px)" }}
      whileInView={{ opacity: 1, y: 0, filter: "blur(0px)" }}
      viewport={{ once: true, margin: "-80px" }}
      transition={{ duration: 0.8, ease: [0.22, 1, 0.36, 1] }}
      className="mb-10 max-w-[680px]"
    >
      <div className="flex items-center gap-2 font-mono text-[11px] uppercase tracking-[0.18em]" style={{ color }}>
        <span className="size-1.5 rounded-full" style={{ background: color, boxShadow: `0 0 10px ${color}` }} />
        {kicker}
      </div>
      <h2 className="mt-3 text-[clamp(32px,4.6vw,56px)] font-semibold leading-[1] tracking-[-0.045em]">{title}</h2>
      {body && <p className="mt-4 max-w-[54ch] text-[15.5px] leading-relaxed text-muted-foreground">{body}</p>}
    </motion.div>
  );
}

function Finale() {
  return (
    <section className="relative isolate mt-36 overflow-hidden">
      <div className="absolute inset-0 -z-10 opacity-70 [mask-image:linear-gradient(to_bottom,transparent,black_35%,black_65%,transparent)]">
        <SpectralDrape seed={7} strands={9} interactive={false} />
      </div>
      <div className="mx-auto flex max-w-[1100px] flex-col items-center px-5 py-32 text-center">
        <h2 className="text-[clamp(48px,9vw,128px)] font-semibold leading-[0.88] tracking-[-0.06em]">
          Let it
          <br />
          <span className="text-drape">watch.</span>
        </h2>
        <p className="mt-6 max-w-[44ch] text-[16px] leading-relaxed text-white/60">
          One command. Then it sits up there and pays attention, so you don't have to.
        </p>
        <div className="mt-10 flex flex-wrap items-center justify-center gap-3">
          <PrimaryButton onClick={openInstall}>Get Nosy Notch</PrimaryButton>
          <CopyCommand />
        </div>
        <p className="mt-6 font-mono text-[11.5px] text-white/35">macOS 14+ · Node.js 18+ · no account, no App Store</p>
      </div>
    </section>
  );
}

function Footer() {
  return (
    <footer className="mx-auto flex max-w-[1100px] flex-col items-center justify-between gap-3 px-5 pb-10 pt-4 text-[13px] text-faint sm:flex-row">
      <span className="flex items-center gap-2">
        <LogoMark className="size-4 text-muted-foreground" /> Nosy Notch · MIT License
      </span>
      <span className="flex flex-wrap justify-center gap-5">
        <a href={`${REPO_URL}#readme`} className="cursor-target hover:text-foreground">README</a>
        <a href={`${REPO_URL}/releases`} className="cursor-target hover:text-foreground">Releases</a>
        <a href={REPO_URL} className="cursor-target hover:text-foreground">GitHub</a>
        <a href="https://davidkubus.dev/impressum" className="cursor-target hover:text-foreground">Impressum</a>
        <a href="https://davidkubus.dev/datenschutz" className="cursor-target hover:text-foreground">Datenschutz</a>
      </span>
    </footer>
  );
}

export default function App() {
  return (
    <>
      <Analytics />
      <TargetCursor targetSelector=".cursor-target" spinDuration={2.4} hideDefaultCursor />
      <SiteMenuBar />
      <Hero />

      <main className="mx-auto max-w-[1100px] px-4 sm:px-5">
        <section id="moments" className="scroll-mt-20 pt-10">
          <SectionHead
            kicker="Interactive demo"
            color="#A78BFA"
            title={
              <>
                Every moment,
                <br />
                <span className="text-white/45">at a glance.</span>
              </>
            }
            body="The real notch, rebuilt from the app's code. Pick a moment, or just watch. When it asks for permission, answer it."
          />
          <Moments />
        </section>

        <section id="nosy" className="scroll-mt-20 pt-36">
          <SectionHead
            kicker="Meet Nosy"
            color="#E0A0E6"
            title={
              <>
                A tiny helper
                <br />
                <span className="text-white/45">that lives in your notch.</span>
              </>
            }
            body="Nosy looks out of the notch, follows your pointer and works along with your agents. Go on, poke it."
          />
          <MeetNosy />
        </section>

        <section id="extras" className="scroll-mt-20 pt-36">
          <SectionHead
            kicker="And more"
            color="#73D9F2"
            title={
              <>
                Not just agents.
                <br />
                <span className="text-white/45">Everything that deserves a glance.</span>
              </>
            }
            body="Recorded straight from the app. The ones that need a macOS permission stay off until you turn them on."
          />
          <Extras />
        </section>

        <section id="agents" className="scroll-mt-20 pt-36">
          <SectionHead
            kicker="Works with"
            color="#80AAFF"
            title={
              <>
                Three agents.
                <br />
                <span className="text-white/45">Each with its own spark.</span>
              </>
            }
            body="Run several sessions at once, mixed across agents. The notch always shows the one that matters most. Hover a card to wake it up."
          />
          <Agents />
        </section>

        <section id="nod" className="scroll-mt-20 pt-36">
          <Nod />
        </section>

      </main>

      <Finale />
      <Footer />
    </>
  );
}
