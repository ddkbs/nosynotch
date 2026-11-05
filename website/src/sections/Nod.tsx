import { AnimatePresence, motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { Confetti } from "../notch/Confetti";

type Verdict = "none" | "allow" | "deny";

/**
 * "Just nod." Move the pointer up and down over the head to nod (allow) or left and right to
 * shake it (deny), the way head gestures work with AirPods in the app.
 */
export function Nod() {
  const area = useRef<HTMLDivElement>(null);
  const [tilt, setTilt] = useState({ x: 0, y: 0 });
  const [verdict, setVerdict] = useState<Verdict>("none");
  const [burst, setBurst] = useState(0);
  const track = useRef({ lx: 0, ly: 0, dx: 0, dy: 0, flipsX: [] as number[], flipsY: [] as number[], has: false });

  const decide = (v: Verdict) => {
    setVerdict(v);
    if (v === "allow") setBurst((b) => b + 1);
    track.current.flipsX = [];
    track.current.flipsY = [];
  };

  useEffect(() => {
    if (verdict === "none") return;
    const id = setTimeout(() => setVerdict("none"), 2400);
    return () => clearTimeout(id);
  }, [verdict]);

  const onMove = (e: React.PointerEvent) => {
    const r = area.current!.getBoundingClientRect();
    const x = (e.clientX - r.left) / r.width - 0.5;
    const y = (e.clientY - r.top) / r.height - 0.5;
    setTilt({ x, y });
    if (verdict !== "none") return;
    const t = track.current;
    const now = performance.now();
    if (t.has) {
      const dx = e.clientX - t.lx;
      const dy = e.clientY - t.ly;
      // Count direction changes on each axis within a short window.
      if (Math.abs(dy) > 2 && Math.abs(dy) > Math.abs(dx)) {
        if (t.dy && Math.sign(dy) !== Math.sign(t.dy)) t.flipsY.push(now);
        t.dy = dy;
      }
      if (Math.abs(dx) > 2 && Math.abs(dx) > Math.abs(dy)) {
        if (t.dx && Math.sign(dx) !== Math.sign(t.dx)) t.flipsX.push(now);
        t.dx = dx;
      }
      t.flipsY = t.flipsY.filter((f) => now - f < 1100);
      t.flipsX = t.flipsX.filter((f) => now - f < 1100);
      if (t.flipsY.length >= 3) decide("allow");
      else if (t.flipsX.length >= 3) decide("deny");
    }
    t.lx = e.clientX;
    t.ly = e.clientY;
    t.has = true;
  };

  return (
    <div className="grid items-center gap-8 md:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
      <div
        ref={area}
        onPointerMove={onMove}
        onPointerLeave={() => setTilt({ x: 0, y: 0 })}
        className="relative grid h-[340px] place-items-center overflow-hidden rounded-[26px] border border-white/[0.08] bg-[radial-gradient(circle_at_50%_40%,#17121f,#08080a_70%)] touch-none"
      >
        {/* The notch asking, above the head. */}
        <div className="absolute left-1/2 top-0 -translate-x-1/2">
          <motion.div
            className="flex h-9 items-center gap-2 rounded-b-[16px] bg-black px-4 text-[11.5px] font-medium"
            animate={{
              boxShadow:
                verdict === "allow" ? "0 0 26px #4ADE8099" : verdict === "deny" ? "0 0 26px #F8717188" : "0 0 26px #F5A52488",
            }}
          >
            <AnimatePresence mode="wait">
              <motion.span key={verdict} initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -4 }} className="whitespace-nowrap">
                {verdict === "allow" ? (
                  <span className="text-success">✓ Allowed · rm -rf node_modules</span>
                ) : verdict === "deny" ? (
                  <span className="text-danger">✕ Denied. Good call.</span>
                ) : (
                  <span className="text-amber">Claude wants to run rm -rf node_modules</span>
                )}
              </motion.span>
            </AnimatePresence>
          </motion.div>
        </div>

        {/* A head with AirPods, tilting towards the pointer. */}
        <motion.div
          className="relative"
          animate={
            verdict === "allow"
              ? { rotateX: [0, 22, -6, 18, 0], rotateY: 0 }
              : verdict === "deny"
                ? { rotateY: [0, -26, 24, -18, 0], rotateX: 0 }
                : { rotateX: -tilt.y * 26, rotateY: tilt.x * 30 }
          }
          transition={verdict === "none" ? { type: "spring", stiffness: 120, damping: 14 } : { duration: 0.9 }}
          style={{ transformPerspective: 600 }}
        >
          <div className="relative size-[150px] rounded-full bg-[radial-gradient(circle_at_35%_30%,#2a2a33,#121216_70%)] shadow-[inset_0_0_0_1px_rgba(255,255,255,0.08),0_30px_60px_-20px_rgba(0,0,0,0.8)]">
            {/* Eyes */}
            <motion.div className="absolute left-1/2 top-[42%] flex -translate-x-1/2 gap-6" animate={{ x: tilt.x * 14, y: tilt.y * 10 }}>
              {[0, 1].map((i) => (
                <span key={i} className="block h-4 w-3 rounded-full bg-white" />
              ))}
            </motion.div>
            {/* Mouth */}
            <motion.div
              className="absolute left-1/2 top-[66%] h-2 w-8 -translate-x-1/2 rounded-b-full border-b-2 border-white/60"
              animate={{ scaleY: verdict === "allow" ? 1.8 : verdict === "deny" ? -1 : 1 }}
            />
            {/* AirPods */}
            <span className="absolute -left-2 top-[48%] h-9 w-3.5 rounded-full bg-white shadow-[0_0_14px_rgba(255,255,255,0.4)]" />
            <span className="absolute -right-2 top-[48%] h-9 w-3.5 rounded-full bg-white shadow-[0_0_14px_rgba(255,255,255,0.4)]" />
          </div>
        </motion.div>
        <span className="absolute left-1/2 top-[44%]">
          <Confetti burst={burst} count={40} spread={1.8} />
        </span>
        <span className="absolute bottom-4 font-mono text-[11px] text-white/35">
          move up & down to nod · left & right to shake
        </span>
      </div>

      <div>
        <h3 className="text-[clamp(28px,4vw,44px)] font-semibold leading-[1.02] tracking-[-0.04em]">
          Hands full?
          <br />
          <span className="text-white/45">Just nod.</span>
        </h3>
        <p className="mt-5 max-w-[44ch] text-[15.5px] leading-relaxed text-muted-foreground">
          With AirPods in, a nod allows the command and a head shake denies it. Motion is only read
          while a request is open, and it's off until you turn it on. Try it with your mouse.
        </p>
        <div className="mt-6 flex gap-2">
          <button type="button" onClick={() => decide("allow")} className="cursor-target h-9 rounded-full bg-white/[0.08] px-4 text-[13px] font-medium hover:bg-white/[0.14]">
            Nod for me
          </button>
          <button type="button" onClick={() => decide("deny")} className="cursor-target h-9 rounded-full px-4 text-[13px] font-medium text-white/55 hover:text-white">
            Shake
          </button>
        </div>
      </div>
    </div>
  );
}
