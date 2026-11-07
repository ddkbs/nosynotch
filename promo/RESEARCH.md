# Promo research: what works, and what that means for Nosy Notch

Last updated 2026-11-07. Sources are listed at the bottom. Subreddit rules change often, so check each sidebar before posting.

## 1. sketchy (our own reference)

- **Numbers:** 230 ★ and 19 forks, a month after the repo went up. Almost all the stars came in **five days after launch**: 67 / 58 / 57 / 32 / 16 stars from 2–6 Nov. The burst came from the launch push (posts plus creator outreach list in `sketchy-sonstiges/sketchy-outreach`). After that the star count levelled off.
- **README recipe:**
  1. A one-sentence promise naming what it does and where: "lets your AI assistant **draw while it explains** … in the Claude chat … Claude Code, Codex, Cursor".
  2. The mechanism as a crisp contrast: "The AI decides **what** to draw. Sketchy decides **where**." People repeat this line, and it is also the GitHub description.
  3. The first image shows it **in real use** (inside a real chat), not a logo. The commit "lead the README with Sketchy in a real chat" was deliberate.
  4. "What it can draw": a short heading, 1–2 sentences and one big image per capability, each with a concrete example prompt ("Ask *'Explain my repo'*").
  5. Install is split by **where you work**, not by technology.
- **Lesson:** sell one clear hook, and show it in context. The first image has to be self-explanatory without any text.
- **Lesson:** the curve drops off after about 4 days, so a launch needs a second wave (a new feature, a new channel, outreach).

## 2. Comparable projects

| Project | ★ | Pitch | What made it work |
|---|---|---|---|
| **boring.notch** | 11.3k | "Not so boring notch That Rocks" | Free and open-source alternative to paid NotchNook ($25). Covers the whole notch utility set (music, shelf + AirDrop, calendar, camera mirror, battery). Picked up by Korben, Product Hunt, Peerlist. |
| **Notchi** | 1.0k (since Jan 2026) | "a tamagotchi that lives in your Mac notch and emotionally reacts to your Claude Code sessions" | **A mascot / tamagotchi** as the hook, a video right at the top of the README, a DMG download button. Korben wrote about it in 5 languages, plus HN and HelloGitHub. Its features are thin (read-only, no approvals). |
| **Buddi** | 93 | "your buddy lives here now" | Origin story: Anthropic quietly removed `/buddy` from Claude Code, so Buddi brought it back. ASCII buddy, approvals, chat with sessions. |
| **Claude Island / Open Island** | – | free notch app for Claude Code | Approvals from the notch, simple. |
| **Vibe Island** | paid | 30 agents, two-way | Polish and coverage, but costs money. |
| **Claude Pet, Mac Pet, VibePet, Notchling** | small | pixel pets | All pixel cats or dogs. None has its own character design. |

**Key insight:** the "tamagotchi in the notch" idea is **proven** (Notchi gets 1k stars on a cute character alone). The "full notch utility for free" idea is **proven** (boring.notch gets 11k). **Nobody combines both** with real agent features (approvals, chat, limits). That is Nosy Notch's position from v0.3 on:

> boring.notch's utility + Notchi's charm + an actual agent cockpit, in one free app.

Always phrase this comparison politely and only in comments (e.g. "I love boring.notch, I wanted the agent side too"). Never claim "the only one" in a title.

## 3. What gets upvotes on Reddit (patterns from the research and our earlier posts)

1. **The video does the talking.** Post type "Images & Video": upload the MP4 directly, with the text below. The first second decides whether people scroll past. For v0.3 the first second is **Nosy jumping into the notch** (the tar splash).
2. **Title = a personal "I"-story with a concrete result.** Good: "I gave my MacBook notch a tiny helper who…". Bad: "Nosy Notch v0.3 – feature list". No marketing words ("revolutionary", "ultimate"), no emoji walls.
3. **Story before features:** the problem (agents wait silently, I miss it), then the solution, then 4–6 bullets, then the install line. Keep it under ~250 words.
4. **Disclose that you're the developer**, and in Claude subs say how Claude helped (r/ClaudeAI Rule 7).
5. **The first hour counts:** answer every comment quickly and personally. Prepare a first comment of your own with technical details and the GitHub link (some subs push link posts down).
6. **No cross-post flood:** 3–4 subs per day at most, each post with its own text. Copying the same text into 20 subs looks like spam (risk of a shadowban).
7. **Make one sub-specific detail the focus:** Mac subs care about music, shelf and calendar; Claude subs about hooks, approvals and the limit reset; Swift subs about how it's built.
8. **Ask a question at the end** ("what should Nosy unlock at level 10?"). That drives comments, and comments drive reach.
9. **Free + open source + local** belongs in the first lines. That's the biggest trust argument against the paid notch apps.

