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
- [ ] Reddit karma: r/ClaudeAI needs **> 100 karma** for a feed post (otherwise megathread). Comment helpfully in the subs a few days before posting.
- [ ] Have the first comment of your own (section 4) ready to paste

## 1. Clips you need

**Finished promo video (44 s, voiceover + music):** `~/Desktop/Projects/nosy_sonstiges/nosy-video/renders/nosy-notch-promo.mp4` (HyperFrames project next to it, rebuild with `python3 build.py`). Good as the main video for r/ClaudeAI, r/SideProject and r/vibecoding.

Upload MP4s, not GIFs (sharper, smaller; Reddit turns GIFs into video anyway). A post holds **one video** or a **gallery** (up to 20 images/GIFs).

| File (suggestion) | Content | Length | Main clip for |
|---|---|---|---|
| `nosy-hero.mp4` | **Hero:** Nosy stands under the notch → hops → dives in like a tar puddle (splash, ripple) → only his eyes look out and follow the cursor. Then an agent finishes: he drips back out, jumps for joy, confetti. | 8–12 s, loopable | r/ClaudeAI, r/vibecoding, r/SideProject |
| `nosy-moods.mp4` | Montage: working (focused, sweat drop) → needs you (waves, Allow/Deny) → done (happy) → sleeping (zzz) → "oh! hi" | 10 s | r/ClaudeCode, extra |
| `nosy-levelup.mp4` | Task done → energy bar fills → "Level 4" → antenna grows / headphones unlocked, streak flame | 5 s | extra, r/vibecoding |
| `chat.mp4` | Hover → the answer in the notch → type a reply → send → the agent works again | 8 s | r/ClaudeCode, r/codex |
| `shelf-airdrop.mp4` | Drag a file onto the notch → the "Shelf / AirDrop" targets open → drop → the AirDrop dialog opens | 6 s | extra (later r/macapps) |
| `calendar.mp4` | "Standup in 10 min" slides out, Join button | 4 s | extra |
| `charging.mp4` | Plug in the charger → charging animation, Nosy plugs himself in | 3 s | extra |
| `airpods.mp4` | AirPods connect → name + L/R/case battery | 3 s | extra |
| `timer.mp4` | Focus timer runs, Nosy holds his ears shut, timer done | 4 s | extra |
| Existing: `attention.mp4`, `usage.mp4`, `limit-reset.mp4`, `media.mp4` | from `website/public/demo/` | | extras |

**Rule:** the first second always shows Nosy or the notch moving. Never a black start frame or the desktop first.

## 2. Order and timing

US prime time: **Tuesday–Thursday, 8–10 am ET = 2–4 pm German time.** 3–4 subs per day at most, each with its own text. Answer every comment in the first 2 hours.

| Day | Subs | Why |
|---|---|---|
| 1 (Tue) | r/ClaudeAI, r/ClaudeCode | Core audience, biggest lever. Two different texts (story vs. tech). |
| 2 (Wed) | r/SideProject, r/vibecoding | Builder audience + casual vibe coders |
| 3 (Thu) | r/codex, r/ChatGPTCoding, r/OpenAI (only in the project thread) | Codex audience |
| 4–5 (weekend) | r/opensource, r/coolgithubprojects | Broad reach, weekend browsers |
| +1 week | r/swift / r/SwiftUI (technical post), Show HN, email to Korben | Second wave with a "how I built it" angle |
| +1 week | r/AI_Agents, r/indiehackers, r/alphaandbetausers (3c) | Second wave, agents + builders + testers |
| +8–10 days | r/devtools, r/IMadeThis, r/aipromptprogramming, r/AIToolsTech, r/aitools (3c) | Small subs, low risk |
| +10–12 days | r/tamagotchi, r/virtualpets (3c, check rules first) | Pet fans, Nosy as the hook |
| at 100 ★ | r/macapps (post parked in 3b) | Only once the repo has 100 stars |

