<h1 align="center">Nosy Notch</h1>

<p align="center">
  <b>Your MacBook notch keeps an eye on Claude Code, Codex and Cursor –<br>with Nosy, a tiny helper who lives in it.</b>
</p>

<p align="center">
  <img src="docs/gifs/demo.gif" alt="Nosy Notch: Claude thinks, uses tools, asks for permission and finishes" width="720">
</p>

<p align="center">
  <code>npx nosynotch</code> · macOS 14+ · free · no account, no App Store, no Xcode
</p>

Coding agents spend a lot of time working on their own – and then sit there waiting for a "yes" you never saw.
Nosy Notch turns the black notch of your MacBook into a tiny status display: it slides open while an agent thinks,
shows which tool it's running, waves when it needs you, and throws confetti when it's done. You can approve a command
right there, with a click or a nod of your head – or read the conversation and reply without leaving what you're doing.
Living in the notch is **Nosy**, a little helper who works along, cheers when a task is done and falls asleep when
nothing happens. And in between, the notch is your music player, file shelf, focus timer and meeting reminder.

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/gifs/tools.gif" alt="Working"><br><b>Live status</b><br><sub>Thinking, the tool it's running, how long it's been</sub></td>
    <td align="center" width="50%"><img src="docs/gifs/attention.gif" alt="Needs you"><br><b>Allow from the notch</b><br><sub>Deny · Always allow · Allow – or just nod</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/gifs/done.gif" alt="Done"><br><b>Done</b><br><sub>Checkmark, confetti and the gist of the answer</sub></td>
    <td align="center"><img src="docs/gifs/unseen.gif" alt="Unseen"><br><b>Didn't see it?</b><br><sub>A green dot waits until you look</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/gifs/usage.gif" alt="Usage"><br><b>Every session, every limit</b><br><sub>Hover for all sessions, context fill and usage limits</sub></td>
    <td align="center"><img src="docs/gifs/media.gif" alt="Music"><br><b>Music in between</b><br><sub>Spotify / Apple Music, with an equalizer that follows the beat</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/gifs/nosy.gif" alt="Nosy"><br><b>Meet Nosy</b><br><sub>Peeks out, follows your pointer, dives back into the notch</sub></td>
    <td align="center"><img src="docs/gifs/chat.gif" alt="Chat"><br><b>Reply from the notch</b><br><sub>The conversation and a reply field, right there</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/gifs/drop-zone.gif" alt="Shelf and AirDrop"><br><b>Shelf and AirDrop</b><br><sub>Drag files onto the notch</sub></td>
    <td align="center"><img src="docs/gifs/meeting.gif" alt="Meeting"><br><b>Your next meeting</b><br><sub>A heads-up 10 minutes before, Join in one click</sub></td>
  </tr>
</table>

<p align="center"><a href="docs/animations.md"><b>→ Every animation, explained</b></a></p>

## Install

```bash
npx nosynotch
```

