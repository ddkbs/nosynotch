<h1 align="center">Nosy Notch</h1>

<p align="center">
  <b>Your MacBook notch keeps an eye on Claude Code and Codex – and plays your music while they take a break.</b>
</p>

<p align="center">
  <img src="docs/gifs/demo.gif" alt="Nosy Notch: Claude thinks, uses tools, asks for permission and finishes" width="720">
</p>

<p align="center">
  <code>npx nosynotch</code> · macOS 14+ · no account, no App Store, no Xcode
</p>

<table>
  <tr>
    <td align="center" width="50%"><img src="docs/gifs/thinking.gif" alt="Thinking"><br><b>Thinking</b><br><sub>The notch slides open, the spark spins</sub></td>
    <td align="center" width="50%"><img src="docs/gifs/tools.gif" alt="Working"><br><b>Working</b><br><sub>Live icon for every tool Claude uses</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/gifs/attention.gif" alt="Needs you"><br><b>Needs you</b><br><sub>Allow or deny right in the notch – glow, shake, sound</sub></td>
    <td align="center"><img src="docs/gifs/done.gif" alt="Done"><br><b>Done</b><br><sub>Checkmark, confetti and a summary of the answer</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/gifs/media.gif" alt="Music"><br><b>Music</b><br><sub>Spotify / Apple Music player while Claude is idle</sub></td>
    <td align="center"><img src="docs/gifs/handoff.gif" alt="Back to music"><br><b>Back to music</b><br><sub>Close a notification with ✕ and the music returns</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/gifs/error.gif" alt="Error"><br><b>Error</b><br><sub>Rate limit, overload, auth problems …</sub></td>
    <td align="center"><img src="docs/gifs/hover.gif" alt="All sessions"><br><b>All sessions</b><br><sub>Hover to see every running session</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/gifs/codex.gif" alt="Codex"><br><b>Codex too</b><br><sub>Codex CLI and the ChatGPT app's Codex mode, side by side with Claude</sub></td>
    <td align="center"><img src="docs/gifs/compacting.gif" alt="Compacting"><br><b>Compacting</b><br><sub>Purple spark while the context is compacted</sub></td>
  </tr>
</table>

<p align="center"><a href="docs/animations.md"><b>→ Every animation explained</b></a></p>

## Install

Open Terminal and run:

```bash
npx nosynotch
```

That's it. Needs macOS 14+ and [Node.js](https://nodejs.org) 18+ (for `npx`; `brew install node` works too). The command

1. downloads the app to `~/.nosynotch/` (or builds it locally with Swift if there is no release yet),
2. adds the hooks to your Claude Code settings – and to Codex (`~/.codex/hooks.json`) if you use it. A backup
   (`*.nosynotch.bak`) is created,
3. starts Nosy Notch in the background – no Dock icon, just a ✦ in the menu bar.

Restart Claude Code sessions that are already running once so they load the hooks. New sessions work right away.

**Codex:** Codex only runs hooks you trust. Trust the Nosy Notch hooks once – in the ChatGPT app under
**Codex → Settings → Hooks** (or **Review hooks** in the composer), in the CLI with `/hooks`.

```bash
npx nosynotch demo        # play every animation
npx nosynotch autostart   # start at login (autostart off to disable)
npx nosynotch status      # what is installed and running
npx nosynotch settings    # open the settings window
npx nosynotch stop
npx nosynotch uninstall   # removes app, hooks and autostart
```

## What it shows

| State | Notch |
|---|---|
| **Thinking** | Slides out sideways, the spark rotates and pulses, three dots dance on the right |
| **Working** | Spark spins faster, the right wing shows the tool (terminal, pencil, magnifier, globe …) |
| **Needs you** | Opens up with an amber glow and a shake, waving hand, the command it wants to run and **Allow / Deny** buttons, sound |
| **Compacting** | Purple spark that shrinks and turns backwards |
| **Done** | Checkmark draws itself, confetti, project, duration and the start of Claude's answer, sound. Already looking at that app? Just a small check in the notch, no sound |
| **Error** | Red glow and a sputtering spark when a turn dies from an API error (rate limit, overload, auth …) |
| **Music** | When Claude is idle: album cover left, equalizer in the cover's colour right. Hover for the player |
| **Hover** | List of all sessions with status, current tool and timer. Click jumps to the right terminal |

Works with several sessions at once – Claude Code and Codex mixed. Each session shows a small *Claude* / *Codex*
badge, Codex sessions spin in blue. Macs without a notch get a virtual one in the middle of the menu bar.

## How it works

```
Claude Code ──hook (curl, ~15 ms)──▶ 127.0.0.1:7823/event ──▶ Nosy Notch (SwiftUI panel over the notch)
```

