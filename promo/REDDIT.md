# Reddit launch v0.3: "Meet Nosy"

Ready-to-copy posts (English) for the v0.3 launch with Nosy, the chat in the notch, shelf + AirDrop, calendar, battery, AirPods and the focus timer. Background and sources are in [`RESEARCH.md`](RESEARCH.md).

> **Placeholders:** the posts describe the features as planned (as of 2026-11-07). Before posting, check that everything is in the release exactly like this, especially the points marked ⚠ in the checklist. Delete anything that didn't make it.

---

## 0. Before the first post

- [ ] Release **v0.3.0** on GitHub, `npx nosynotch` tested from npm on a clean account
- [ ] README: **Nosy video as the very first item** (dive into the notch), then the sections in sketchy style (one heading + one clip per capability)
- [ ] GitHub description, e.g.: *"A tiny helper in your MacBook notch: watches Claude Code, Codex and Cursor, plays your music, holds your files. Free, local, MIT."*
- [ ] ⚠ Check feature status: reply from the notch (how exactly: Accessibility / typing into the app?), calendar + AirPods opt-in, Nosy accessories and level names, timer mutes agent sounds
- [ ] Clips recorded (see 1.)
- [ ] Reddit karma: r/ClaudeAI needs **≥ 50 total karma** for a feed post (otherwise megathread), r/macapps **10 sub karma** + 1 dev post per 30 days. Comment helpfully in the subs a few days before posting.
- [ ] Have the first comment of your own (section 4) ready to paste

## 1. Clips you need

Upload MP4s, not GIFs (sharper, smaller; Reddit turns GIFs into video anyway). A post holds **one video** or a **gallery** (up to 20 images/GIFs).

| File (suggestion) | Content | Length | Main clip for |
|---|---|---|---|
| `nosy-hero.mp4` | **Hero:** Nosy stands under the notch → hops → dives in like a tar puddle (splash, ripple) → only his eyes look out and follow the cursor. Then an agent finishes: he drips back out, jumps for joy, confetti. | 8–12 s, loopable | r/ClaudeAI, r/vibecoding, r/SideProject, r/MacOS |
| `nosy-moods.mp4` | Montage: working (focused, sweat drop) → needs you (waves, Allow/Deny) → done (happy) → sleeping (zzz) → "oh! hi" | 10 s | r/ClaudeCode, extra |
| `nosy-levelup.mp4` | Task done → energy bar fills → "Level 4" → antenna grows / headphones unlocked, streak flame | 5 s | extra, r/vibecoding |
| `chat.mp4` | Hover → the answer in the notch → type a reply → send → the agent works again | 8 s | r/ClaudeCode, r/cursor, r/codex |
| `shelf-airdrop.mp4` | Drag a file onto the notch → the "Shelf / AirDrop" targets open → drop → the AirDrop dialog opens | 6 s | r/macapps, r/MacOS |
| `calendar.mp4` | "Standup in 10 min" slides out, Join button | 4 s | r/macapps extra |
| `charging.mp4` | Plug in the charger → charging animation, Nosy plugs himself in | 3 s | r/macbookpro, extra |
| `airpods.mp4` | AirPods connect → name + L/R/case battery | 3 s | extra |
| `timer.mp4` | Focus timer runs, Nosy holds his ears shut, timer done | 4 s | extra |
| Existing: `attention.mp4`, `usage.mp4`, `limit-reset.mp4`, `media.mp4` | from `website/public/demo/` | | extras |

**Rule:** the first second always shows Nosy or the notch moving. Never a black start frame or the desktop first.

## 2. Order and timing

US prime time: **Tuesday–Thursday, 8–10 am ET = 2–4 pm German time.** 3–4 subs per day at most, each with its own text. Answer every comment in the first 2 hours.

