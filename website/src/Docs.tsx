import { useEffect, useState } from "react";
import { INSTALL_COMMAND, RELEASES_URL, REPO_URL } from "./lib";

const SECTIONS = [
  ["introduction", "Introduction"],
  ["install", "Installation"],
  ["agents", "Agents"],
  ["moments", "What the notch shows"],
  ["approve", "Allow from the notch"],
  ["usage", "Sessions and limits"],
  ["music", "Music"],
  ["settings", "Settings"],
  ["commands", "Commands"],
  ["privacy", "Privacy"],
  ["how", "How it works"],
  ["troubleshooting", "Troubleshooting"],
] as const;

function Clip({ id, alt }: { id: string; alt: string }) {
  return (
    <video
      src={`/demo/${id}.mp4`}
      poster={`/demo/${id}.jpg`}
      autoPlay
      loop
      muted
      playsInline
      aria-label={alt}
      className="my-5 block w-full rounded-xl border border-border-strong"
    />
  );
}

/** The documentation: a sticky table of contents and a short explanation of everything. */
export function Docs() {
  const [active, setActive] = useState<string>(SECTIONS[0][0]);
  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        const visible = entries.filter((e) => e.isIntersecting);
        if (visible.length) setActive(visible[0].target.id);
      },
      { rootMargin: "-90px 0px -70% 0px" },
    );
    for (const [id] of SECTIONS) {
      const el = document.getElementById(id);
      if (el) observer.observe(el);
    }
    return () => observer.disconnect();
  }, []);

  return (
    <div className="mx-auto grid max-w-[1180px] gap-10 px-5 pb-32 pt-28 lg:grid-cols-[220px_minmax(0,1fr)]">
      <aside className="hidden lg:block">
        <nav className="sticky top-28 flex flex-col gap-0.5 text-[14px]">
          <div className="mb-3 font-mono text-[11px] uppercase tracking-[0.16em] text-faint">
            Documentation
          </div>
          {SECTIONS.map(([id, label]) => (
            <a
              key={id}
              href={`#${id}`}
              className={`cursor-target relative rounded-md py-1.5 pl-3 transition-colors ${
                active === id ? "text-foreground" : "text-muted-foreground hover:text-foreground"
              }`}
            >
              <span
                className={`absolute left-0 top-1/2 h-4 w-px -translate-y-1/2 transition-colors ${
                  active === id ? "bg-accent" : "bg-border-strong"
                }`}
              />
              {label}
            </a>
          ))}
        </nav>
      </aside>

      <article className="prose-docs min-w-0 max-w-[740px]">
        <h1 id="introduction" className="scroll-mt-28 text-[40px] font-semibold tracking-[-0.04em]">
          Nosy Notch documentation
        </h1>
        <p>
          Nosy Notch turns the notch of your MacBook into a small status display for coding agents. It
          slides open while Claude Code, Codex or Cursor works, shows which tool is running, asks you
          when an agent needs permission and celebrates when it's done. When nothing is running, it
          plays your music. It's free, open source and everything stays on your Mac.
        </p>
        <Clip id="demo" alt="A full run: thinking, tools, a permission request and done" />

        <h2 id="install">Installation</h2>
        <p>
          You need macOS 14 or newer and <a href="https://nodejs.org">Node.js</a> 18+ for{" "}
          <code>npx</code> (<code>brew install node</code> works too). Then run:
        </p>
        <pre>
          <code>{INSTALL_COMMAND}</code>
        </pre>
        <p>
          That one command downloads the app to <code>~/.nosynotch/</code>, connects every agent it
          finds and starts Nosy Notch in the background. There's no Dock icon, just a ✦ in the menu
          bar. Macs without a notch get a virtual one in the middle of the menu bar.
        </p>
        <p>Two small things afterwards:</p>
        <ul>
          <li>Restart Claude Code sessions that were already running, so they pick up the hooks.</li>
          <li>
            Codex runs no hook you haven't trusted. Trust the new hooks once: ChatGPT app →{" "}
            <strong>Codex → Settings → Hooks</strong>, or <code>/hooks</code> in the CLI.
          </li>
        </ul>
        <p>
          Prefer no terminal? Download the app from the{" "}
          <a href={RELEASES_URL}>latest release</a>, move it to Applications, open it and click{" "}
          <strong>Connect</strong> in Settings → Agents.
        </p>

        <h2 id="agents">Agents</h2>
        <table>
          <thead>
            <tr>
              <th />
              <th>Live status</th>
              <th>Allow in the notch</th>
              <th>Usage limits</th>
              <th>Context fill</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><strong>Claude Code</strong></td>
              <td>✓</td><td>✓</td><td>✓ Pro / Max</td><td>✓</td>
            </tr>
            <tr>
              <td><strong>Codex</strong></td>
              <td>✓</td><td>✓</td><td>✓</td><td>✓</td>
            </tr>
            <tr>
              <td><strong>Cursor</strong></td>
              <td>✓</td><td>–</td><td>–</td><td>–</td>
            </tr>
          </tbody>
        </table>
        <p>
          Claude Code works in the terminal, in VS Code and in the desktop app, Codex in its CLI and in
          the ChatGPT app's Codex mode. Several sessions at once are fine, mixed across agents. Each
          gets its own colour: orange for Claude, blue for Codex, silver for Cursor.
        </p>

        <h2 id="moments">What the notch shows</h2>
        <h3>Thinking and working</h3>
        <p>
          The notch slides out sideways. A spark turns on the left; on the right you see three dots
          while the agent thinks, or the icon of the tool it runs: terminal, pencil, magnifier,
          globe, checklist.
        </p>
        <Clip id="tools" alt="The notch showing the tool that is running" />
        <h3>Done</h3>
        <p>
          A checkmark draws itself, confetti flies and you read how the answer starts, with the
          project and how long the turn took. Click to jump to the right terminal or app. If that app
          is already in front, the notch stays small and silent: just a green check for three seconds.
        </p>
        <Clip id="done" alt="Done: checkmark and confetti" />
        <h3>Unseen, errors, compacting</h3>
        <p>
          Missed a result? A green dot breathes in the notch until you switch to that app or hover the
          list, and you get one gentle reminder after five minutes. API errors (rate limit, overloaded,
          billing …) get a red glow and a plain-language message. When Claude compacts its context, a
          purple spark turns backwards.
        </p>

        <h2 id="approve">Allow from the notch</h2>
        <p>
          When an agent asks for permission, the notch opens with an amber glow, shakes and shows the
          exact command. Click <strong>Allow</strong>, <strong>Deny</strong> or{" "}
          <strong>Always allow</strong> and the agent carries on. Claude Code keeps its own dialog open
          at the same time, so you can answer wherever you are.
        </p>
        <Clip id="attention" alt="Needs you: the permission card with Deny and Allow" />
        <p>
          With <strong>head gestures</strong> on (Settings → Permissions) and AirPods in, a nod allows
          and a head shake denies. Motion is only read while a request is open. Cursor has no
          approval hook, so it shows status only.
        </p>

        <h2 id="usage">Sessions and limits</h2>
        <p>
          Hover the notch for every session: status, current tool, a timer and a ring for how full its
          context window is. A click brings the right terminal to the front. At the bottom you see
          your 5-hour and weekly limits as bars. Hover a bar to see when it resets.
        </p>
        <Clip id="usage" alt="Hover view with sessions and usage limits" />
        <p>
          Claude only reports limits in its status line JSON, so Nosy Notch installs a silent status
          line, but only if you don't have your own. Codex limits come from its session files.
        </p>

        <h2 id="music">Music</h2>
        <p>
          When no agent is working, Spotify or Apple Music takes over: cover on the left, equalizer
          on the right, a full player on hover. The agents always win, and the music comes back as soon
          as they're done. Turn on the <strong>live equalizer</strong> in Settings → Music to have the
          bars follow the real audio.
        </p>
        <Clip id="media" alt="Music player in the notch" />

        <h2 id="settings">Settings</h2>
        <p>
          Click the ✦ in the menu bar → <strong>Settings…</strong>
        </p>
        <ul>
          <li><strong>Agents</strong>: connect Claude Code, Codex and Cursor</li>
          <li><strong>Alerts</strong>: sounds, mute for 1 h / 8 h / ∞, reminders</li>
          <li><strong>Permissions</strong>: the notch buttons and head gestures</li>
          <li><strong>Usage</strong>: which limits to show, context rings</li>
          <li><strong>Music</strong>: the player and the live equalizer</li>
        </ul>
        <p>
          Everything that needs a macOS permission is off until you turn it on, or asks only the
          first time you use it.
        </p>

        <h2 id="commands">Commands</h2>
        <pre>
          <code>{`npx nosynotch            # install or update, connect agents, start
npx nosynotch demo       # play every animation
npx nosynotch settings   # open the settings window
npx nosynotch status     # what is installed and running
npx nosynotch autostart  # start at login (autostart off to disable)
npx nosynotch stop
npx nosynotch uninstall  # removes app, hooks and autostart`}</code>
        </pre>

        <h2 id="privacy">Privacy</h2>
        <p>
          Everything stays on your Mac. The hooks talk to <code>127.0.0.1</code> only and nothing is
          uploaded. The only network requests are for album covers. The live equalizer analyses audio
          in memory and records nothing. Approvals are protected by a secret in{" "}
          <code>~/.nosynotch/approval-token</code>, so no other process can answer in your name.
        </p>

        <h2 id="how">How it works</h2>
        <p>
          Claude Code, Codex and Cursor all have <em>hooks</em>: small commands they run at every step
          (prompt sent, tool started, permission needed, done …). Nosy Notch adds a one-line{" "}
          <code>curl</code> that forwards each event to the app on <code>127.0.0.1:7823</code>. If the
          app isn't running, <code>curl</code> fails instantly and the agent carries on, so hooks never
          slow it down. Only the permission hook waits, until you click in the notch.
        </p>

        <h2 id="troubleshooting">Troubleshooting</h2>
        <ul>
          <li>
            <strong>Nothing happens:</strong> run <code>npx nosynotch status</code>, then restart the
            agent session.
          </li>
          <li>
            <strong>Codex stays quiet:</strong> trust the hooks once (Codex → Settings → Hooks).
          </li>
          <li>
            <strong>No song shown:</strong> play or skip once, then allow Nosy Notch to control your
            player when macOS asks.
          </li>
          <li>
            Still stuck? <a href={`${REPO_URL}/issues`}>Open an issue</a>.
          </li>
        </ul>
      </article>
    </div>
  );
}
