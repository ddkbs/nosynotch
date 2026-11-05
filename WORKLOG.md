# WORKLOG

## 2026-11-05 (11)
- Fix: **Cursor erschien als „Claude“** – Cursor führt zusätzlich die Hooks aus `~/.claude/settings.json` aus (Cursor-Log bestätigt). Payloads mit `cursor_version` gelten jetzt immer als Cursor; Duplikate über die Claude-URL werden verworfen, solange unsere Cursor-Hooks installiert sind.
- Fix: Genehmigungs-Karte klappt nach **30 s** von selbst zu und gibt die Anfrage an den App-eigenen Dialog zurück (blieb vorher bis ✕ offen).
- Fix: Live-Equalizer fragt seltener nach Audio-Zugriff – Tap bleibt über Pausen offen, wird nur bei 1 min Stille neu verbunden. Hinweis: Jeder lokale Build (neue ad-hoc-Signatur) kann die macOS-Abfrage erneut auslösen.
- Settings: eigene Animationen für Codex (Sechseck + blinkendes `>_`) und Cursor (tippender Zeiger mit Wellen); Status/„Made with“ entfernt, neuer Gold-Stern, freistehende Orbit-Animation.
- Offen: Agent-Glyphen evtl. auch in der Notch statt des Sparks für Codex/Cursor; Release v0.2.0.

## 2026-11-05 (10)
- Projektordner heißt jetzt `~/Desktop/Projects/nosynotch` (von David umbenannt).
- **Grüner Punkt für ungesehene Ergebnisse** (Notch-Flügel, Cover-Badge, Session-Zeile) bis App-Wechsel/Hover/Klick/✕; **Erinnerung nach 5 min** für ungesehenes „Fertig“ und unbeantwortetes „Braucht dich“ (leiserer Sound). **Stumm** 1 h / 8 h / ∞ im Menü und in Settings (nur Ton + Banner, Animationen laufen weiter).
- **Kontext-Ring** pro Session (Claude: Statusline `context_window.used_percentage`, Codex: letztes `token_count` / `model_context_window`), **Usage-Auswahl** Beide/Claude/Codex.
- **Cursor** (`~/.cursor/hooks.json`, camelCase-Events gemappt, Session = `conversation_id`, Hook gibt `{}` bzw. `{"continue":true}` aus). Nur Status, kein Genehmigen (Cursor hat kein passendes Approval-Event). Mit simulierten Hooks geprüft, nicht mit echtem Cursor-Agenten. Achtung: Hooks liegen schon in Davids echter `~/.cursor/hooks.json`.
- **Kopfnicken mit AirPods** (CMHeadphoneMotionManager, standardmäßig aus): Nicken = Allow, Kopfschütteln = Deny, nur solange eine Anfrage offen ist. Nicht mit echten AirPods getestet (keine verbunden).
- **Settings komplett neu** im Notch-Stil: schwarze Sidebar mit Live-Mini-Notch, Seiten Agents/Alerts/Permissions/Usage/Music/General, Karten + eigene Pill-Toggles in Agentenfarben, „Star it on GitHub“-Karte unten links (Stern dreht/funkelt beim Hover).
- Alle GIFs neu (+ `unseen`, `settings`), GIF-Skript flacht Frames auf RGB (sonst wurde Schwarz transparent). README neu geschrieben (Tabelle „Works with“, Fließtext-Abschnitte, Privacy). Version 0.2.0.
- Offen: Kopfnicken + Cursor real testen, Release v0.2.0 taggen, Repo public, `NPM_TOKEN`.