| Day | Subs | Why |
|---|---|---|
| 1 (Tue) | r/ClaudeAI, r/ClaudeCode | Core audience, biggest lever. Two different texts (story vs. tech). |
| 2 (Wed) | r/macapps (if eligible, otherwise megathread), r/SideProject | Mac audience for shelf/calendar/music, builder audience |
| 3 (Thu) | r/vibecoding, r/cursor | Casual + Cursor users |
| 4 (Fri) | r/codex, r/ChatGPTCoding, r/OpenAI (only in the project thread) | Codex audience |
| 5–6 (weekend) | r/MacOS, r/opensource, r/coolgithubprojects | Broad reach, weekend browsers |
| +1 week | r/swift / r/SwiftUI (technical post), r/macbookpro, Show HN, email to Korben | Second wave with a "how I built it" angle |

---

## 3. Posts

### r/ClaudeAI
**Flair:** Built with Claude · **Media:** `nosy-hero.mp4`

**Title**
```
I built a tiny helper that lives in my MacBook notch, works along with Claude Code and jumps for joy when it's done
```

**Text**
```
I'm the developer, and I built this almost entirely with Claude Code.

Claude Code often works on its own for minutes, then sits there waiting for a "yes" I never saw. So my notch app Nosy Notch got a resident: Nosy, a small egg-shaped helper with big eyes and a little ✦ antenna.

- When the notch closes, Nosy jumps into it like a tar puddle and looks out with just his eyes (they follow your cursor).
- While Claude works he concentrates; on long runs he sweats, when the context compacts he gets dizzy.
- When Claude needs permission he waves – you click Allow / Deny right in the notch (or nod with AirPods).
- When it's done he drips back out and jumps for joy. Nothing going on for a while? He falls asleep.
- Every finished task feeds him: energy, levels, a daily streak, unlockable accessories. And on purpose: he never dies and never guilt-trips you. Worst case he's sleepy.

New in this version: read Claude's answer and reply right from the notch, plus a file shelf with AirDrop, calendar heads-ups, battery and AirPods status and a focus timer.

How Claude helped: it wrote the Swift/SwiftUI app, the hook server and the npx installer, tested the PermissionRequest hook against real sessions, and built the frame-by-frame recorder for the clips. My part: the idea, the character, and a lot of "cuter, calmer, bigger".

Free and open source (MIT), everything stays on your Mac. Also works with Codex and Cursor.
Try it: npx nosynotch (macOS 14+)
GitHub: https://github.com/ddkbs/nosynotch

What should Nosy unlock at level 10?
```

### r/ClaudeCode
**Flair:** Showcase / Project · **Media:** `nosy-moods.mp4` (or `chat.mp4`)

**Title**
```
Claude Code hooks → a notch helper that mirrors your session's state (and you can reply to Claude from the notch now)
```

**Text**
```
Dev here. Nosy Notch turns Claude Code's hooks into a little character in the MacBook notch. Quick tour of how the states map:

- UserPromptSubmit / PreToolUse → Nosy concentrates, the notch shows the tool (Bash, Edit, Grep …) and the elapsed time
- PreCompact → spiral eyes
- PermissionRequest → he waves; the hook waits and the notch shows Deny / Always allow / Allow (Claude's own dialog stays open too). Answers carry a local secret, and "Always allow" never passes the setMode suggestion.
- Stop → he jumps out of the notch, confetti, first lines of the answer
- StopFailure → shocked ✕✕ eyes with the readable error (rate limit, overloaded …)
- rate_limits at 100 % → exhausted; when a limit you'd nearly used up resets → "Claude is ready again"

New: hover a session to read the conversation, and reply right from the notch. Finished turns feed Nosy (energy, level, streak) – no guilt mechanics, he just gets sleepy.

Every hook is one curl to 127.0.0.1; if the app isn't running, curl fails instantly and Claude carries on. Installs into ~/.claude, $CLAUDE_CONFIG_DIR and every ~/.claude-* account folder. Usage + context come from a silent status line, only if you don't have your own.

npx nosynotch · https://github.com/ddkbs/nosynotch
Free, MIT, local. Which state would you want him to show that he doesn't yet?
```

### r/macapps
**Format:** "AppName — descriptor" · disclosure as the first line · **Media:** gallery `shelf-airdrop`, `nosy-hero`, `calendar`, `media` (or video `shelf-airdrop.mp4`)
> Only if you're eligible (1 dev post / 30 days, 10 sub karma). Otherwise as a comment in the monthly megathread "The App Pile", shortened.