Deliberately left out: r/MacOS, r/cursor, r/macbookpro, r/macbookair.

---

## 3. Posts

### r/ClaudeAI
**Flair:** Built with Claude · **Media:** `nosy-hero.mp4`
> Sub rules (as of now): built with/for Claude **by you**, detailed description of how Claude helped, **say it's free to try**, minimal promo language, no referral links. **Feed posts need > 100 karma**, otherwise the megathread.

**Title**
```
I built a free Mac app with Claude Code: a tiny helper in the MacBook notch that shows what Claude Code is doing
```

**Text**
```
I built Nosy Notch, a free and open-source macOS app, almost entirely with Claude Code. It's free to try, no paid tier.

What it does
Claude Code often works on its own for minutes, then waits for a "yes" I never saw. Nosy Notch shows every Claude Code session in the MacBook notch, with a small helper called Nosy living in it:
- While Claude works, the notch shows the tool it's running and Nosy concentrates. When the context compacts, he gets dizzy.
- When Claude asks for permission, Nosy waves and the notch shows Deny / Always allow / Allow. Claude's own dialog stays open too.
- When a turn is done, he drips out of the notch and jumps for joy, with the first lines of the answer. You can read the conversation and reply right from the notch.
- Hover for all sessions, context fill and your 5-hour / weekly limits. When nothing runs, he falls asleep in the notch.
- Finished tasks give him energy, levels and a streak. He never dies and never guilt-trips you.
- Also: music player, file shelf with AirDrop, calendar heads-ups, battery and AirPods status, focus timer. Works with Codex and Cursor too.

How Claude Code helped
Claude Code wrote the Swift/SwiftUI app, the local hook server, the npx installer and the website. My part was the idea, the character design and testing on my Mac. Some things it did on its own:
- It read the hooks docs, then ran real Claude Code sessions with a test PermissionRequest hook. That's how it found out Claude's dialog stays open while the hook waits, which is what makes approving from the notch possible. It also saw that one "always allow" suggestion switches the session mode, so it filters that out.
- When the app froze on launch, it profiled the process with sample and found an Apple Events permission check blocking the main thread.
- For Nosy, it drew several rounds of sketches in the chat until we had the character, then built the "jumps into the notch like a tar puddle" animation in SwiftUI.
- It built a recorder that renders the animations frame by frame on a virtual clock, which made the clips in this post.
- A security pass it ran found that a website could post to the local server, so the server now rejects browser requests.

Try it (free)
macOS 14+ and Node: npx nosynotch installs the app, connects the hooks and starts it. npx nosynotch uninstall removes everything. Everything stays on your Mac, MIT licensed.
Website: https://nosynotch.davidkubus.dev
GitHub: https://github.com/ddkbs/nosynotch

Feel free to try it out and leave your feedback!
```

### r/ClaudeCode
**Flair:** Built with Claude Code (or Showcase) · **Media:** `nosy-moods.mp4` (or `chat.mp4`)
> Sub rule: simple project sharing goes in the weekly showcase thread. A standalone post must explain **what you built, how Claude Code was used and what you learned**. That's why this text is longer and has those three parts.

**Title**
```
I built a little helper that lives in my MacBook notch and keeps an eye on Claude Code for me. Here's how Claude Code built it and what I learned
```