Nosy Notch uses [Claude Code hooks](https://code.claude.com/docs/en/hooks), not MCP: an MCP server is only called when *Claude*
decides to use a tool, but a live status needs every lifecycle event (`UserPromptSubmit`, `PreToolUse`, `PostToolUse`,
`PermissionRequest`, `Notification`, `Stop`, `StopFailure`, `PreCompact`, `SessionStart/End` …).

Every hook is a one-line `curl` that posts the hook's JSON to the app. If the app isn't running, `curl` fails instantly and
`|| true` makes sure Claude Code is never blocked or slowed down.

There is nothing to pair or log into: once the hooks are in `settings.json`, **every** Claude Code session – terminal, VS Code,
the desktop app – reports to the notch.

**Codex** (the CLI and the Codex mode of the ChatGPT desktop app) has the same kind of hooks. Nosy Notch adds the same
one-line `curl` to `~/.codex/hooks.json` (or `$CODEX_HOME/hooks.json`) with `&agent=codex` in the URL. Codex skips new hooks
until you trust them once (see [Install](#install)). Bonus: Codex reports when you interrupt a turn, so its status never gets stuck.

**Several accounts / `CLAUDE_CONFIG_DIR`:** each config directory has its own `settings.json`. Nosy Notch installs the hooks into
`~/.claude`, `$CLAUDE_CONFIG_DIR` and every `~/.claude-*` folder that looks like a config directory. `npx nosynotch status`
lists each one. Added an account later? Run `npx nosynotch hooks` again.

## Allow or deny from the notch

When Claude Code or Codex asks for permission, the notch shows the command with **Deny** and **Allow** (plus
**Always allow** when Claude Code offers a rule for it). Click, and the agent carries on – no need to find the right terminal.

- **Claude Code** keeps its own dialog open at the same time. Answer wherever you like; the other one closes.
- **Codex** shows its own prompt only after the hook returns: click ✕ in the notch (or wait 45 s) to answer in Codex instead.
- Your settings still win: a matching deny rule blocks the command even if you click Allow. *Always allow* only adds
  allow rules or directories, never switches the permission mode.
- The permission hook waits for the notch and prints its answer only if it carries a secret from
  `~/.nosynotch/approval-token`. If Nosy Notch isn't running, the hook ends immediately and the normal prompt appears.
- Turn it off in Settings → Permissions.

## Music

When no Claude session is busy and **Spotify** or **Apple Music** is playing, the notch turns into a mini player. Claude always
wins: as soon as a session works or needs you, the notch switches over, and the music comes back afterwards.

- Track info comes from the notifications Spotify and Music broadcast anyway – no permission needed.
- For play/pause, next and seeking, macOS asks once per player whether Nosy Notch may control it ("Automation").
- Covers: Spotify's public oEmbed endpoint and Apple's iTunes Search. Only the track ID (Spotify) or artist + title (Music) is sent.
- Browser audio, YouTube and podcasts aren't supported yet: Apple closed the private MediaRemote API to third-party apps in macOS 15.4.

## Settings

Click the ✦ in the menu bar → **Settings…** (or run `npx nosynotch settings`):

- **Claude Code** – which config directories are connected, one button to connect or disconnect, play the demo
- **Codex** – connect or disconnect `~/.codex/hooks.json`
- **Permissions** – answer permission requests in the notch (on by default)
- **Launch at login**
- **Notifications** – sound for done / needs you / error, how long notifications stay open, keep "Done" small while you're
  already in that app, optional macOS banners
- **Music** – show Spotify / Apple Music in the notch, keep showing it while paused

If you start the app without the CLI (e.g. built from source), the settings open on first launch with a big
**Connect Claude Code** button.

## Build from source

Requires macOS 14+ and the free Xcode Command Line Tools (`xcode-select --install`).

```bash
swift run                      # run directly
./scripts/build-app.sh --open  # build and open build/Nosy Notch.app
```

<details>
<summary>Add the hooks manually</summary>

For every event (`SessionStart`, `SessionEnd`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`,
`PermissionRequest`, `Notification`, `Stop`, `StopFailure`, `SubagentStop`, `PreCompact`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "timeout": 5,
            "command": "curl -s -m 2 -X POST -H 'Content-Type: application/json' -H 'Expect:' -H \"X-Term-Program: ${TERM_PROGRAM:-}\" -H \"X-Bundle-Id: ${__CFBundleIdentifier:-}\" --data-binary @- 'http://127.0.0.1:7823/event?src=nosynotch' >/dev/null 2>&1 || true"
          }
        ]
      }
    ]
  }
}
```

`matcher` is only needed for the tool events (`PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`).
</details>

## Development

`swift run` starts without an app bundle, so macOS notifications don't work there – everything else does.

Re-record the GIFs: `./scripts/record-gifs.sh` (needs `ffmpeg`), see [docs/animations.md](docs/animations.md#re-recording-the-gifs).

Releases: bump the version in `package.json` and push a tag `vX.Y.Z`. GitHub Actions builds the universal binary
(arm64 + x86_64), attaches it to the release and publishes to npm if the `NPM_TOKEN` secret is set.

```
bin/nosynotch.js                     npx CLI (download, hooks, start/stop, autostart)
Sources/NosyNotch/
├── main.swift / AppDelegate.swift   app lifecycle, menu bar item, CLI flags
├── EventServer.swift                tiny HTTP server (Network.framework, loopback only)
├── HookEvent.swift                  hook JSON → event
├── SessionStore.swift               event stream → state per session
├── Session.swift                    states, tool icons/labels, colours, error texts
├── NowPlaying.swift                 Spotify / Apple Music: track, cover, controls
├── Transcript.swift                 reads the last answer from the transcript (for "Done")
├── Approvals.swift                  permission requests waiting for Allow / Deny in the notch
├── HookInstaller.swift              patches settings.json in every Claude config directory and ~/.codex/hooks.json
├── Preferences.swift / LoginItem.swift  settings, launch at login
├── Notifier.swift                   sounds, notifications, bringing the terminal to the front
├── NotchViewModel.swift             presentation (hidden/compact/expanded/…/media) and sizes
├── NotchWindow.swift                transparent NSPanel over the notch, hover without stealing clicks
├── Demo.swift / Recorder.swift      demo run, GIF recorder (--record)
└── Views/                           notch shape, spark, indicators, confetti, checkmark, media player, settings …
```

If you interrupt a turn with Esc / Ctrl-C, Claude Code sends no `Stop` event. The session then falls back to "Ready" after a
timeout (10 min thinking / 30 min tool), at the latest with your next prompt. You can also remove it from the hover list with ✕.

Not affiliated with Anthropic or OpenAI. Claude is a trademark of Anthropic, Codex and ChatGPT are trademarks of OpenAI.
