# WORKLOG

## 2026-11-05
- Projekt angelegt (leerer Ordner, git init).
- Ziel: macOS-Notch-App, die den Live-Zustand von Claude Code animiert anzeigt und bei „fertig“ / „braucht dich“ benachrichtigt.
- Entscheidung: **Hooks statt MCP**. MCP ist pull-basiert (Claude ruft Tools auf), Hooks feuern bei jedem Lifecycle-Event. Hooks `curl`en das JSON an einen lokalen HTTP-Server in der App (127.0.0.1:7823).
- Stack: Swift Package (macOS 14+), AppKit-`NSPanel` über der Notch + SwiftUI für die Animationen, Network.framework für den Server.
- v0.1 implementiert: Zustände (denkt / Tool / braucht dich / komprimiert / fertig), Hover-Liste mit mehreren Sessions, Konfetti + Häkchen bei Fertig, Shake + Glow bei Rückfrage, Sounds, optionale macOS-Mitteilungen, Klick → Terminal aktivieren, Hook-Installer (Menü + `--install-hooks`), Demo-Modus.
- Offen: Auf echtem Mac bauen und testen (in der Cloud-Session gab es keinen Swift-Compiler), Feintuning von Notch-Radien / Timings, ggf. App-Icon, Autostart-Option, Kontext-/Token-Anzeige.
- Umbau auf **`npx claude-notch`** (kein App-Download/kein Apple-Developer-Account): Node-CLI ohne Dependencies lädt eine ad-hoc-signierte Universal-Binary aus GitHub Releases nach `~/.claude-notch/` (Fallback: lokal mit `swift build`), trägt Hooks ein, startet den Helfer, optional Autostart per LaunchAgent. Neuer Server-Endpoint `POST /quit` für `stop`.
- GitHub Actions (macOS-Runner): baut Universal-Binary, Smoke-Test, Release bei Tag `v*`, npm publish wenn `NPM_TOKEN` gesetzt.
