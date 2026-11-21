# Regression baseline before removing polling

## Automated tests

Requires Swift 6+ (Swift Testing). Run:

```sh
./scripts/test.sh
```

The runner selects an installed macOS 26.5 SDK for standalone Command Line Tools unless `SDKROOT` is already set, and explicitly loads the bundled Testing macro plugin to support incremental builds. Full Xcode keeps its default SDK.

A restricted execution environment may also need writable compiler caches and `--disable-sandbox`; these are execution-environment options, not application requirements.

`BehaviorTests` is serialized because it uses the existing process-wide virtual `Clock`. Each case resets the virtual clock and uses isolated UserDefaults suites where persistence is exercised. Test constructors can disable real timers. System media observation is disabled, and calendar tests supply snapshots rather than requesting calendar access. No hooks are installed and no real user preference values are modified.

The tests characterize:

- Ordered, nested and cancelled virtual-clock work.
- Finished/waiting reminders: 5-minute boundary, deduplication, seen/dismissed/ended sessions, renewed activity and preference changes.
- Thinking/compaction/tool timeout thresholds, refreshed activity, and different expiry ages for seen/unseen results.
- Limit reset threshold of 80%, exact reset time, duplicate prevention across reload, 12-hour late-notice cutoff, preference changes and replacing old usage with fresh data.
- Focus completion after a long observation gap, single completion, cancellation and restart.
- Energy decay, floor, backward wall-clock movement, feeding, isolated persistence/offline time, daily counters and streaks.
- Calendar selection, 10-minute notification threshold, duplicate suppression, deletion, rescheduling, expired notice windows and unchanged snapshots.
- Day/night sleep thresholds, activity keeping Nosy awake, pointer entry/exit, hover presentation and edge hysteresis.
- Claude and Codex transcript reading using real temporary files, including partial writes, appends, atomic replacement, deletion, metadata exclusion and assistant-block merging.

Limits of the original characterization cases: session maintenance, focus ticks and sleep checks are explicitly invoked after advancing time; transcript readers are called after file mutations. Those cases alone do not establish automatic adapter behavior. The additional adapter tests below now cover scheduling and file observation. Cursor cases still exercise model geometry/presentation rather than AppKit's transparent-panel event delivery.

The baseline preparation introduced timer opt-outs, access to one maintenance pass, isolated persistence, notification-preference closures and calendar snapshot evaluation. These original characterization cases remain in the suite after the event-based refactor.

## Adapter tests added with the refactor

The suite now also verifies automatic session reminders/expiry, limit resets and preference cancellation, focus completion/cancellation, calendar boundaries/stop, automatic sleep/wake on hover, and deadline replacement/cancellation/time-zone invalidation.

Chat lifecycle integration verifies file updates, cancellation after closing, and reading the latest transcript on reopening.

Real filesystem observer tests cover append, atomic replacement, deletion, recreation, initially missing files, cancellation and unrelated parent-directory changes. They use real temporary files and bounded asynchronous waits, not a polling implementation.

Remaining integration checks: actual system sleep/resume and wall-clock changes, EventKit permissions/change delivery and event filtering, transparent-panel pointer delivery, settings occlusion, and Core Audio tap stop/resume. These are not marked passed by the rule tests.

## Manual macOS regression matrix

Run against the baseline build and again after the refactor. Record actual result for each; these checks have not been marked passed merely because unit tests pass.

| Scenario | Expected |
| --- | --- |
| Hidden, pointer still | Settles to near-zero CPU; no continuous cosmetic animation. |
| Hidden, pointer moving away from notch | Remains hidden; entry detection remains responsive. Compare CPU separately from stationary scenario. |
| Pointer crosses all notch edges, including a fast pass | Opens/closes reliably; small exit margin prevents edge flicker. |
| Expand, then leave | Closing animation completes, then settles. No permanent splash timeline. |
| File dragged from Finder to/from notch | Shelf opens, drop and exit work; no stuck drag state. Repeat with shelf disabled. |
| Settings open, closed, minimized, app hidden | Visible previews animate. Closed previews stop. Record baseline behavior for minimized/hidden settings, which is an optimization target. |
| Music playing, paused, stopped, resumed | Correct player display; live equalizer and controls recover. Test paused-player display both on and off. |
| Chat open, updating, closed and reopened | New messages appear without duplicates; replacing transcript still works; closing stops observation after the refactor. |
| Focus timer / mute expiry with notch collapsed | Correct one-time completion and icon restoration. |
| Suspend/resume across reminder or reset deadline | Correct pending notifications without duplicates. |
| Calendar event added, rescheduled, cancelled | Correct upcoming meeting and alert; requires a real permission-enabled calendar test. |

## CPU capture

Run each scenario separately with a settled running app. Do not use active agent tasks as a controlled idle workload. Stop moving the pointer for the stationary scenario. The script records observations and never asserts an exact CPU percentage:

```sh
python3 scripts/measure-idle.py --scenario hidden-stationary --output /tmp/nosy-before-hidden.json
# Repeat after the refactor, with the same settings/workload:
python3 scripts/measure-idle.py --scenario hidden-stationary --output /tmp/nosy-after-hidden.json
```

Default capture is 30 seconds, discarding top's first sample. JSON includes all interval CPU samples and the mean/max; raw top output is saved beside it. The scenario label is supplied by the operator, not detected automatically. Repeat multiple captures before attributing small differences to a code change. This records CPU, not wakeups; wakeup and audio-capture claims need profiling separately.