**Text**
```
What I built

Nosy Notch is a free Mac app that turns the MacBook notch into a small window into your Claude Code sessions. A little helper called Nosy lives in it:

- While Claude works, the notch shows what it's doing right now and Nosy concentrates along with it
- When Claude needs your permission, Nosy waves and you can click Allow or Deny right in the notch
- When Claude is done, Nosy jumps out of the notch for joy and shows the start of the answer
- You can read the conversation and reply to Claude directly from the notch
- Hover to see all your sessions, how full each one is and how much of your usage limit is left
- When nothing is running, Nosy falls asleep in the notch
- Every finished task gives him energy, levels and a daily streak. He never dies and never makes you feel guilty
- On the side: music player, a shelf for files with AirDrop, meeting reminders, battery and AirPods status and a focus timer

It also works with Codex and Cursor, and everything stays on your Mac.

How I used Claude Code

I didn't write the code myself. I described what I wanted, Claude Code built it, tested it and showed me the result. My job was the idea, testing on my Mac and a lot of feedback like "cuter", "calmer" or "bigger".

- Instead of guessing how Claude Code's permission prompts behave, it ran real test sessions and found out that approving from the notch works while Claude's own prompt stays open.
- For Nosy, it drew rough sketches in the chat, round after round, until the character felt right. Then it built the animations, including Nosy jumping into the notch like into a puddle.
- It built its own little recorder to film the animations, so it could look at the result itself instead of asking me every time.
- I ran a second Claude Code session in parallel for the promo (including this post) while the first one kept building.

What I learned

- Let it test for real. The best moments came when Claude Code tried something in a real session instead of trusting what it assumed.
- Show, don't describe. Once it could record and look at its own animations, the feedback rounds got much shorter.
- Sketch before you build. A few rough drawings saved hours of building the wrong character.
- Keep a worklog. I use several Claude accounts without a shared chat history, so a short WORKLOG.md in the repo keeps every session up to date.
- Small commits. Every finished piece gets its own commit, so I can undo exactly the part I don't like.

Try it

It's free and open source. On macOS 14+ run: npx nosynotch
https://github.com/ddkbs/nosynotch
https://nosynotch.davidkubus.dev

Feel free to try it out and leave your feedback!
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
https://nosynotch.davidkubus.dev

Feel free to try it out and leave your feedback!
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
https://nosynotch.davidkubus.dev
Issues and PRs welcome, especially support for more agents and new Nosy accessories.

Feel free to try it out and leave your feedback!
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
https://nosynotch.davidkubus.dev
Free, MIT, everything stays on your Mac.

Feel free to try it out and leave your feedback!
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
https://nosynotch.davidkubus.dev

Feel free to try it out and leave your feedback!
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
Website: https://nosynotch.davidkubus.dev
Happy to go deeper on any of these.

Feel free to try it out and leave your feedback!
```
> ⚠ Adjust the technical details to what the main session actually builds (morph technique, drag detection, key handling).

## 3b. Parked

### r/macapps (parked until 100 ★)
**Format:** "AppName — descriptor" · disclosure as the first line · **Media:** gallery `shelf-airdrop`, `nosy-hero`, `calendar`, `media` (or video `shelf-airdrop.mp4`)
> Only once the repo has **100 stars**. Then also check: 1 dev post / 30 days, 10 sub karma, otherwise the monthly megathread "The App Pile".

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
https://nosynotch.davidkubus.dev


Feel free to try it out and leave your feedback!
```

---

## 3c. Second wave (after the first week)

Plain-text bodies, same style as above. Vary the media so the posts don't look copy-pasted.

### r/AI_Agents
**Flair:** check the sidebar (project / showcase) · **Media:** `nosy-notch-promo.mp4` or `attention.mp4`

**Title**
```
Long-running coding agents have an attention problem. I put a little helper in my MacBook notch to fix mine
```

**Text**
```
Coding agents like Claude Code, Codex and Cursor work on their own for minutes, then stop and wait for a human who isn't looking. That gap was costing me more time than the agents saved.

So I built Nosy Notch, a free Mac app that turns the notch into a small control spot for every agent session:

- Live state per session: thinking, which tool it's running, compacting, waiting, error
- Permission requests show up in the notch with Allow / Deny, and the answer goes straight back to the agent
- When a turn ends you see the start of the answer, and you can read the conversation and reply from the notch
- A green dot if you missed a result, plus one reminder after 5 minutes
- Context fill per session and your usage limits, with a heads-up when a limit resets
- Stays quiet when you're already looking at the agent's window

