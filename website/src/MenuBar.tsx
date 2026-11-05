import { useEffect, useState } from "react";
import { formatStars, REPO_URL, useRepoInfo } from "./lib";
import { LogoMark } from "./Logo";
import { TopNotch } from "./TopNotch";

export function Clock({ withDate = true }: { withDate?: boolean }) {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const id = setInterval(() => setNow(new Date()), 15_000);
    return () => clearInterval(id);
  }, []);
  const day = now.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" }).replace(",", "");
  const time = now.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
  return (
    <span className="tabular-nums">
      {withDate && <span className="hidden sm:inline">{day}&nbsp;&nbsp;</span>}
      {time}
    </span>
  );
}

function Wifi() {
  return (
    <svg viewBox="0 0 24 24" className="size-[15px]" fill="currentColor" aria-hidden>
      <path d="M12 18.5a1.6 1.6 0 1 1 0 3.2 1.6 1.6 0 0 1 0-3.2Zm0-5c2 0 3.8.8 5.1 2.1l-1.6 1.6A5 5 0 0 0 12 15.7a5 5 0 0 0-3.5 1.5l-1.6-1.6A7.2 7.2 0 0 1 12 13.5Zm0-5c3.4 0 6.4 1.3 8.7 3.5l-1.6 1.6A10 10 0 0 0 12 10.7a10 10 0 0 0-7.1 2.9l-1.6-1.6A12.3 12.3 0 0 1 12 8.5Z" />
    </svg>
  );
}

function SparkMark({ className = "" }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden>
      <path d="M12 2c1 5 3 7 10 10-7 3-9 5-10 10-1-5-3-7-10-10 7-3 9-5 10-10Z" fill="currentColor" />
    </svg>
  );
}

/** The menu bar inside the demo screens: an app name on the left, the ✦ and the clock on the right. */
export function MenuBarContent({ app }: { app: string }) {
  return (
    <div className="relative flex h-8 items-center justify-between px-4 text-[13px] font-medium text-white/90">
      <span className="flex items-center gap-4">
        <span className="font-semibold">{app}</span>
        <span className="hidden text-white/80 md:inline">Shell</span>
        <span className="hidden text-white/80 md:inline">Edit</span>
      </span>
      <span className="flex items-center gap-3.5">
        <SparkMark className="size-3.5 text-white" />
        <span className="hidden md:block">
          <Wifi />
        </span>
        <Clock />
      </span>
    </div>
  );
}

const LINKS = [
  ["Moments", "#moments"],
  ["Agents", "#agents"],
  ["Nod", "#nod"],
  ["Privacy", "#privacy"],
];

/** The page's own menu bar, macOS style, with the site's notch hanging in the middle. */
export function SiteMenuBar() {
  const { stars } = useRepoInfo();
  const [scrolled, setScrolled] = useState(false);
  useEffect(() => {
    const on = () => setScrolled(window.scrollY > 8);
    on();
    window.addEventListener("scroll", on, { passive: true });
    return () => window.removeEventListener("scroll", on);
  }, []);

  return (
    <header className="fixed inset-x-0 top-0 z-50">
      <div
        className={`flex h-9 items-center justify-between px-4 text-[13px] font-medium transition-colors duration-300 sm:px-5 ${
          scrolled ? "bg-black/55 backdrop-blur-xl" : "bg-transparent"
        }`}
      >
        <nav className="flex items-center gap-5">
          <a href="#top" className="cursor-target flex items-center gap-2 font-semibold tracking-[-0.01em]">
            <LogoMark className="size-[18px]" />
            Nosy Notch
          </a>
          <span className="hidden items-center gap-5 text-white/65 lg:flex">
            {LINKS.map(([label, href]) => (
              <a key={href} href={href} className="cursor-target transition-colors hover:text-white">
                {label}
              </a>
            ))}
          </span>
        </nav>
        <span className="flex items-center gap-4 text-white/75">
          <a href={REPO_URL} target="_blank" rel="noreferrer" className="cursor-target flex items-center gap-1.5 transition-colors hover:text-white">
            <svg viewBox="0 0 24 24" className="size-[15px]" fill="currentColor" aria-hidden>
              <path d="M12 .5a11.5 11.5 0 0 0-3.64 22.41c.58.1.79-.25.79-.56v-2c-3.2.7-3.88-1.37-3.88-1.37-.52-1.33-1.28-1.69-1.28-1.69-1.05-.71.08-.7.08-.7 1.16.08 1.77 1.19 1.77 1.19 1.03 1.77 2.7 1.26 3.36.96.1-.75.4-1.26.73-1.55-2.55-.29-5.24-1.28-5.24-5.69 0-1.26.45-2.29 1.19-3.1-.12-.29-.52-1.46.11-3.05 0 0 .97-.31 3.17 1.18a11 11 0 0 1 5.77 0c2.2-1.49 3.17-1.18 3.17-1.18.63 1.59.23 2.76.11 3.05.74.81 1.19 1.84 1.19 3.1 0 4.42-2.7 5.39-5.26 5.68.41.36.78 1.06.78 2.14v3.17c0 .31.21.67.8.56A11.5 11.5 0 0 0 12 .5Z" />
            </svg>
            <span className="hidden sm:inline">Star</span>
            {stars ? <span className="font-mono text-[12px] tabular-nums">{formatStars(stars)}</span> : null}
          </a>
          <span className="hidden md:block">
            <Wifi />
          </span>
          <Clock />
        </span>
      </div>
      <div className="absolute left-1/2 top-0 -translate-x-1/2">
        <TopNotch />
      </div>
    </header>
  );
}