## 2026-11-05 (9)
- **Usage-Balken** im Hover (Settings → Usage, standardmäßig an): 5h- und Wochenlimit für Claude und Codex, grün/gelb/rot, Hover auf Balken = Zeit bis Reset. Claude: Limits gibt es nur im Statusline-JSON → stille Statusline (`curl … /usage`) wird installiert, **nur wenn keine eigene existiert**; Ausschalten entfernt sie. Codex: letzter `rate_limits`-Eintrag aus `~/.codex/sessions/**/rollout-*.jsonl` (bei SessionStart/Prompt/Stop + App-Start). Echte Werte kamen an. Neues GIF `usage.gif`.
- **Live-Equalizer** (Settings → Music, standardmäßig aus): 5 größere, leuchtende Balken, per Core-Audio-Process-Tap (macOS 14.2+) auf die Audio-Prozesse von Spotify/Music + FFT, automatische Verstärkung pro Band (sonst waren die Balken fast immer voll). Live mit Spotify geprüft. `NSAudioCaptureUsageDescription` in Info.plist. Tap läuft nur, wenn Musik spielt und die Option an ist.
- Auffällig: Nach jedem lokalen Build (ad-hoc-Signatur ändert sich) erkennt die App den laufenden Song erst beim nächsten Play/Pause/Trackwechsel (Automation-Rechte hängen an der Signatur). Für Releases egal.
- Cursor: hat eigene Hooks (`~/.cursor/hooks.json`, andere Eventnamen wie `beforeSubmitPrompt`, `beforeShellExecution` mit allow/deny/ask, `stop` mit Status) → Integration machbar, noch nicht gebaut. Claude Code im Cursor-Terminal läuft schon jetzt.
- Offen: Cursor-Unterstützung, Version 0.2.0 taggen, Repo public, `NPM_TOKEN`.

## 2026-11-05 (8)
- **Leises „Fertig“**: Ist die App der Sitzung vorne (Claude-App, Terminal, VS Code, ChatGPT …), zeigt die Notch bei `Stop` nur kurz (3 s) einen grünen Haken in der kompakten Leiste – keine Karte, kein Sound, kein Banner. Sonst wie bisher groß.
- Nachtrag: auch **„Braucht dich“** bleibt klein, wenn die App vorne ist (kein Sound, keine Karte, bernsteinfarbene Blase in der Leiste); der Permission-Hook antwortet dann sofort ohne Entscheidung → der App-eigene Dialog übernimmt. Live geprüft mit Claude-App vorne. Fehler bleiben immer groß.
- Entscheidung: Vergleich auf App-Ebene (Bundle-ID aus `$__CFBundleIdentifier` bzw. `TERM_PROGRAM` vs. `frontmostApplication`), Fenster/Tab ist nicht erkennbar. Claude-App setzt `com.anthropic.claudefordesktop`. Abschaltbar in Settings → Notifications.
- Neues GIF `quiet-done.gif`.
- Offen: Wechselt man während „Braucht dich“ weg von der App, poppt nichts nachträglich groß auf (nur die Leiste). Sonst wie (7).

## 2026-11-05 (7)
- **Codex-Unterstützung** (Codex CLI + Codex-Modus der ChatGPT-App): gleiche curl-Hooks in `~/.codex/hooks.json` (bzw. `$CODEX_HOME`), URL mit `&agent=codex`. Sitzungen merken sich ihren Agenten: blauer Spark, „Codex“/„Claude“-Badge, Icons für `apply_patch`/`update_plan`/`web_search`, `Interrupt`-Hook → sofort „Ready“. Settings-Abschnitt „Codex“, CLI installiert/entfernt/zeigt Codex-Hooks mit. Neues GIF `codex.gif`.
- Codex führt Hooks erst aus, wenn man ihnen einmal vertraut (App: Codex → Settings → Hooks, CLI: `/hooks`) – das kann Nosy Notch nicht abnehmen, Hinweis steht in Settings/CLI/README.
- **Genehmigen in der Notch**: `PermissionRequest`-Hook wartet auf `POST /permission`, Notch zeigt Deny / Allow / (Always allow). Getestet mit echtem Claude Code: Terminal-Dialog bleibt parallel offen, Hook-„allow“ schließt ihn. Codex zeigt seinen Prompt erst nach dem Hook → dort 45 s Wartezeit bzw. ✕ gibt sofort zurück. Antwort im Terminal / neuer Turn → Hook endet ohne Entscheidung.
- Entscheidungen: Geheimnis in `~/.nosynotch/approval-token` (0600), Hook gibt nur Antworten mit Token weiter (gegen fremde Prozesse auf dem Port). „Always allow“ nur `addRules`/`addDirectories` – `setMode` würde z. B. die ganze Sitzung auf „accept edits“ stellen (im Test passiert). Abschaltbar in Settings → Permissions.
- Fix: Server versucht es erneut, wenn der Port beim Start noch belegt ist (vorher blieb die App taub).
- Offen: echter Codex-Lauf mit den Hooks (Testlauf mit `--dangerously-bypass-hook-trust` wurde vom Auto-Mode geblockt) – David muss die Hooks in Codex einmal vertrauen und kurz testen. Version noch 0.1.0 → für Release auf 0.2.0 heben und taggen. Offen von (6) bleibt: Repo public, `NPM_TOKEN`.

