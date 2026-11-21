# Compact animation CPU audit — 2026-11-17

The user reported roughly 5% CPU with only the wing eyes visible (and occasional 12% readings). Measurements were taken on macOS 27.2.1 with one external PA32QCV display. Early samples were not reliable idle comparisons: this coding session's hooks created working/waiting states, and some samples included expanded permission cards.

## Final changes

- Pulse a static native symbol layer with Core Animation instead of rebuilding the SwiftUI symbol for each opacity frame. Virtual-clock recordings retain the original deterministic SwiftUI implementation. Paused settings stop the native pulse.
- Use lower-rate periodic updates for moving wing eyes (12 Hz, 8 Hz asleep) and thinking dots (15 Hz). Calm eye moods still update only at blink boundaries.
- Keep the compact clock colon steady and update at wall-clock minute boundaries or a meeting's countdown boundaries. The expanded clock retains its animated colon.
- Add a browser-blocked, loopback `GET /diagnostics` report with aggregate session counts and each display's presentation, mood and hover state. No identifiers, commands, paths or conversation text are included. `scripts/measure-idle.py --diagnostics-url http://127.0.0.1:7823/diagnostics` records state before and after a CPU sample.

## Measurements from the original development branch

These samples were captured before extracting the CPU changes onto a branch based on upstream. A matched comparison of this branch against upstream is pending.

- Verified idle clock, no sessions and no hover: **0.217% mean, 0.5% maximum** over six samples, initial sample discarded (`build/diagnostics/final-after.json` and `final-after-state.json`).
- Periodic SwiftUI pulse with one synthetic active tool and no hover: **3.267% mean, 3.8% maximum** (`final-periodic-tool.json`).
- Native pulse with one synthetic active tool and no hover: **0.083% mean, 0.3% maximum** (`final-layer-pulse-tool.json`). The earlier eye mood was `typing`; the final turn had aged into `sweating`. Both use the same pulsing tool indicator and blink-only wing eye scheduling. These short runs are indicative, not a universal performance threshold or a strictly identical full-state A/B test.
- The synthetic session sent UI events only, executed no commands and was removed after each measurement.
- Header-only captures verified that the native symbol remains visible and changes opacity. CPU behavior with two simultaneously connected displays remains to be measured.