## 4. Subreddit rules (as of research, verify before posting)

| Sub | Self-promo | Requirements / notes |
|---|---|---|
| r/ClaudeAI | yes, "Built with Claude" showcase (Rule 7) | **> 100 karma** for a feed post (raised from 50), otherwise the "Built with Claude Project Showcase Megathread". Say that you built it, how Claude helped, and that it's free to try. New accounts are blocked for ~3 days. |
| r/ClaudeCode | yes | Project / Showcase flair. Technical depth is welcome. |
| r/macapps | yes, strictly regulated | Disclose that you're the dev. **1 dev post per 30 days** (trusted devs: 1 per app), otherwise the monthly megathread ("The App Pile"). 10 r/macapps karma to self-promote in comments. Title "AppName — short descriptor". Include pricing, privacy and OS requirements. Ask the mods via modmail first if unsure. |
| r/MacOS | unclear (relaxed in Dec 2025) | Read the sidebar. Use an "Apps" flair if there is one. No duplicates within a week. |
| r/SideProject | yes | A gallery or video works well. Builder tone ("stack", "what I learned"). |
| r/opensource | yes for OSS | Name the license (MIT). Technical, no sales talk. |
| r/cursor | yes | Showcase / Resources flair. Lax with new accounts. |
| r/codex, r/ChatGPTCoding | mostly yes | Check the sidebar. |
| r/OpenAI | strict | Only in the weekly / project thread. |
| r/vibecoding | yes | Casual and fun. "Built with Claude Code" is a plus there. |
| r/coolgithubprojects | link posts | Link the GitHub repo, put the GIF in a comment. |
| r/swift, r/SwiftUI | only technical | A plain launch post gets removed. A "how I built X" post with code details works. |

## 5. Channels beyond Reddit

- **Korben.info** covered both boring.notch and Notchi, in several languages. That makes it target #1 for a short email with the video once v0.3 is out.
- **Show HN:** "Show HN: Nosy Notch – a tiny helper in the MacBook notch that watches your coding agents". Tuesday–Thursday, 8–10 am ET. Answer in the thread for the first 2 hours.
- **HelloGitHub** (picked up Notchi), **Product Hunt** (boring.notch, Buddi, Notchling were all there).
- **X/Bluesky:** a 15 s clip of the dive morph with `#ClaudeCode`, tagging the Claude Code team only if it fits.
- **Second wave:** each new feature (e.g. Nosy accessories, more agents) is a new occasion for a post in 2–3 weeks.

## Sources

- [boring.notch on GitHub](https://github.com/TheBoredTeam/boring.notch), [Korben on boring.notch](https://korben.info/en/boring-notch-macbook-notch-finally-useful.html), [Product Hunt boring.notch](https://www.producthunt.com/products/theboringnotch/launches)
- [Notchi on GitHub](https://github.com/sk-ruban/notchi), [Korben on Notchi](https://korben.info/en/notchi-pixel-art-mascot-macbook-notch-claude-code.html), [HelloGitHub Notchi](https://hellogithub.com/en/repository/sk-ruban/notchi)
- [Buddi on GitHub](https://github.com/talkvalue/Buddi), [Buddi on Product Hunt](https://www.producthunt.com/p/buddi-living-in-the-notch/buddi-2)
- [Vibe Island comparison (vendor page)](https://vibeisland.app/alternatives/)
- [r/macapps rules summary (Thread Otter)](https://www.threadotter.com/subreddit-rules/macapps)
- [r/ClaudeAI Built-with-Claude megathread (mirror)](https://redlib.groet-infra.nl/r/ClaudeAI/comments/1sly3jm/built_with_claude_project_showcase_megathread/oq1cg2n/?context=3)
- [r/MacOS snapshot, "New Rules for App Self Promotion"](https://reddit.sentinel-team.org/subreddits/MacOS/snapshots/2025-12-06T05%3A42%3A12.870909Z)
- [Infisical: 3000 stars in 2 months](https://infisical.com/blog/how-we-got-3000-github-stars-in-2-months), [Launch on Reddit guide](https://launchkit-5du.pages.dev/launch/open-source-project/)
- sketchy star history: `gh api repos/ddkbs/sketchy/stargazers` (starred_at per day)
