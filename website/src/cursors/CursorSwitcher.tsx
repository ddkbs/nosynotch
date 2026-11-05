import { AnimatePresence, motion } from "motion/react";
import { useState } from "react";
import { CURSORS, type CursorKind } from "./Cursors";

/** Dev only: a dot in the corner that opens a list of cursors to try. */
export function CursorSwitcher({ value, onChange }: { value: CursorKind; onChange: (k: CursorKind) => void }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="fixed bottom-4 right-4 z-[10000] flex flex-col items-end gap-2">
      <AnimatePresence>
        {open && (
          <motion.div
            initial={{ opacity: 0, y: 8, scale: 0.96 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 6, scale: 0.97 }}
            transition={{ duration: 0.18 }}
            className="w-56 rounded-2xl border border-white/10 bg-black/85 p-1.5 shadow-2xl backdrop-blur-xl"
          >
            <div className="px-2.5 pb-1 pt-1.5 font-mono text-[10px] uppercase tracking-[0.14em] text-white/35">Cursor · dev only</div>
            {CURSORS.map((c, i) => (
              <button
                key={c.id}
                type="button"
                onClick={() => onChange(c.id)}
                className={`cursor-target flex w-full items-center gap-2.5 rounded-xl px-2.5 py-2 text-left transition-colors ${
                  value === c.id ? "bg-white/10" : "hover:bg-white/[0.06]"
                }`}
              >
                <span className="font-mono text-[10px] text-white/35">{i + 1}</span>
                <span className="text-[13px] font-medium">{c.label}</span>
                <span className="ml-auto truncate text-[11px] text-white/40">{c.hint}</span>
              </button>
            ))}
            <div className="px-2.5 pb-1 pt-1.5 text-[10.5px] text-white/30">Keys 1–5 switch too</div>
          </motion.div>
        )}
      </AnimatePresence>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-label="Switch cursor"
        className="cursor-target grid size-7 place-items-center rounded-full border border-white/15 bg-black/80 backdrop-blur"
      >
        <span className="size-2.5 rounded-full bg-[conic-gradient(#6D5BFF,#FF4F9A,#FF9A5A,#6D5BFF)]" />
      </button>
    </div>
  );
}