A small helper called Nosy lives in the notch and shows all of this at a glance: he concentrates while the agent works, waves when it needs you and cheers when it's done.

It works through each agent's own hooks and runs fully on your Mac.

What do you want to see from an agent at a glance?

https://github.com/ddkbs/nosynotch
https://nosynotch.davidkubus.dev

Feel free to try it out and leave your feedback!
```

### r/aipromptprogramming
**Media:** `nosy-notch-promo.mp4`

**Title**
```
I built a Mac app with Claude Code that tells me when my coding agent needs me (and lets me answer from the notch)
```

**Text**
```
If you run Claude Code, Codex or Cursor for longer tasks, you know the moment: you come back and it has been waiting for your "yes" for ten minutes.

Nosy Notch puts that into the MacBook notch:
- see what the agent is doing right now
- Allow / Deny permission requests right there
- read the answer and reply without switching windows
- usage limits and context fill on hover

A little helper named Nosy lives in the notch and reacts to everything, from concentrating to cheering. Finished tasks level him up.

I built the whole thing with Claude Code: I described what I wanted and gave feedback, Claude Code wrote, tested and recorded it. Free and open source.

https://github.com/ddkbs/nosynotch
https://nosynotch.davidkubus.dev

Feel free to try it out and leave your feedback!
```

### r/AIToolsTech
**Media:** `nosy-notch-promo.mp4`

**Title**
```
Nosy Notch: a free Mac app that shows Claude Code, Codex and Cursor in your MacBook notch
```

**Text**
```
What it is: a free, open-source macOS app for people who code with AI agents.

What it does:
- Shows live what your agent is doing, right in the notch
- Lets you allow or deny its commands with one click
- Shows the answer when it's done and lets you reply from the notch
- Tracks your usage limits and how full each session's context is
- Nosy, a small helper living in the notch, reacts to all of it and levels up with every finished task

Extras: music player, file shelf with AirDrop, meeting reminders, battery and AirPods status, focus timer.

Works with: Claude Code, Codex, Cursor. Runs locally, no account. Install with: npx nosynotch (macOS 14+)

https://github.com/ddkbs/nosynotch
https://nosynotch.davidkubus.dev

Feel free to try it out and leave your feedback!
```

### r/aitools
**Media:** `nosy-notch-promo.mp4`

**Title**
```
Free tool: approve your AI coding agent's commands from the MacBook notch
```

**Text**
```
I made a free Mac app for anyone using Claude Code, Codex or Cursor.

Your MacBook notch becomes a little status window: it shows what the agent is doing, asks you right there when it needs permission, and shows the answer when it's done, with a reply box. A small helper called Nosy lives in it and reacts along the way.

No account, nothing leaves your Mac, open source. Install: npx nosynotch

https://github.com/ddkbs/nosynotch
https://nosynotch.davidkubus.dev

Feel free to try it out and leave your feedback!
```

### r/IMadeThis
**Media:** `nosy-notch-promo.mp4`

**Title**
```
I made a tiny helper that lives in my MacBook notch
```

**Text**
```
His name is Nosy. He lives in the notch of my MacBook and keeps an eye on my AI coding tools for me.

When the agent works, he concentrates. When it needs my permission, he waves and I click Allow right in the notch. When it's done, he jumps out and cheers, and I can read the answer and reply from there. When nothing happens for a while, he falls asleep.

Every finished task gives him energy and levels, and he keeps a daily streak. On purpose he never dies and never makes you feel guilty.

It's a free, open-source Mac app and works with Claude Code, Codex and Cursor.

https://github.com/ddkbs/nosynotch
https://nosynotch.davidkubus.dev

Feel free to try it out and leave your feedback!
```

### r/alphaandbetausers
**Media:** `nosy-notch-promo.mp4` · tone: asking for testers

**Title**
```
Looking for testers: a free Mac app that puts your AI coding agent in the MacBook notch
```

**Text**
```
I'm the developer of Nosy Notch and I'm looking for people who use Claude Code, Codex or Cursor on a Mac to try it and tell me what's broken or confusing.

