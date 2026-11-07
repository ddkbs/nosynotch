import { motion } from "motion/react";

const EXTRAS: { video: string; title: string; body: string; color: string }[] = [
  { video: "chat", title: "Reply from the notch", body: "Read the conversation and answer right there – no hunting for the right terminal.", color: "#D97757" },
  { video: "drop-zone", title: "Shelf and AirDrop", body: "Drag files onto the notch: park them for later, or AirDrop them in one move.", color: "#A78BFA" },
  { video: "meeting", title: "Your next meeting", body: "A heads-up ten minutes before, and Join for Zoom, Meet or Teams.", color: "#5B9EFF" },
  { video: "focus", title: "Focus timer", body: "25 minutes, a ring in the notch, no agent sounds until the break.", color: "#B3A3FF" },
  { video: "charging", title: "Charging", body: "Plug in and the battery fills up – and a heads-up at 20 %.", color: "#4ADE80" },
  { video: "airpods", title: "AirPods", body: "Headphones connect with their left, right and case battery.", color: "#F5F5F7" },
];

/** The extras as small looping recordings from the app itself. */
export function Extras() {
  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {EXTRAS.map((x, i) => (
        <motion.figure
          key={x.video}
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-60px" }}
          transition={{ duration: 0.6, delay: (i % 3) * 0.08 }}
          className="overflow-hidden rounded-[20px] border border-white/10 bg-panel"
        >
          <video
            className="aspect-[560/214] w-full object-cover object-top"
            src={`/demo/${x.video}.mp4`}
            poster={`/demo/${x.video}.jpg`}
            autoPlay
            muted
            loop
            playsInline
            preload="metadata"
          />
          <figcaption className="p-5">
            <div className="flex items-center gap-2">
              <span className="size-1.5 rounded-full" style={{ background: x.color, boxShadow: `0 0 10px ${x.color}` }} />
              <h3 className="text-[15.5px] font-semibold tracking-[-0.01em]">{x.title}</h3>
            </div>
            <p className="mt-1.5 text-[13.5px] leading-relaxed text-muted-foreground">{x.body}</p>
          </figcaption>
        </motion.figure>
      ))}
    </div>
  );
}
