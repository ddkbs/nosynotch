# claude-notch ✦

Live-Status von **Claude Code** direkt in der MacBook-Notch – mit Animationen.

| Zustand | Notch |
|---|---|
| **Denkt nach** | Notch fährt seitlich aus, das Spark-Logo rotiert, Strahlen pulsieren als Welle, rechts tanzen drei Punkte |
| **Tool läuft** | Spark dreht schneller, rechts das Tool-Icon (Terminal, Stift, Lupe, Globus …) mit Puls |
| **Braucht dich** (Permission/Rückfrage) | Notch klappt auf, oranges Glühen, Shake, winkende Hand + Nachricht, Sound |
| **Komprimiert** | violetter, sich zusammenziehender Spark |
| **Fertig** | Notch klappt auf, Häkchen zeichnet sich, Konfetti-Burst, Projekt + Dauer + Zusammenfassung der letzten Antwort, Sound |
| **Hover** | Liste aller laufenden Sessions mit Status, aktuellem Tool und Timer. Klick → springt ins richtige Terminal |

Funktioniert mit mehreren parallelen Sessions. Auf Macs ohne Notch hängt eine „virtuelle“ Notch mittig an der Menüleiste.

## Wie es funktioniert

```
Claude Code ──hook (curl, ~15 ms)──▶ 127.0.0.1:7823/event ──▶ ClaudeNotch.app (SwiftUI-Panel über der Notch)
```

Kein MCP-Server nötig: Ein MCP-Server wird nur aufgerufen, wenn *Claude* sich entscheidet, ein Tool zu benutzen. Für einen Live-Status braucht man aber jedes Lifecycle-Event. Genau dafür gibt es **Claude Code Hooks**
(`UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Notification`, `Stop`, `SessionStart/End`, `PreCompact`, `SubagentStop`).
Jeder Hook ist ein einzeiliges `curl`, das das Hook-JSON an die App schickt. Läuft die App nicht, schlägt `curl` sofort fehl,
`|| true` sorgt dafür, dass Claude Code davon nie blockiert wird.

## Installation

```bash
npx claude-notch
```

Das war's. Der Befehl
1. lädt die fertige Binary von GitHub Releases nach `~/.claude-notch/` (gibt es kein Release, kompiliert er sie lokal mit Swift),
2. trägt die Hooks in `~/.claude/settings.json` ein (vorher wird `settings.json.claude-notch.bak` angelegt),
3. startet den Notch-Helfer im Hintergrund (ohne Dock-Icon, nur ein ✦ in der Menüleiste).

**Kein Apple-Developer-Account, kein App Store, kein Xcode-Projekt.** Die Binary ist ad-hoc signiert. Dateien, die über Node/curl
geladen werden, bekommen kein Quarantäne-Flag, deshalb meckert Gatekeeper nicht.

Bereits laufende Claude-Code-Sessions einmal neu starten, damit sie die Hooks laden.

```bash
npx claude-notch demo        # alle Animationen vorführen
npx claude-notch autostart   # beim Login starten (autostart off)
npx claude-notch status
npx claude-notch stop
npx claude-notch uninstall   # entfernt App, Hooks und Autostart
```

Global installieren geht auch: `npm i -g claude-notch`, danach einfach `claude-notch`.

### Aus dem Quellcode

Voraussetzung: macOS 14+ und die kostenlosen Xcode Command Line Tools (`xcode-select --install`).

```bash
swift run
```

oder als `.app`: `./scripts/build-app.sh --open`.

<details>
<summary>Hooks manuell eintragen</summary>

Für jedes Event (`SessionStart`, `SessionEnd`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Notification`, `Stop`, `SubagentStop`, `PreCompact`):

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
            "command": "curl -s -m 2 -X POST -H 'Content-Type: application/json' -H 'Expect:' -H \"X-Term-Program: ${TERM_PROGRAM:-}\" -H \"X-Bundle-Id: ${__CFBundleIdentifier:-}\" --data-binary @- 'http://127.0.0.1:7823/event?src=claude-notch' >/dev/null 2>&1 || true"
          }
        ]
      }
    ]
  }
}
```
`matcher` braucht es nur bei `PreToolUse`/`PostToolUse`.
</details>

## Einstellungen (Menüleiste ✦)

- **Sound bei Fertig / Rückfrage**: an (Glass / Funk)
- **macOS-Mitteilungen**: aus (die Notch ist ja die Benachrichtigung). Funktioniert nur aus der gebauten `.app`, nicht per `swift run`.

## Entwicklung

`swift run` startet ohne App-Bundle, also ohne macOS-Mitteilungen. Alles andere funktioniert.

Releases: Version in `package.json` hochzählen, Tag `vX.Y.Z` pushen. GitHub Actions baut die Universal-Binary (arm64 + x86_64),
hängt sie ans Release und veröffentlicht auf npm, falls das Secret `NPM_TOKEN` gesetzt ist.

```
bin/claude-notch.js                  npx-CLI (Download, Hooks, Start/Stop, Autostart)
Sources/ClaudeNotch/
├── main.swift / AppDelegate.swift   App-Lifecycle, Menüleisten-Item, CLI-Flags
├── EventServer.swift                Mini-HTTP-Server (Network.framework, nur Loopback)
├── HookEvent.swift                  Hook-JSON → Event
├── SessionStore.swift               Event-Stream → Zustand pro Session
├── Session.swift                    Zustände, Tool-Icons/Labels, Farben
├── Transcript.swift                 liest die letzte Antwort aus dem Transcript (für „Fertig“)
├── HookInstaller.swift              ~/.claude/settings.json patchen
├── Notifier.swift                   Sounds, Mitteilungen, Terminal aktivieren
├── NotchViewModel.swift             Präsentation (hidden/compact/expanded/celebrating/attention) + Größen
├── NotchWindow.swift                transparentes NSPanel über der Notch, Hover ohne Klicks zu klauen
├── Demo.swift                       Demo-Ablauf
└── Views/                           NotchShape, ClaudeSpark, Indikatoren, Konfetti, Häkchen …
```

Hinweis: Bricht man einen Turn mit Esc/Ctrl-C ab, sendet Claude Code kein `Stop`. Die Session fällt dann nach einem Timeout
(10 Min. Denken / 30 Min. Tool) auf „Bereit“ zurück, spätestens beim nächsten Prompt stimmt alles wieder. In der Hover-Liste kann man sie auch per ✕ wegklicken.