**Title**
```
Nosy Notch — free, open-source notch app with a file shelf, AirDrop, calendar, music and a tiny resident helper
```

**Text**
```
Disclosure: I'm the developer. Free, open source (MIT), no account, no tracking.

Nosy Notch turns the MacBook notch into a small dynamic area:

- Shelf + AirDrop: drag a file onto the notch, drop it on "Shelf" to park it or on "AirDrop" to send it. Drag it back out later.
- Calendar: next meeting on hover, a heads-up 10 minutes before with a Join button for Zoom / Meet / Teams links (opt-in, asks for calendar access).
- Battery: charging animation when you plug in, a warning at 20 %. AirPods: name and battery when they connect (opt-in).
- Focus timer right in the notch.
- Music: Spotify / Apple Music cover and an equalizer that follows the actual music, full player on hover.
- Nosy: a little helper who lives in the notch – he dives in like a tar puddle, looks out with his eyes, falls asleep when nothing happens and wakes up when you come by.
- If you code with AI agents (Claude Code, Codex, Cursor): live status, approve commands from the notch, usage limits.

Native Swift / SwiftUI, macOS 14+, Apple Silicon and Intel. Macs without a notch get a virtual one. Everything runs locally; the only network requests are album covers.

Install: npx nosynotch, or download from the GitHub release.
https://github.com/ddkbs/nosynotch

Happy to hear what you'd want on the shelf next.
```

### r/MacOS
**Flair:** Apps (if there is one) · **Media:** `nosy-hero.mp4`

**Title**
```
I gave my notch a tiny resident: he dives into it like a tar puddle and keeps an eye on things
```

**Text**
```
The notch is always there, so I made it a home for a small helper called Nosy.

When the notch closes he hops in with a splash and peeks out with just his eyes, which follow your cursor. When something happens he drips back out: a file you drag onto the notch (park it on the shelf or AirDrop it), a meeting in 10 minutes, your charger, your AirPods connecting, a focus timer finishing. When music plays he bobs along next to the cover and a live equalizer. Leave him alone long enough and he falls asleep.

If you code with AI tools (Claude Code, Codex, Cursor), he also shows what they're doing and waves when they need you.

Free, open source, native SwiftUI, macOS 14+. Macs without a notch get a virtual one.
https://github.com/ddkbs/nosynotch

What would you want him to react to?
```

### r/SideProject
**Media:** gallery `nosy-hero`, `chat`, `shelf-airdrop` (or video `nosy-hero.mp4`)

**Title**
```
I turned my MacBook notch into a home for a tiny tamagotchi that watches my AI coding agents
```

**Text**
```
The problem: AI coding agents run for minutes, then silently wait for an approval. I kept coming back to terminals that had been waiting for ten minutes.

v1 was a status display in the notch. It worked, but it felt like a tool. v0.3 gives it a character: Nosy, a small helper who lives in the notch. He dives in like a tar puddle, works along with your agent, waves when it needs you, jumps for joy when it's done, and falls asleep when nothing's happening. Finished tasks feed him (energy, levels, streaks) – without any guilt mechanics.

Also new: read and answer the agent right from the notch, a file shelf with AirDrop, calendar heads-ups, battery and AirPods status, a focus timer.

Stack: Swift / SwiftUI, the agents' own hooks talking to a tiny loopback HTTP server, a zero-dependency npx installer, animations rendered on a virtual clock for the clips. Works with Claude Code, Codex and Cursor. Free and MIT.

npx nosynotch
https://github.com/ddkbs/nosynotch

What's the one thing that would make you install it?
```

### r/opensource
**Media:** `nosy-hero.mp4` · keep it technical

**Title**
```
Nosy Notch – MIT-licensed macOS notch app: coding-agent status, file shelf, calendar and a little animated resident
```

