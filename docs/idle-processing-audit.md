# Hidden-notch processing audit

Historical scope: local working tree before the event-based refactor (see `polling-refactor.md` for the implementation), with `presentation == .hidden` (collapsed notch), rather than app termination. This is a source audit, informed by the recent CPU samples. A code path being eligible to run does not establish that it explains a particular measured CPU spike. No performance fix is included in this audit.

## Findings

| Priority | Work | Evidence / condition | Proposed change |
| --- | --- | --- | --- |
| High | Invisible eye tracking on global mouse movement | `NotchWindowController.updateHover` calls `model.updateGaze` before hit testing. `updateGaze` always calculates and publishes gaze when Nosy is enabled, even with no eyes mounted. | Keep cheap entry hit testing; calculate gaze only when eyes/body are visible or on entry. Refresh gaze on reveal. |
| High, conditional | Audio capture and FFT after pause | `updateSpectrum` retains `tappedPlayer` when a track is paused. `AudioSpectrum.follow` therefore retains the existing process tap. With `mediaShowWhenPaused == false`, the notch can be hidden while the tap remains attached. FFT analysis is performed before the later signal checks. | Stop the tap whenever there is no visible live equalizer or playback is paused. Reattach when needed. A retained tap's actual callbacks depend on Core Audio/player behavior. |
| Medium | Repeated full calendar queries | `CalendarMonitor` queries EventKit for a 12-hour range, sorts events, and maps the next meeting every 30 seconds, on the main actor. The calendar must still announce upcoming meetings while hidden. | Cache meeting data; invalidate on EventKit changes and refresh on horizon/time changes. Schedule the next meeting/reminder boundary instead of repeatedly querying all events. |
| Medium | Pasteboard reads with file shelf disabled | Global mouse-down/up observer is always installed. `mouseButton(down: true)` reads the drag pasteboard change count without checking `shelfEnabled`; only `updateFileDrag` checks it later. | Skip pasteboard work when the shelf is disabled, while preserving drag-completion cleanup. File-drag detection itself must remain available while hidden when shelf is enabled. |
| Medium | Empty session maintenance | `SessionStore` runs `sweep` and `remind` every 15 seconds even with no sessions; sweeps remain needed when sessions exist. | Stop maintenance when empty; restart on first event. Later schedule individual expiry/reminder deadlines. |
| Medium | Reset checks without eligible limits | `UsageStore` wakes every 20 seconds even with reset notices disabled or no eligible reset window. | Schedule only the next unnotified reset for a window at or above 80%, preserving startup/late-reset behavior. Recalculate on fresh usage or preference changes. |
| Low | Sleep-state polling when Nosy is disabled / already asleep | `NotchViewModel` checks activity and calendar hour every 15 seconds irrespective of `nosyEnabled`, visibility or sleep state. Sleep state is relevant when Nosy is revealed, so merely stopping all hidden updates would be incorrect. | Use an activity-based sleep deadline; update on reveal and day/night threshold changes. Avoid polling when Nosy is disabled. |
| Low | Energy decay publication and persistence while invisible | `NosyPet` changes published state and writes defaults every five minutes, including when energy is already at its floor. | Calculate decay lazily before energy-dependent decisions, feeding, reveal and persistence. Preserve elapsed-time accounting and streak rules. Avoid publishing unchanged energy. |
| Medium, event-driven | Duplicate media publications and visual preparation | `NowPlaying.apply` assigns track/playback values and calls `onChange` for notifications even if values are unchanged. Artwork loading and average-color processing happen on track changes even with media disabled or a paused track hidden. | Suppress equal assignments, separate metadata/playback state from visual assets, and load artwork only on visual demand. Keep playback notifications needed to reveal the media notch. |
| Low, event-driven | Repeated audio-queue submissions | Every `recompute` calls `updateSpectrum`, which calls `spectrum.follow`; its unchanged-player guard is inside `queue.async`, so even identical targets enqueue work. | Deduplicate target changes before queue submission, with state kept consistent when the tap fails/stops. |
| Low, event-driven | Hidden root-view invalidation | `NotchView` observes the entire session store, model and media objects. Session/context/media changes can evaluate layout, shape and header code even while hidden. `usage.onChange` explicitly sends model invalidation. | Separate hidden entry geometry from visible content and subscribe visible subviews narrowly. Retain the state transitions that reveal the notch. |
| Conditional; needs runtime verification | Settings minimized or app hidden with Settings open | The local close fix tears down Settings only on `windowWillClose`. Minimizing or hiding leaves its view hierarchy, including animation timelines, retained. | Pause cosmetic timelines on actual window visibility/miniaturization/app hiding, while preserving window state. This is distinct from simply collapsing the notch. |

## Work already addressed locally

- Finished splash timeline is removed after its final frame (`NotchView.splashAt`).
- Closing Settings destroys its hosting hierarchy (`SettingsWindowController.windowWillClose`).
- Menu icon no longer polls/reassigns its image every 30 seconds; a one-shot timer handles timed mute expiry.
- Maintenance timers have tolerance so macOS can coalesce wakeups. This does not stop the timers.

## Paths that should remain available

- HTTP hook listener, session state, permissions and notifications: hidden is normal while waiting for agent work.
- Minimal pointer entry detection and file-drop detection when enabled.
- Calendar change notifications and upcoming meeting deadlines.
- Media playback notifications needed to reveal the player; no periodic AppleScript polling loop was found.
- Power/Bluetooth notifications, which are event-driven and may reveal notices.
- Mute expiry and focus completion deadlines.
- Session reminders, expiry and limit-reset notifications when data is eligible.

## Paths already gated

- Head motion tracking is active only for a displayed permission request with the feature enabled.
- Hover polling at 80 ms stops when the pointer exits.
- Chat polling at 1.5 seconds is invalidated by `closeChat`; a valid open chat selects `.chat`, so it cannot coexist with `.hidden` through the normal presentation selection.
- Focus ticking starts only with a running timer; that timer normally selects visible `.timer` presentation, not `.hidden`.
- Main notch animation views are mounted conditionally by presentation. In the hidden path, eye/spark/equalizer timelines are not mounted; the bounded closing splash is the deliberate transition exception.
- Codex usage files are read at startup and selected hook events, not by an idle polling timer. Claude usage forwarding is driven by Claude's status-line updates.
- Shelf filesystem pruning runs on shelf appearance, not periodically.

## Validation plan

Measure hidden/stationary, hidden/moving pointer, visible/expanded, closing transition, paused media with hidden paused-player UI, and minimized Settings separately. Exclude startup and distinguish average CPU from periodic spikes. Verify reveal latency, file drag/drop, mute expiry, calendar alerts, session reminders, limit resets, energy decay, and live audio resume before accepting optimizations.
