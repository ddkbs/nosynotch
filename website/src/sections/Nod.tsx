import { animate, AnimatePresence, motion, useMotionValue, useSpring, useTransform } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { Confetti } from "../notch/Confetti";

type Verdict = "none" | "allow" | "deny";

/** An AirPod: a rounded bud with its stem, lit from the top left. */
function AirPod({ side }: { side: "l" | "r" }) {
  return (
    <span className={`absolute top-[46%] ${side === "l" ? "-left-[13px]" : "-right-[13px] scale-x-[-1]"}`} aria-hidden>
      <span className="relative block">
        <span className="block size-[22px] rounded-full bg-[radial-gradient(circle_at_35%_30%,#ffffff,#d9d9e0_60%,#a9a9b4)] shadow-[0_4px_10px_rgba(0,0,0,0.5)]" />
        <span className="absolute left-[9px] top-[16px] block h-[30px] w-[8px] rounded-full bg-[linear-gradient(90deg,#f4f4f7,#c9c9d2)] shadow-[0_6px_10px_rgba(0,0,0,0.45)]" />
        <span className="absolute left-[5px] top-[6px] block size-[6px] rounded-full bg-[#2a2a30]" />
      </span>
    </span>
  );
}

/**
 * "Just nod." Move the pointer up and down over the head to nod (allow) or left and right to
 * shake it (deny), the way head gestures work with AirPods in the app. Everything runs on
 * springs, nothing re-renders while the pointer moves.
 */