That one command downloads the app to `~/.nosynotch/`, connects every agent it finds and starts Nosy Notch in the
background – no Dock icon, just a ✦ in the menu bar. You need [Node.js](https://nodejs.org) 18+ for `npx`
(`brew install node` works too).

Two small things afterwards: restart Claude Code sessions that were already running, and – if you use Codex – trust the
new hooks once in Codex (ChatGPT app → **Codex → Settings → Hooks**, or `/hooks` in the CLI). Codex runs no hook you
haven't trusted.

<details>
<summary>More commands</summary>

```bash
npx nosynotch demo        # play every animation
npx nosynotch settings    # open the settings window
npx nosynotch status      # what is installed and running
npx nosynotch autostart   # start at login (autostart off to disable)
npx nosynotch stop
npx nosynotch uninstall   # removes app, hooks and autostart
```
</details>

## Works with

| | Live status | Allow / deny in the notch | Usage limits | Context fill |
|---|:---:|:---:|:---:|:---:|
| **Claude Code** – terminal, VS Code, desktop app | ✓ | ✓ | ✓ Pro / Max | ✓ |
| **Codex** – CLI and the ChatGPT app's Codex mode | ✓ | ✓ | ✓ | ✓ |
| **Cursor** – Cursor's agent | ✓ | ✓ commands outside its sandbox | – | ✓ |

Cursor doesn't share its usage limits with any hook, so that column stays empty for now.

Several sessions at once are no problem, mixed across agents. Each one gets a small badge and its own colour:
orange for Claude, blue for Codex, silver for Cursor. Macs without a notch get a virtual one in the middle of the menu bar.

## What the notch does

**While an agent works**, the notch slides out sideways: a spark spins on the left, the current tool on the right
(terminal, pencil, magnifier, globe …). Hover it to see every session with its status, a ring for how full its context
window is, and your 5-hour and weekly limits as bars. If a limit was at 80 % or more, the notch tells you the moment it resets.
A click on a session brings its terminal or app to the front.

**When it needs you**, the notch opens with an amber glow, shakes and shows the exact command. Click **Allow**,
**Deny** or **Always allow** – the agent carries on, no hunting for the right window. Claude Code keeps its own dialog
open at the same time, so you can answer wherever you are. With head gestures turned on, a nod with your AirPods allows
and a head shake denies.

**When it's done**, a checkmark draws itself, confetti flies and you get the start of the answer. Missed it? A small
green dot stays in the notch until you switch to that app or hover the list, and after five minutes you get one gentle
reminder. Already looking at the app? Then everything stays small and silent.

**Want to answer?** Click **Reply** on the done card (or the bubble next to a session) and the notch shows the
conversation with a reply field. Your reply is pasted into the session's app and sent – or, if you prefer, run in the
background with `claude --resume` / `codex exec resume`.

**When nothing's running**, Spotify or Apple Music takes over: cover on the left, equalizer on the right, a full player
on hover. The agents always win – the music comes back as soon as they're done.

## Meet Nosy

<img src="docs/gifs/nosy.gif" alt="Nosy peeks out, gets petted and dives back into the notch" width="560" align="right">

Nosy is a tiny helper who lives in your notch. Only its eyes look out of the black – they follow your pointer, and
they change with your agents: focused while one thinks, looking down while it types, a sweat drop on long turns,
spiral eyes while it compacts, wide eyes and a wave when it needs you, ^^ and a jump when it's done.

When the notch opens, Nosy drips out of the edge and hangs from it by its paws; when it closes, Nosy dives back in
like into a puddle of tar – splash included. Bring the pointer close and it peeks out; leave it alone for a while
and it falls asleep (sooner at night). Click it and it giggles.

**Energy, levels and streaks** – every finished task feeds Nosy, days with tasks make a streak, XP unlock a little
wardrobe (headphones, glasses, cap, bow). Deliberately guilt-free: Nosy never gets sad or sick, a missed day just
starts a new streak. Eight colours to pick from – Obsidian, the default, glows in the colour of the agent that's
working. All of it stays in your Mac's settings, and you can turn Nosy off for the classic agent symbols.

<br clear="right">

## More in the notch

- **Shelf and AirDrop** – drag files onto the notch: park them on the shelf and drag them out later, or AirDrop them.
- **Focus timer** – 15 / 25 / 50 minutes from the hover view or the menu bar, a ring in the notch, agent sounds stay
  quiet until the break.
- **Calendar** – your next meeting in the hover view and a heads-up 10 minutes before, with Join for Zoom, Meet,
  Teams, Webex and FaceTime links. *(Opt-in.)*
- **Charging and AirPods** – a little animation when you plug in, a heads-up at 20 %, and your headphones with
  left / right / case battery when they connect. *(Headphones are opt-in.)*

## Settings

<img src="docs/gifs/settings.gif" alt="The settings window" width="620" align="right">

Click the ✦ in the menu bar → **Settings…**

- **Agents** – connect Claude Code, Codex and Cursor
- **Nosy** – Nosy on or off, energy / levels / streaks, colour and wardrobe
- **Alerts** – sounds, mute for 1 h / 8 h / ∞, reminders
- **Permissions** – the notch buttons and head gestures
- **Usage** – which limits to show, a heads-up when a limit resets, context rings
- **Extras** – Shelf and AirDrop, how replies are sent, focus timer, battery, headphones, calendar
- **Music** – player and the live equalizer

Mute and the focus timer are also right in the menu bar menu. Everything that needs a macOS permission (controlling
your player, the live equalizer, head gestures, headphones, the calendar, replying by typing into an app) is off until
you turn it on – or asks only the first time you use it.

<br clear="right">

## Privacy

Everything stays on your Mac. The hooks talk to `127.0.0.1` only and nothing is uploaded. The only network requests
are for album covers (Spotify's public oEmbed with the track ID, Apple's iTunes Search with artist and title). The live equalizer analyses the
player's audio in memory and records nothing; head gestures only read motion while a request is open. The calendar,
headphone batteries and the conversation in the notch are read locally and never sent anywhere; Nosy's progress and the
shelf live in the app's settings. A reply typed in the notch goes to the session's own app (pasted with ⌘V, your
clipboard is put back) or to the agent's own CLI. Approvals are protected by a secret in
`~/.nosynotch/approval-token`, so no other process can answer in your name.

## How it works

```
Claude Code / Codex / Cursor ──hook (curl, ~15 ms)──▶ 127.0.0.1:7823 ──▶ Nosy Notch (SwiftUI panel over the notch)
```

All three agents have *hooks*: little commands they run at every step (prompt sent, tool started, permission needed,
done …). Nosy Notch adds a one-line `curl` that forwards each event to the app. If the app isn't running, `curl` fails
instantly and the agent carries on as if nothing happened – hooks never slow it down.

| | Where the hooks live | Extra |
|---|---|---|
| Claude Code | `settings.json` in `~/.claude`, `$CLAUDE_CONFIG_DIR` and every `~/.claude-*` account folder | Usage limits and context via a silent status line – preserves your existing status line |
| Codex | `~/.codex/hooks.json` | Limits and context from its session files |
| Cursor | `~/.cursor/hooks.json` | Prints `{}` so Cursor never waits on it – except `beforeShellExecution` for commands outside the sandbox, which waits for Allow / Deny |

The permission hook is the one exception that waits: it holds the request until you click in the notch. Answer in the
terminal instead, or let it time out, and the agent's own prompt takes over.

## Build from source

Requires macOS 14+ and the free Xcode Command Line Tools (`xcode-select --install`).

```bash
swift run                      # run directly
./scripts/build-app.sh --open  # build and open build/Nosy Notch.app
./scripts/record-gifs.sh       # re-record the GIFs in docs/gifs and the website videos (needs ffmpeg)
./scripts/record-gifs.sh done  # just one scene ("settings" = the settings window)
```

The recorder renders on a virtual clock, so no frame is ever dropped – a slow Mac just takes longer. Each scene
becomes a GIF for this README (30 fps, 840 px) and an MP4 + JPG poster in `website/public/demo/`. Options as
environment variables: `FPS=60` capture rate, `SCALE=3` for sharper 1680 px frames (default 2), `GIF_WIDTH` /
`GIF_FPS` / `GIF_COLORS`, `VIDEO=0` for GIFs only, `WEBM=1` for VP9 WebMs too, `STILLS=1` for PNG stills.

Releases: bump the version in `package.json` and `Resources/Info.plist`, push a tag `vX.Y.Z`. GitHub Actions builds a
universal binary, attaches it to the release and publishes to npm if the `NPM_TOKEN` secret is set.

<details>
<summary>Project layout</summary>

```
bin/nosynotch.js                     npx CLI (download, hooks, start/stop, autostart)
Sources/NosyNotch/
├── main.swift / AppDelegate.swift   app lifecycle, menu bar item, CLI flags
├── EventServer.swift                tiny HTTP server (Network.framework, loopback only)
├── HookEvent.swift                  hook JSON → event (Claude, Codex and Cursor dialects)
├── SessionStore.swift               event stream → state per session, unseen results, reminders
├── Session.swift                    states, agents, tool icons/labels, colours, error texts
├── HookInstaller.swift              hooks for Claude Code, Codex and Cursor
├── Approvals.swift                  permission requests waiting for Allow / Deny
├── HeadGestures.swift               nod / shake with AirPods
├── Usage.swift                      usage limits and context fill
├── Nosy/                            Nosy: drawing, moods, energy / levels / streaks, hanging + tar dive
├── Chat.swift                       transcripts → conversation, sending replies
├── Shelf.swift                      parked files, AirDrop
├── Notices.swift                    charging, low battery, headphones, meetings
├── FocusTimer.swift                 Pomodoro timer
├── CalendarMonitor.swift            next meeting (EventKit)
├── NowPlaying.swift                 Spotify / Apple Music: track, cover, controls
├── AudioSpectrum.swift              live equalizer: Core Audio tap + FFT
├── Notifier.swift                   sounds, banners, mute, bringing the right app to the front
├── NotchViewModel.swift             what the notch shows and how big it is
├── NotchWindow.swift                transparent panel over the notch, hover without stealing clicks
├── Clock.swift                      wall clock, or a virtual one while recording
├── Recorder.swift                   GIF / video recorder (--record, --record-settings)
└── Views/                           notch shape, spark, confetti, media player, settings …
```
</details>

<sub>Not affiliated with Anthropic, OpenAI or Anysphere. Claude is a trademark of Anthropic, Codex and ChatGPT are
trademarks of OpenAI, Cursor is a trademark of Anysphere.</sub>