## 2026-11-05 (6)
- GitHub-Repo umbenannt: `ddkbs/claude-notch` → **`ddkbs/nosynotch`** (Remote, `REPO` in der CLI, package.json, Settings-Link angepasst).
- **Release v0.1.0** getaggt: CI grün, Release mit `NosyNotch-macos.tar.gz` (Universal arm64+x86_64, ad-hoc signiert) liegt auf GitHub. npm-Publish übersprungen (kein `NPM_TOKEN`).
- Offen (nur David kann das): Repo öffentlich stellen (sonst 404 beim Download für andere), npm-Token als Secret `NPM_TOKEN` anlegen, dann Release-Workflow für `v0.1.0` erneut ausführen → npm publish.

## 2026-11-05 (5)
- **Name: Nosy Notch** (npm/CLI `nosynotch`, App `Nosy Notch.app`, Bundle-ID `dev.davidkubus.nosynotch`, Daten `~/.nosynotch`). Grund: „Claude“ ist Marke von Anthropic. Alte claude-notch-Hooks werden erkannt und ersetzt, `npx nosynotch` räumt alte App/LaunchAgent/Ordner weg. GitHub-Repo heißt noch `ddkbs/claude-notch` (Release-Downloads zeigen dorthin).
- **Alles Englisch**: App, CLI, README, docs. WORKLOG bleibt deutsch.
- README: keine PNGs mehr (David will keine), Demo-GIF oben + beschriftetes 2-Spalten-Raster. `docs/screenshots` gelöscht, Stills nur noch mit `STILLS=1`.
- **Einstellungsfenster** (✦ → Settings…, `npx nosynotch settings`, `POST /settings`): Connect-Button + Status je Config-Ordner, Launch at login (gleicher LaunchAgent wie CLI), 3 Sounds einzeln, Anzeigedauer, macOS-Mitteilungen, Musik an/aus + „auch pausiert zeigen“. Menü nur noch Settings / Demo / Quit. Öffnet sich beim allerersten Start, wenn keine Hooks da sind.
- Offen: Damit `npx nosynotch` für andere klappt: Repo öffentlich (oder Binaries woanders hosten), Tag `v0.1.0` → Release, `NPM_TOKEN` setzen → npm publish. Repo ggf. in `nosynotch` umbenennen (dann `REPO` in bin/nosynotch.js anpassen).

## 2026-11-05 (4)
- **Media-Player als Ruhe-Notch**: Spielt Spotify/Apple Music und Claude ist idle → Cover links, EQ in Cover-Farbe rechts; Hover → Player (Titel, Fortschritt mit Spulen, Zurück/Play/Weiter). Claude hat immer Vorrang.
- **✕ an allen Benachrichtigungen** (Fertig / Braucht dich / Fehler) → zurück zur Ruhe-Notch (Musik).
- Entscheidungen: Track-Infos über Distributed Notifications der Player (keine Berechtigung), Steuerung per AppleScript (einmal Automation-Prompt), Cover über Spotify oEmbed / iTunes Search. MediaRemote ist seit macOS 15.4 für Dritt-Apps zu → Browser/YouTube gehen (noch) nicht.
- Fallstricke: Distributed Notifications brauchen `suspensionBehavior: .deliverImmediately` (sonst hält macOS sie bei Hintergrund-Apps zurück); `AEDeterminePermissionToAutomateTarget` blockiert auf dem Main-Thread für immer → läuft auf eigener Queue.
- Neue GIFs `media`, `handoff`, Screenshot `media.png`; alle GIFs neu (✕ sichtbar).
- Offen: Produktname (Vorschlag „Brow“, npm frei; „Claude“ wegen Markenrecht nicht im Namen eines Bezahlprodukts), echter Test mit Spotify-Steuerung auf dem MacBook (Automation-Prompt), evtl. MediaRemote-Adapter für alle Quellen, Release taggen.

