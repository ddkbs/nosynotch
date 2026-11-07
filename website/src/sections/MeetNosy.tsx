import { AnimatePresence, motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { MenuBarContent } from "../MenuBar";
import { NOSY_COLORS, Nosy, NosyEyes, type NosyColor, type NosyMood } from "../notch/Nosy";

const MOODS: { mood: NosyMood; label: string; tint: string }[] = [
  { mood: "idle", label: "Curious", tint: "#D97757" },
  { mood: "working", label: "Working", tint: "#D97757" },
  { mood: "needs", label: "Needs you", tint: "#F5A524" },
  { mood: "happy", label: "Done", tint: "#4ADE80" },
  { mood: "sleeping", label: "Asleep", tint: "#A78BFA" },
];

const POINTS = [
  ["Works along", "Types while your agent runs tools, sweats on long turns, gets dizzy while it compacts."],
  ["Waves, cheers, naps", "Waves when an agent needs you, jumps when it's done, dozes off when nothing happens."],
  ["Feeds on finished tasks", "Energy, levels, streaks and a little wardrobe. No guilt: Nosy never gets sad."],
  ["Lives in the black", "When the notch closes, Nosy dives into it like into tar – and keeps watching with its eyes."],
] as const;

/** Black drops that fly out of the notch when Nosy dives in. */
function Splash({ x }: { x: number }) {
  const drops = [-160, -140, -118, -100, -80, -62, -40, -22, -150, -30, -90, -125];
  return (
    <div className="pointer-events-none absolute top-[38px]" style={{ left: x }}>
      <motion.span
        className="absolute -translate-x-1/2 rounded-[50%] border-2 border-black/70"
        initial={{ width: 20, height: 6, opacity: 0.8 }}
        animate={{ width: 120, height: 22, opacity: 0 }}
        transition={{ duration: 0.8, ease: "easeOut" }}
      />
      {drops.map((a, i) => {
        const rad = (a * Math.PI) / 180;
        const speed = 50 + ((i * 37) % 45);
        const size = 3 + ((i * 7) % 4);
        return (
          <motion.span
            key={i}
            className="absolute rounded-full bg-black"
            style={{ width: size, height: size }}
            initial={{ x: 0, y: 0, opacity: 1 }}
            animate={{ x: [0, Math.cos(rad) * speed * 0.8, Math.cos(rad) * speed * 1.4], y: [0, -Math.sin(rad) * speed * 0.5, -Math.sin(rad) * speed * 0.6 + 70], opacity: [1, 1, 0] }}
            transition={{ duration: 0.9, ease: "easeOut", delay: 0.12 }}
          />
        );
      })}
    </div>
  );
}

export function MeetNosy() {
  const [mood, setMood] = useState<NosyMood>("idle");
  const [color, setColor] = useState<NosyColor>("obsidian");
  const [inside, setInside] = useState(false);
  const [giggle, setGiggle] = useState(false);
  const [splash, setSplash] = useState(0);
  const [look, setLook] = useState({ x: 0, y: 0 });
  const stage = useRef<HTMLDivElement>(null);
  const tint = MOODS.find((m) => m.mood === mood)?.tint ?? "#D97757";

  // The eyes follow the pointer anywhere on the page.
  useEffect(() => {
    const move = (e: PointerEvent) => {
      const r = stage.current?.getBoundingClientRect();
      if (!r) return;
      const cx = r.left + r.width / 2 - 70, cy = r.top + 120;
      setLook({ x: Math.max(-1, Math.min(1, (e.clientX - cx) / 400)), y: Math.max(-1, Math.min(1, (e.clientY - cy) / 300)) });
    };
    window.addEventListener("pointermove", move);
    return () => window.removeEventListener("pointermove", move);
  }, []);

  const toggle = () => {
    if (!inside) setSplash((n) => n + 1);
    setInside((v) => !v);
  };
  const pet = () => {
    setGiggle(true);
    setTimeout(() => setGiggle(false), 1600);
  };
  const shown: NosyMood = giggle ? "giggle" : mood;
  const rim = NOSY_COLORS[color].rim ?? tint;

  return (
    <div className="grid items-center gap-10 md:grid-cols-[1.1fr_1fr]">
      <div>
        <div ref={stage} className="relative overflow-hidden rounded-[22px] border border-white/10 bg-black p-1.5 shadow-[0_40px_120px_-40px_rgba(155,123,255,0.45)]">
          <div className="mac-wallpaper relative h-[380px] overflow-hidden rounded-[16px]">
            <div className="absolute inset-0 bg-black/10" />
            <MenuBarContent app="Terminal" />
            {/* The open notch. */}
            <motion.button
              type="button"
              onClick={() => inside && toggle()}
              aria-label={inside ? "Let Nosy out" : "Notch"}
              className="cursor-target absolute left-1/2 top-0 z-10 -translate-x-1/2 rounded-b-[18px] bg-black"
              animate={{ width: inside ? 250 : 300, height: inside ? 32 : 38, boxShadow: `0 0 26px ${rim}55` }}
              transition={{ type: "spring", stiffness: 260, damping: 24 }}
            >
              <AnimatePresence>
                {inside && (
                  <motion.svg
                    key="eyes"
                    viewBox="0 0 30 16"
                    className="absolute left-[18px] top-[7px] h-[18px] w-[34px]"
                    initial={{ opacity: 0, scale: 0.3 }}
                    animate={{ opacity: 1, scale: 1 }}
                    exit={{ opacity: 0, scale: 0.3 }}
                    transition={{ delay: 0.35 }}
                  >
                    <NosyEyes mood={shown} look={look} ink="#fff" cx={15} cy={8} r={4.4} gap={6} />
                  </motion.svg>
                )}
              </AnimatePresence>
            </motion.button>
            <div className="absolute left-1/2 top-[38px] z-20" style={{ marginLeft: -116 }}>
              {splash > 0 && inside && <Splash key={`s${splash}`} x={70} />}
              <AnimatePresence>
                {!inside && (
                  <motion.button
                    key="nosy"
                    type="button"
                    onClick={pet}
                    aria-label="Pet Nosy"
                    className="cursor-target block origin-top"
                    style={{ marginTop: -16 }}
                    initial={{ scaleX: 0.45, scaleY: 0.25, y: -40, filter: "brightness(0)" }}
                    animate={{ scaleX: 1, scaleY: 1, y: 0, filter: "brightness(1)" }}
                    exit={{ scaleX: 0.45, scaleY: 0.25, y: -40, filter: "brightness(0)", transition: { duration: 0.4, ease: [0.5, 0, 0.75, 0] } }}
                    transition={{ type: "spring", stiffness: 220, damping: 14 }}
                  >
                    <div className="nosy-sway">
                      <Nosy mood={shown} look={look} color={color} tint={tint} hanging className="h-[170px] w-[142px]" />
                    </div>
                  </motion.button>
                )}
              </AnimatePresence>
            </div>
            <p className="absolute bottom-4 left-0 right-0 text-center font-mono text-[11px] text-white/45">
              {inside ? "click the notch to let Nosy out" : "click Nosy to pet it"}
            </p>
          </div>
        </div>

        <div className="mt-5 flex flex-wrap items-center justify-center gap-1.5">
          {MOODS.map((m) => (
            <button
              key={m.mood}
              type="button"
              onClick={() => setMood(m.mood)}
              className={`cursor-target flex items-center gap-2 rounded-full px-3.5 py-1.5 text-[13px] font-medium transition-colors ${
                mood === m.mood ? "bg-white/[0.1] text-foreground" : "bg-white/[0.04] text-muted-foreground hover:text-foreground"
              }`}
            >
              <span className="size-1.5 rounded-full" style={{ background: m.tint, boxShadow: mood === m.mood ? `0 0 10px ${m.tint}` : "none" }} />
              {m.label}
            </button>
          ))}
          <button
            type="button"
            onClick={toggle}
            className="cursor-target rounded-full border border-white/15 px-3.5 py-1.5 text-[13px] font-medium text-foreground hover:border-white/30"
          >
            {inside ? "Come out" : "Dive into the notch"}
          </button>
        </div>
        <div className="mt-3 flex flex-wrap items-center justify-center gap-2">
          {(Object.keys(NOSY_COLORS) as NosyColor[]).map((c) => (
            <button
              key={c}
              type="button"
              onClick={() => setColor(c)}
              title={NOSY_COLORS[c].label}
              className={`cursor-target rounded-xl p-1 transition-colors ${color === c ? "bg-white/[0.1]" : "hover:bg-white/[0.05]"}`}
            >
              <Nosy mood={color === c ? "happy" : "idle"} color={c} tint={tint} className="h-[38px] w-[32px]" />
            </button>
          ))}
        </div>
      </div>

      <div>
        <ul className="space-y-6">
          {POINTS.map(([title, body], i) => (
            <motion.li
              key={title}
              initial={{ opacity: 0, x: 16 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true, margin: "-60px" }}
              transition={{ duration: 0.6, delay: i * 0.08 }}
              className="border-l border-white/10 pl-5"
            >
              <h3 className="text-[17px] font-semibold tracking-[-0.01em]">{title}</h3>
              <p className="mt-1 text-[14.5px] leading-relaxed text-muted-foreground">{body}</p>
            </motion.li>
          ))}
        </ul>
        <p className="mt-8 font-mono text-[11.5px] text-white/40">Eight colours · Obsidian glows in your agent's colour · Settings → Nosy</p>
      </div>
    </div>
  );
}
