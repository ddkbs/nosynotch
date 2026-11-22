# Compact animation CPU audit

## Final changes

- Pulse a static native symbol layer with Core Animation instead of rebuilding the SwiftUI symbol for each opacity frame. Virtual-clock recordings retain the original deterministic SwiftUI implementation. Paused settings stop the native pulse.
- Use lower-rate periodic updates for moving wing eyes (12 Hz, 8 Hz asleep) and thinking dots (15 Hz). Calm eye moods still update only at blink boundaries.
- Keep the compact clock colon steady and update at wall-clock minute boundaries or a meeting's countdown boundaries. The expanded clock retains its animated colon.
- Add a browser-blocked, loopback `GET /diagnostics` report with aggregate session counts and each display's presentation, mood and hover state. No identifiers, commands, paths or conversation text are included. `scripts/measure-idle.py --diagnostics-url http://127.0.0.1:7823/diagnostics` records state before and after a CPU sample.

## Comparison with upstream

Compared upstream `ad5f0be` with `3ad7ed3` on macOS 27.2.1 using the built-in Retina display. Both were arm64 release builds compiled with the macOS 26.5 SDK. Each build ran twice in alternating pair order, with 40 seconds per scenario per run. The active tool was simulated using app events.

| Scenario | Upstream mean | With changes | Difference |
| --- | ---: | ---: | ---: |
| Idle clock, no sessions | 0.124% | 0.027% | −0.097 percentage points |
| Compact notch, active tool | 0.107% | 0.027% | −0.080 percentage points |

The averages measure Nosy Notch process CPU as a share of one core. In the active-tool scenario, the highest one-second sample was 0.160% upstream and 0.186% with the changes. The comparison covers one display and two UI states. WindowServer, GPU and energy use were outside the measurement.