export function Nod() {
  const area = useRef<HTMLDivElement>(null);
  const [verdict, setVerdict] = useState<Verdict>("none");
  const [progress, setProgress] = useState<{ axis: "x" | "y" | null; n: number }>({ axis: null, n: 0 });
  const [burst, setBurst] = useState(0);
  const [pulse, setPulse] = useState(0);

  // Pointer position (−0.5 … 0.5) eased by springs; nod / shake are added on top.
  const px = useMotionValue(0);
  const py = useMotionValue(0);
  const sx = useSpring(px, { stiffness: 140, damping: 18, mass: 0.6 });
  const sy = useSpring(py, { stiffness: 140, damping: 18, mass: 0.6 });
  const nodX = useMotionValue(0);
  const nodY = useMotionValue(0);
  const rotateX = useTransform([sy, nodX], ([y, n]: number[]) => -y * 24 + n);
  const rotateY = useTransform([sx, nodY], ([x, n]: number[]) => x * 30 + n);
  const eyeX = useTransform(sx, (x) => x * 16);
  const eyeY = useTransform(sy, (y) => y * 10);
  const shineX = useTransform(sx, (x) => `${35 - x * 30}%`);
  const shineY = useTransform(sy, (y) => `${30 - y * 30}%`);
  const shine = useTransform([shineX, shineY], ([a, b]) => `radial-gradient(circle at ${a} ${b}, #34343e, #15151a 62%, #0d0d10)`);

  const track = useRef({ lx: 0, ly: 0, dx: 0, dy: 0, flipsX: [] as number[], flipsY: [] as number[], has: false, locked: false });

  const decide = (v: Exclude<Verdict, "none">) => {
    const t = track.current;
    t.locked = true;
    t.flipsX = [];
    t.flipsY = [];
    setProgress({ axis: null, n: 0 });
    setVerdict(v);
    setPulse((p) => p + 1);
    if (v === "allow") {
      void animate(nodX, [0, 20, -6, 16, -3, 0], { duration: 1, ease: "easeInOut" });
      setTimeout(() => setBurst((b) => b + 1), 250);
    } else {
      void animate(nodY, [0, -26, 22, -16, 8, 0], { duration: 1, ease: "easeInOut" });
    }
    setTimeout(() => {
      setVerdict("none");
      t.locked = false;
    }, 2600);
  };

  useEffect(() => {
    const el = area.current!;
    const onMove = (e: PointerEvent) => {
      const r = el.getBoundingClientRect();
      px.set((e.clientX - r.left) / r.width - 0.5);
      py.set((e.clientY - r.top) / r.height - 0.5);
      const t = track.current;
      if (t.locked) return;
      const now = performance.now();
      if (t.has) {
        const dx = e.clientX - t.lx;
        const dy = e.clientY - t.ly;
        if (Math.abs(dy) > 2.5 && Math.abs(dy) > Math.abs(dx) * 1.2) {
          if (t.dy && Math.sign(dy) !== Math.sign(t.dy)) t.flipsY.push(now);
          t.dy = dy;
        }
        if (Math.abs(dx) > 2.5 && Math.abs(dx) > Math.abs(dy) * 1.2) {
          if (t.dx && Math.sign(dx) !== Math.sign(t.dx)) t.flipsX.push(now);
          t.dx = dx;
        }
        t.flipsY = t.flipsY.filter((f) => now - f < 1600);
        t.flipsX = t.flipsX.filter((f) => now - f < 1600);
        const ny = Math.min(3, t.flipsY.length), nx = Math.min(3, t.flipsX.length);
        const next = ny >= nx ? { axis: ny ? ("y" as const) : null, n: ny } : { axis: "x" as const, n: nx };
        setProgress((p) => (p.axis === next.axis && p.n === next.n ? p : next));
        if (ny >= 3) decide("allow");
        else if (nx >= 3) decide("deny");
      }
      t.lx = e.clientX;
      t.ly = e.clientY;
      t.has = true;
    };
    const onLeave = () => {
      px.set(0);
      py.set(0);
    };
    el.addEventListener("pointermove", onMove);
    el.addEventListener("pointerleave", onLeave);
    return () => {
      el.removeEventListener("pointermove", onMove);
      el.removeEventListener("pointerleave", onLeave);
    };
  }, []);

  const glow = verdict === "allow" ? "#4ADE80" : verdict === "deny" ? "#F87171" : "#F5A524";

  return (
    <div className="grid items-center gap-10 md:grid-cols-[minmax(0,1.1fr)_minmax(0,1fr)]">
      <div
        ref={area}
        className="relative grid h-[380px] touch-none place-items-center overflow-hidden rounded-[28px] border border-white/[0.08] bg-[radial-gradient(circle_at_50%_45%,#1a1424,#08080a_72%)]"
      >
        {/* The notch asking, above the head. */}
        <div className="absolute left-1/2 top-0 -translate-x-1/2">
          <motion.div
            layout
            className="flex h-10 items-center gap-2.5 overflow-hidden rounded-b-[18px] bg-black px-5 text-[12px] font-medium"
            animate={{ boxShadow: `0 0 30px ${glow}88` }}
            transition={{ duration: 0.4 }}
          >
            <AnimatePresence mode="wait" initial={false}>
              <motion.span
                key={verdict}
                initial={{ opacity: 0, y: 6, filter: "blur(4px)" }}
                animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
                exit={{ opacity: 0, y: -6, filter: "blur(4px)" }}
                transition={{ duration: 0.25 }}
                className="whitespace-nowrap"
              >
                {verdict === "allow" ? (
                  <span className="text-success">✓ Allowed · npm run build</span>
                ) : verdict === "deny" ? (
                  <span className="text-danger">✕ Denied. Claude will ask differently.</span>
                ) : (
                  <span className="text-amber">Claude wants to run npm run build</span>
                )}
              </motion.span>
            </AnimatePresence>
          </motion.div>
        </div>

        {/* Head */}
        <motion.div style={{ rotateX, rotateY, transformPerspective: 700 }} className="relative">
          <motion.div
            className="relative size-[168px] rounded-full shadow-[inset_0_0_0_1px_rgba(255,255,255,0.07),0_40px_70px_-25px_rgba(0,0,0,0.9)]"
            style={{ background: shine }}
            animate={{ scale: [1, 1.012, 1] }}
            transition={{ duration: 3.2, repeat: Infinity, ease: "easeInOut" }}
          >
            <motion.div className="absolute left-1/2 top-[40%] flex -translate-x-1/2 gap-7" style={{ x: eyeX, y: eyeY }}>
              {[0, 1].map((i) => (
                <span key={i} className="relative block h-[19px] w-[14px] overflow-hidden rounded-full bg-white">
                  <span className="absolute inset-x-0 top-0 block bg-[#1a1a20]" style={{ animation: "blink-lid 4.2s infinite" }} />
                </span>
              ))}
            </motion.div>
            <motion.div className="absolute left-1/2 top-[64%] -translate-x-1/2" style={{ x: eyeX }}>
              <motion.svg width="38" height="14" viewBox="0 0 38 14" fill="none" aria-hidden>
                <motion.path
                  stroke="rgba(255,255,255,0.7)"
                  strokeWidth="2.4"
                  strokeLinecap="round"
                  initial={false}
                  animate={{ d: verdict === "allow" ? "M5 3 Q19 15 33 3" : verdict === "deny" ? "M7 10 Q19 2 31 10" : "M8 5 Q19 10 30 5" }}
                  transition={{ type: "spring", stiffness: 200, damping: 16 }}
                />
              </motion.svg>
            </motion.div>
            <AirPod side="l" />
            <AirPod side="r" />
            {/* Pulse from the AirPods when a gesture is recognised. */}
            <AnimatePresence>
              {pulse > 0 && verdict !== "none" && (
                <motion.span
                  key={pulse}
                  className="pointer-events-none absolute inset-[-10px] rounded-full border-2"
                  style={{ borderColor: glow }}
                  initial={{ opacity: 0.9, scale: 0.9 }}
                  animate={{ opacity: 0, scale: 1.5 }}
                  exit={{ opacity: 0 }}
                  transition={{ duration: 0.9, ease: "easeOut" }}
                />
              )}
            </AnimatePresence>
          </motion.div>
        </motion.div>

        <span className="absolute left-1/2 top-1/2">
          <Confetti burst={burst} count={44} spread={2} />
        </span>

        {/* Gesture progress: three dots fill up as you nod or shake. */}
        <div className="absolute bottom-5 flex flex-col items-center gap-2">
          <span className="flex gap-1.5">
            {[0, 1, 2].map((i) => (
              <motion.span
                key={i}
                className="block size-1.5 rounded-full"
                animate={{
                  background: i < progress.n ? (progress.axis === "x" ? "#F87171" : "#4ADE80") : "rgba(255,255,255,0.18)",
                  scale: i < progress.n ? 1.3 : 1,
                }}
                transition={{ type: "spring", stiffness: 400, damping: 20 }}
              />
            ))}
          </span>
          <span className="font-mono text-[11px] text-white/35">up & down to nod · left & right to shake</span>
        </div>
      </div>

      <div>
        <div className="flex items-center gap-2 font-mono text-[11px] uppercase tracking-[0.18em] text-amber">
          <span className="size-1.5 rounded-full bg-amber shadow-[0_0_10px_#F5A524]" />
          Head gestures
        </div>
        <h3 className="mt-3 text-[clamp(32px,4.6vw,56px)] font-semibold leading-[1] tracking-[-0.045em]">
          Hands full?
          <br />
          <span className="text-white/45">Just nod.</span>
        </h3>
        <p className="mt-5 max-w-[44ch] text-[15.5px] leading-relaxed text-muted-foreground">
          With AirPods in, a nod allows the command and a head shake denies it. Motion is only read
          while a request is open, and it's off until you turn it on. Try it with your mouse.
        </p>
        <div className="mt-6 flex gap-2">
          <button
            type="button"
            onClick={() => verdict === "none" && decide("allow")}
            className="cursor-target h-10 rounded-full bg-white/[0.08] px-5 text-[13.5px] font-medium transition-colors hover:bg-white/[0.14]"
          >
            Nod for me
          </button>
          <button
            type="button"
            onClick={() => verdict === "none" && decide("deny")}
            className="cursor-target h-10 rounded-full px-5 text-[13.5px] font-medium text-white/55 transition-colors hover:text-white"
          >
            Shake
          </button>
        </div>
      </div>
    </div>
  );
}