**Text**
```
Nosy Notch is a native Swift / SwiftUI app (macOS 14+, MIT) for the MacBook notch.

- Shows live status from Claude Code, Codex and Cursor via their hooks; permission requests can be answered from the notch.
- Read and reply to a session's conversation from the notch.
- Shelf + AirDrop via drag and drop, calendar heads-ups (EventKit), battery and AirPods status, focus timer, Spotify / Apple Music with a Core Audio tap equalizer.
- Nosy, an animated helper drawn in SwiftUI: state machine over the agent events, a tar-splash morph into the notch, energy / level / streak stored locally.

Privacy by design: a loopback-only HTTP server that rejects browser requests, approvals signed with a local secret, no telemetry, no account. Everything that needs a macOS permission is off until you turn it on.

https://github.com/ddkbs/nosynotch
Issues and PRs welcome, especially support for more agents and new Nosy accessories.
```

### r/cursor
**Flair:** Showcase / Resources · **Media:** `chat.mp4` (or `nosy-moods.mp4`)

**Title**
```
Cursor's agent in the MacBook notch: live status, Allow/Deny for sandbox-escaping commands, and now a reply box
```

**Text**
```
Dev here. Nosy Notch hooks into ~/.cursor/hooks.json and shows what Cursor's agent is doing in the MacBook notch.

- A small helper (Nosy) concentrates while the agent works; the notch shows the tool and context fill.
- Terminal / MCP commands that leave Cursor's sandbox wait in the notch with Allow / Deny. ✕ or 45 s and Cursor's own prompt takes over.
- When it's done, Nosy jumps out with the first lines of the answer, and you can reply right there.
- Already looking at Cursor? Then it stays small and silent.

All other hooks never block Cursor (they print {} immediately). Claude Code and Codex sessions show up side by side if you use them too. Bonus for everyone: file shelf + AirDrop, calendar, music in the notch.

npx nosynotch · https://github.com/ddkbs/nosynotch
Free, MIT, local. Tell me if anything looks off with your setup.
```

### r/codex (also r/ChatGPTCoding, r/OpenAI only in the project thread)
**Media:** `nosy-moods.mp4` (Codex session with the blue hexagon)

**Title**
```
Codex in the MacBook notch: a little helper that works along, waves for approvals and lets you reply from the notch
```

**Text**
```
Codex has hooks now, so my notch app Nosy Notch supports it fully:

- Live status with Codex's blue hexagon, the command or patch it's on
- Approvals in the notch (Allow / Deny), answered straight through the PermissionRequest hook – ✕ and Codex shows its own prompt
- 5-hour / weekly limits and context fill from Codex's session files, plus a heads-up when a limit resets
- New: read the conversation and reply from the notch
- And Nosy, a small helper who lives in the notch and reacts to all of it – he jumps for joy when Codex is done and gets exhausted when you hit your limit

Works with the Codex CLI and the ChatGPT app's Codex mode, side by side with Claude Code and Cursor. Note: trust the hooks once in Codex (Settings → Hooks or /hooks).

npx nosynotch · https://github.com/ddkbs/nosynotch
Free, MIT, everything stays on your Mac.
```

### r/vibecoding
**Media:** `nosy-hero.mp4` (extra in comments: `nosy-levelup.mp4`)

**Title**
```
My coding agent now has a little buddy living in my notch who levels up every time it finishes a task
```

**Text**
```
I got tired of tabbing back to check if Claude Code was done, so I built a tiny helper that lives in my MacBook notch.

- He dives into the notch like a tar puddle and watches with his eyes
- concentrates while the agent works, sweats on long runs
- waves when it needs my OK (click Allow – or just nod with AirPods)
- jumps for joy when it's done, falls asleep when nothing's going on
- every finished task feeds him: energy, levels, streaks, little accessories. He never dies and never guilt-trips you, he just gets sleepy

I can read and answer the agent right from the notch too, and when I'm not coding it's a music player, file shelf with AirDrop and meeting reminder.

Works with Claude Code, Codex and Cursor. Free, open source, built mostly with Claude Code.
npx nosynotch
https://github.com/ddkbs/nosynotch
```

### r/coolgithubprojects
**Post type:** link post to `https://github.com/ddkbs/nosynotch`, `nosy-hero.mp4` in the first comment

**Title**
```
nosynotch – a tiny helper in the MacBook notch that watches Claude Code, Codex and Cursor (plus shelf, AirDrop, calendar, music)
```

### r/swift / r/SwiftUI (+1 week, technical)
**Media:** `nosy-hero.mp4` · no launch text, only "how"