## 2026-11-05 (3)
- Aufnahmen mit neuem, farbigem macOS-artigem Hintergrund (Radialverläufe statt `.blur()`, weil `cacheDisplay` keine Blur-Filter rendert).
- Pro Szene zusätzlich ein Standbild mit ausgeklappter Notch → `docs/screenshots/*.png` (2×). README zeigt oben die ausgeklappte Hover-Liste, `docs/animations.md` hat einen Screenshot-Abschnitt.
- Turn-Dauern unter 1 s werden nicht mehr angezeigt („0s“).
- Offen: wie (2).

## 2026-11-05 (2)
- **Fehler-Zustand**: `StopFailure` (Rate-Limit, Überlastung, Auth …) → rotes „Claude ist gestolpert“, flackernder Spark, Sound Basso, Fehlercode übersetzt. `PostToolUseFailure` löst bewusst *keinen* Alarm aus (rote Tests sind Alltag).
- **`PermissionRequest`-Hook** dazu: „Braucht dich“ kommt sofort beim Erlaubnis-Dialog, mit Tool + Befehl in der Nachricht; die nachfolgende `permission_prompt`-Notification wird nicht doppelt gemeldet.
- **Bug: Hooks wirkten nicht bei `CLAUDE_CONFIG_DIR`** (David nutzt `~/.claude-zweit`). App + CLI tragen Hooks jetzt in `~/.claude`, `$CLAUDE_CONFIG_DIR` und alle `~/.claude-*`-Config-Ordner ein; `status` listet jeden Ordner. Lokal installiert in beiden Ordnern.
- **GIFs**: `ClaudeNotch --record` rendert den echten `NotchView` auf gestellter Menüleiste mit 30 fps, `scripts/record-gifs.sh` macht per ffmpeg GIFs in `docs/gifs/`. README hat Demo-GIF + 4er-Raster, `docs/animations.md` alle Animationen mit auslösendem Hook.
- Offen: echte Notch auf dem MacBook mit einer neu gestarteten Session gegenprüfen; evtl. Anzeige für `SubagentStart` / Hintergrund-Tasks; Release v0.1.1 taggen, damit `npx` die neuen Hooks verteilt.

## 2026-11-05
- Projekt angelegt (leerer Ordner, git init).
- Ziel: macOS-Notch-App, die den Live-Zustand von Claude Code animiert anzeigt und bei „fertig“ / „braucht dich“ benachrichtigt.
- Entscheidung: **Hooks statt MCP**. MCP ist pull-basiert (Claude ruft Tools auf), Hooks feuern bei jedem Lifecycle-Event. Hooks `curl`en das JSON an einen lokalen HTTP-Server in der App (127.0.0.1:7823).
- Stack: Swift Package (macOS 14+), AppKit-`NSPanel` über der Notch + SwiftUI für die Animationen, Network.framework für den Server.
- v0.1 implementiert: Zustände (denkt / Tool / braucht dich / komprimiert / fertig), Hover-Liste mit mehreren Sessions, Konfetti + Häkchen bei Fertig, Shake + Glow bei Rückfrage, Sounds, optionale macOS-Mitteilungen, Klick → Terminal aktivieren, Hook-Installer (Menü + `--install-hooks`), Demo-Modus.
- Offen: Auf echtem Mac bauen und testen (in der Cloud-Session gab es keinen Swift-Compiler), Feintuning von Notch-Radien / Timings, ggf. App-Icon, Autostart-Option, Kontext-/Token-Anzeige.
- Umbau auf **`npx claude-notch`** (kein App-Download/kein Apple-Developer-Account): Node-CLI ohne Dependencies lädt eine ad-hoc-signierte Universal-Binary aus GitHub Releases nach `~/.claude-notch/` (Fallback: lokal mit `swift build`), trägt Hooks ein, startet den Helfer, optional Autostart per LaunchAgent. Neuer Server-Endpoint `POST /quit` für `stop`.
- GitHub Actions (macOS-Runner): baut Universal-Binary, Smoke-Test, Release bei Tag `v*`, npm publish wenn `NPM_TOKEN` gesetzt.
