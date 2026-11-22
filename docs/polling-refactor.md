# Event-based scheduling

The service-level repeating timers have been removed. `Deadline` owns one replaceable, cancellable one-shot timer, uses the existing virtual clock in tests/recording, and reevaluates rules on system wake, clock changes and time-zone changes. Actual timer invalidation removes superseded real deadlines rather than leaving a queue of cancelled delayed blocks.

| Area | Replacement |
| --- | --- |
| Sessions | Next reminder or expiry, recalculated on session/preference changes. No deadline when the store is empty. |
| Usage resets | Next eligible, unnotified reset. No deadline with notices disabled or no eligible limits. |
| Focus | One completion deadline. Countdown updates belong to mounted views. |
| Sleep | Inactivity deadline and next day/night threshold; reevaluated on activity changes. No sleep deadline while busy or Nosy disabled. |
| Energy | Derived from elapsed time; committed on feeding/load/persistence. No periodic defaults writes. Visible card updates once a minute. |
| Calendar | EventKit change notifications plus next reminder, meeting end, or query-horizon renewal. No 30-second full query. The bounded query horizon is still renewed after 12 hours when enabled. |
| Chat | File and parent-directory dispatch sources; append, replacement and recreation are coalesced for 50 ms. Unrelated directory changes do not read the transcript. Closing cancels sources, and generation checks reject stale background reads. Path/summary changes are handled through session events. The parent directory must exist for initial observation. |
| Mouse | Global and local AppKit events replace the hover timer. Hidden eyes do not publish gaze; entry hit testing remains active. Shelf-disabled mouse-down skips pasteboard reads. |
| Audio | Capture follows the displayed live equalizer and active playback; pause/hidden equalizer detaches it. Unchanged targets do not enqueue audio work. |
| Settings | Cosmetic timelines pause when occluded/minimized/app-hidden and are destroyed on close. |

Visible clocks and animations still update periodically by design. One-shot timeouts used for transitions, reply actions, permissions, mute expiry, retry and batching remain. Those do not run continuously at idle.

Validation: The Swift regression suite runs via `./scripts/test.sh`; macOS release packaging also succeeds with the installed 26.5 SDK. The original characterization tests remain, with an explicit activity-stop observation added to the sleep fixture to model the real app's event callback. New tests cover automatic scheduling/cancellation, clock invalidation, actual filesystem observation, and chat close/reopen lifecycle.

The manual checklist in `testing-before-polling-refactor.md` still applies. Unit/integration tests do not establish transparent-panel mouse delivery, actual system sleep/resume, EventKit permission behavior, occluded-window rendering or Core Audio hardware behavior. CPU measurements are observations, not absolute pass/fail guarantees.
