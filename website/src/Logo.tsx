/**
 * The Nosy Notch mark: the top edge of a screen with the notch hanging from it, and the agent's
 * spark peeking out of the notch in the accent colour.
 */
export function LogoMark({ className = "size-6" }: { className?: string }) {
  return (
    <svg viewBox="0 0 100 100" fill="none" className={className} aria-hidden>
      <rect x="6" y="14" width="88" height="72" rx="16" stroke="currentColor" strokeOpacity=".35" strokeWidth="6" />
      <path d="M28 14h44v14a14 14 0 0 1-14 14H42a14 14 0 0 1-14-14V14Z" fill="currentColor" />
      <path
        d="M50 50c1.6 7.2 4.8 10.4 12 12-7.2 1.6-10.4 4.8-12 12-1.6-7.2-4.8-10.4-12-12 7.2-1.6 10.4-4.8 12-12Z"
        fill="var(--accent)"
      />
    </svg>
  );
}

export function Logo({ href = "/", className = "" }: { href?: string; className?: string }) {
  return (
    <a
      href={href}
      className={`flex items-center gap-2 text-[18px] font-semibold tracking-[-0.03em] ${className}`}
    >
      <LogoMark className="size-6" />
      Nosy Notch
    </a>
  );
}