What it does:
- shows what your agent is doing in the notch
- Allow / Deny permission requests from the notch
- read the answer and reply without switching windows
- usage limits and context fill on hover
- a little helper called Nosy who reacts to everything and levels up with finished tasks
- extras: music, file shelf with AirDrop, meeting reminders, battery, AirPods, focus timer

Requirements: macOS 14+ and Node (for the installer).
Install: npx nosynotch · Remove everything: npx nosynotch uninstall

What I'd love feedback on: setup, anything that feels noisy or annoying, and what you'd want the notch to show next.

https://github.com/ddkbs/nosynotch
https://nosynotch.davidkubus.dev

Feel free to try it out and leave your feedback!
```

### r/devtools
**Media:** `attention.mp4` or `nosy-notch-promo.mp4`

**Title**
```
Nosy Notch: Claude Code, Codex and Cursor status, approvals and replies in the MacBook notch
```

**Text**
```
A free, open-source macOS app (Swift / SwiftUI) for developers who work with coding agents.

- Hooks into Claude Code, Codex and Cursor (one local curl per event; if the app isn't running, the agent just carries on)
- Live status per session, several sessions and agents at once
- Permission requests answered from the notch, signed with a local secret so no other process can answer for you
- Read the conversation and reply from the notch
- Usage limits and context fill, with an alert when a limit resets
- No account, no telemetry, loopback only

Plus a small animated helper, Nosy, who mirrors what your agent is doing.

Install: npx nosynotch (macOS 14+). MIT licensed.

https://github.com/ddkbs/nosynotch
https://nosynotch.davidkubus.dev

Feel free to try it out and leave your feedback!
```

### r/indiehackers
**Media:** `nosy-notch-promo.mp4` · tone: story + learnings

**Title**
```
I built a Mac app almost entirely with Claude Code. Here's what it does and what I learned
```

**Text**
```
What I built
Nosy Notch, a free Mac app that turns the MacBook notch into a home for a little helper called Nosy. He keeps an eye on AI coding agents (Claude Code, Codex, Cursor): he waves when the agent needs your permission, you click Allow right in the notch, he cheers when it's done, and you can read the answer and reply from there. Finished tasks level him up. On the side: music, a file shelf with AirDrop, meeting reminders, battery and AirPods status, a focus timer.

How I built it
I didn't write the code myself. I described what I wanted, Claude Code built and tested it, and I gave feedback like "cuter", "calmer", "bigger". Even the character started as rough sketches in the chat.

What I learned
- A character changes everything. The first version was a plain status display and nobody cared. Nosy made people smile.
- Free and local is the strongest argument. Most notch apps cost money; being free and open source is what gets people to try it.
- Let the AI test for real. The best fixes came when Claude Code tried things in real sessions instead of assuming.
- Keep a worklog. I use several Claude accounts, so a short WORKLOG.md keeps every session in sync.

It's free and MIT licensed. Install: npx nosynotch

https://github.com/ddkbs/nosynotch
https://nosynotch.davidkubus.dev

Feel free to try it out and leave your feedback!
```

### r/tamagotchi
**Media:** `nosy.mp4` / `level-up.mp4` (Nosy close-up) · ⚠ check the sidebar first: if self-promotion isn't allowed, skip it or ask the mods

**Title**
```
I made a little tamagotchi that lives in my MacBook notch and grows when my work gets done
```

**Text**
```
Disclosure: I made this, and it's free.

Nosy is a tiny creature that lives in the notch at the top of a MacBook screen. Instead of feeding him by hand, he gets energy every time my AI coding tools finish a task. He levels up, keeps a daily streak and reacts to what's happening: he concentrates while work is running, waves when something needs me, cheers when it's done and falls asleep when nothing happens.

The one rule I gave him: he never dies and never makes you feel guilty. Worst case, he's a bit sleepy.

Honest note: he's made for people who code with AI tools (Claude Code, Codex, Cursor) on a Mac, that's what feeds him. I'd love to hear from real tamagotchi fans what would make him feel more alive.

https://github.com/ddkbs/nosynotch
https://nosynotch.davidkubus.dev

Feel free to try it out and leave your feedback!
```

### r/virtualpets
**Media:** `nosy.mp4` (dive into the notch) · ⚠ check the sidebar first

**Title**
```
Meet Nosy, a virtual pet that lives in a MacBook notch and dives into it like a puddle
```

**Text**
```
Disclosure: I'm the one who made him. He's free.

Nosy lives in the black notch at the top of a MacBook screen. When the notch closes, he hops in like he's jumping into a tar puddle and just his eyes peek out, following your cursor. When something happens, he drips back out.

He has moods (focused, waving, cheering, sleepy, dizzy), energy, levels, a daily streak and little things to unlock. And he never dies and never guilt-trips you.

He gets his energy from finished tasks of AI coding tools, so he's mostly for people who code on a Mac. What would you want a pet like this to do?

https://github.com/ddkbs/nosynotch
https://nosynotch.davidkubus.dev

Feel free to try it out and leave your feedback!
```

## 4. First comment of your own (post right after every post)

```
Some details for the curious:
- Install: npx nosynotch (downloads the app to ~/.nosynotch, connects Claude Code / Codex / Cursor if present, starts it). npx nosynotch uninstall removes everything.
- Privacy: hooks talk to 127.0.0.1 only; nothing is uploaded. Calendar, AirPods, head gestures, live equalizer and replying from the notch are off until you turn them on.
- Nosy's energy and streak are stored locally. He never dies – I wanted the cozy part of a tamagotchi without the guilt.
- Not signed with an Apple Developer ID yet (ad-hoc signed), so macOS may ask once.
Repo + every animation explained: https://github.com/ddkbs/nosynotch
Website: https://nosynotch.davidkubus.dev

Feel free to try it out and leave your feedback!
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

## 7. Automation: Claude posts, you only confirm

Goal: you hardly have to do anything. Proposed setup, ready to set up as soon as v0.3 is out:

1. **One scheduled Claude task per posting day** (Claude Desktop "scheduled tasks", 2 pm German time, following the plan in section 2). It uses **Claude in Chrome** with your logged-in Reddit account:
   - opens the subreddit, reads the current sidebar rules (karma, flair, megathread) and skips the sub if the post would break them,
   - fills in title, text, flair and the clip from `website/public/demo/` / `docs/gifs/`,
   - **stops before "Post" and asks you once** (also works from your phone). You reply "yes", and it posts the thread plus the first comment of your own (section 4).
2. **Check-ins after 1 h and 24 h:** Claude reads the new comments, writes reply drafts in your style (ending with "Feel free to try it out and leave your feedback!" where it fits), and posts them after your OK. Bug reports go straight into a list for the main session.
3. **Logbook** in `promo/POSTED.md`: sub, time, link, upvotes, comments, stars before/after.

**Why not fully without you:**
- Reddit only allows bots with an approved API app.
- Most subs remove self-promotion posted automatically, and the account can get banned.
- Claude may only publish something in your name with your explicit OK for each post.

One "yes" per post is the minimum. Everything else (filling in, timing, uploading, logbook, reply drafts) runs automatically.

## 6. Beyond Reddit (short)

- **Korben.info:** wrote about both boring.notch and Notchi. Short email with `nosy-hero.mp4` + 3 sentences + link, right after the release.
- **Show HN:** `Show HN: Nosy Notch – a tiny helper in the MacBook notch that watches your coding agents`, Tue–Thu 8–10 am ET.
- **HelloGitHub, Product Hunt** in week 2. Product Hunt with a Nosy gallery and the first comment as the maker story.