**Title**
```
How I made a SwiftUI character dive into the MacBook notch like a tar puddle (and other notch-app lessons)
```

**Text**
```
I've been building Nosy Notch, a free notch app, and gave it an animated resident. Some things that might help others:

- The morph: the character's body and the notch edge are drawn as one path while they touch, so it looks like he melts into the black; then a few splash particles on a timeline (driven by a virtual clock so recordings are frame-exact).
- Eyes that follow the cursor without re-rendering the whole notch on every mouse move: a separate tiny ObservableObject only the eye view observes, throttled, smoothed with a spring.
- Notch panel: a borderless non-activating NSPanel above the menu bar, sized from safeAreaInsets and auxiliaryTopLeftArea / auxiliaryTopRightArea; it ignores mouse events except over the shape. For the reply box it becomes key only while the chat is open.
- Drag and drop onto the notch: watching NSPasteboard(name: .drag) during global drag events to open the drop zone before the cursor even arrives.
- Live equalizer: a Core Audio process tap on just the player's processes + vDSP FFT with per-band auto gain.

Code (MIT): https://github.com/ddkbs/nosynotch
Happy to go deeper on any of these.
```
> ⚠ Adjust the technical details to what the main session actually builds (morph technique, drag detection, key handling).

### r/macbookpro / r/macbookair (short)
**Media:** `charging.mp4` or `nosy-hero.mp4`

**Title**
```
Finally something lives in my notch
```

**Text**
```
Made a small free app: a little helper called Nosy lives in the notch. He jumps out when I plug in my charger, when my AirPods connect, when a meeting is coming up or when I drag a file onto the notch (shelf or AirDrop), bobs along to Spotify, and falls asleep when nothing's happening. Takes no space the rest of the time.

https://github.com/ddkbs/nosynotch
```

---

## 4. First comment of your own (post right after every post)

```
Some details for the curious:
- Install: npx nosynotch (downloads the app to ~/.nosynotch, connects Claude Code / Codex / Cursor if present, starts it). npx nosynotch uninstall removes everything.
- Privacy: hooks talk to 127.0.0.1 only; nothing is uploaded. Calendar, AirPods, head gestures, live equalizer and replying from the notch are off until you turn them on.
- Nosy's energy and streak are stored locally. He never dies – I wanted the cozy part of a tamagotchi without the guilt.
- Not signed with an Apple Developer ID yet (ad-hoc signed), so macOS may ask once.
Repo + every animation explained: https://github.com/ddkbs/nosynotch
```

## 5. Replies to expected questions

- **"How is this different from boring.notch / NotchNook?"**
  "I love boring.notch! Nosy Notch covers the same basics (music, shelf, AirDrop, calendar) but was built around AI coding agents first: approvals, replies, usage limits. And there's Nosy."
- **"…from Notchi / Buddi / Claude Island?"**
  "Those are great. The difference: approvals and replies from the notch for three agents, usage limits with reset alerts, and the regular notch features in the same app. And Nosy is a hand-designed character instead of a sprite."
- **"Battery / CPU?"**
  "It idles at ~0 % CPU. Animations only run while something is visible, and the hooks are a single curl per event." ⚠ Measure before claiming this.
- **"Why npx instead of a DMG / Homebrew?"**
  "npx also sets up the hooks for all agents in one go. There's also a .app download in every release." (Homebrew cask as a follow-up?)
- **"Will it stay free?"**
  "The app is MIT and stays free. If I ever do extras, the core stays open."
- **"Does it read my code?"**
  "No. It only sees the hook events (tool name, short description) and, for the chat, the session's transcript file on your Mac. Nothing leaves the machine."

## 6. Beyond Reddit (short)

- **Korben.info:** wrote about both boring.notch and Notchi. Short email with `nosy-hero.mp4` + 3 sentences + link, right after the release.
- **Show HN:** `Show HN: Nosy Notch – a tiny helper in the MacBook notch that watches your coding agents`, Tue–Thu 8–10 am ET.
- **HelloGitHub, Product Hunt** in week 2. Product Hunt with a Nosy gallery and the first comment as the maker story.
