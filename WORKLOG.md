# WORKLOG

## 2026-11-13 (Release v0.4.0)
- Branch `feat/idle-clock-node-download` per Fast-Forward nach `main`, Version 0.4.0 (statt 0.3.1, weil Uhr, Next Prompt, Fortschritt und Ports neue Features sind), Tag `v0.4.0` gepusht. CI grün, GitHub-Release mit Universal-Binary da. Issues #1 #2 #4 #6 #9 per „Fixes #n“ automatisch geschlossen; PRs #5 #7 #8 #10 ohne Kommentar geschlossen (Davids Wunsch).
- Vorher lokal: Universal-Release-Build + Smoke-Test im Fake-Home auf Port 7899 (Health, Event, Quit), echte Settings unverändert.
- `npm publish` von David selbst (CI ohne `NPM_TOKEN` übersprungen): erst 404 = abgelaufener Token in `~/.npmrc` (npm meldet das als 404), nach `npm login` + Browser-Bestätigung beim Publish → `+ nosynotch@0.4.0`. Registry zeigte direkt danach noch 0.3.0 (Verzögerung).
- Historie umgeschrieben (David wollte ehames nicht als Contributor): `Co-authored-by: Edgardo Hames` aus 3 Commits entfernt (filter-branch, Inhalt identisch), `main`, Feature-Branch und Tag `v0.4.0` force-gepusht; Release + npm unverändert. Erneut ausgelöster Tag-Build abgebrochen (Release gibt es schon). Lokales Backup: Branch `backup/pre-rewrite`. Künftig keine Co-Autor-Zeilen für Fremd-Fixes.
- **Offen:** Neue Features weiter nicht auf echter Notch getestet. Website-Deploy nach Push auf main nicht geprüft. #3 (opencode) unbeantwortet.

## 2026-11-13 (Issues #1, #2, #4, #6, #9 – CPU, Backup, Statuszeile)
- **Übernommen von ehames** (Co-authored-by, lokal auf diesem Branch): #5 Settings-Fenster wird beim Schließen freigegeben (~46 % CPU im Leerlauf), #7 Splash wird nach dem letzten Frame entfernt (~5 % CPU), #8 `@Entry` ausgeschrieben → Build nur mit Command Line Tools + 26.5-SDK klappt (getestet).
- **Eigen:** Nosys Augen im Flügel (auch neben der Uhr) zeichnen in ruhigen Stimmungen nur noch beim Blinzeln (`NosyBlinkSchedule`, ~0,6/s statt 30/s, Kanten per Skript geprüft), Schlaf-Zzz mit 20 FPS.
- **#2:** Install = ein Laden-Ändern-Speichern pro Datei; `.nosynotch.bak` wird nie durch eine Datei mit unseren Hooks ersetzt (App + CLI).
- **#9 selbst gelöst, PR #10 geschlossen (ohne Kommentar):** eigene Statuszeile wird wörtlich in `{ … }` eingebettet (kein Quoting, keine Zusatz-Keys in settings.json – Claude Code könnte unbekannte Keys anmeckern). Erkennung über `/usage?src=nosynotch` statt nur „nosynotch“ (sonst zählt ein Pfad mit nosynotch als unsere). Befehle mit `\` am Ende bleiben unangetastet. Getestet im Fake-Home (env -i + CFFIXED_USER_HOME, echte Dateien per mtime geprüft): Ausgabe/stderr/Exit bleiben, JSON kommt an, sh + zsh, idempotent, Trennen stellt exakt wieder her, App und CLI erzeugen denselben Befehl.
- **Nicht getestet:** CPU-Messung im echten Leerlauf (App nicht neu installiert – Bedienungshilfen-Recht), echte Claude-Statuszeile live.
- **Offen:** Branch pushen/mergen (38+7 Commits, nur lokal), danach PRs #5, #7, #8 schließen und Issues beantworten; #3 (opencode) nur beantworten.

## 2026-11-12 (Offene Ports)
- **Ports** (`Ports.swift`, `Views/PortViews.swift`): lauschende TCP-Ports per libproc (kein `lsof`), Elternkette per `sysctl` (libproc scheitert an root-Prozessen wie `login`). Zeigt Port, was es ist (Skript hinter node/python, z. B. „vite“), Ordner (cwd), wer es gestartet hat (Agent + erste App in der Kette), nur-localhost vs. Netzwerk (🌐). Klick öffnet `localhost:PORT`, ✕ = SIGTERM, nach 2 s SIGKILL (mit Startzeit-Check gegen PID-Wiederverwendung).
- Entscheidungen: Standard nur Dev-Prozesse (von Agent/Terminal/Editor gestartet oder kein App-Prozess); Agents selbst und NosyNotch ausgeblendet, „Include apps“ zeigt den Rest. Apps fragen vor dem Beenden („Quit“-Bestätigung im Chip). Nur eigene Prozesse sichtbar, root-Dienste gar nicht – kein Passwort nötig. Settings → Extras, Standard aus (bei David per `defaults write` an). Session-Zeile zeigt `:5173`, wenn der Agent der Session den Server gestartet hat (PID in der Kette, sonst gleicher Ordner + Agent).
- `NosyNotch --ports` listet dasselbe im Terminal. Recorder-Szene `ports` + `docs/gifs/ports.gif`; im Recorder wird nie ein echter Prozess beendet.
- Geprüft: Scan gegen echte Prozesse (vite aus Claude, Raycast-Backend, Spotify, ControlCenter, ollama …), Beenden eines Test-Servers (anderer Prozess auf gleichem Port blieb), Offscreen-Render. Installiert in `build/Nosy Notch.app`, Nosy-Level unverändert (Backup: `~/Desktop/nosynotch-defaults-backup-2026-11-12.plist`).
- **Nicht getestet:** echtes Hovern/Klicken auf der Notch, Bestätigungs-Flow mit echter Maus.
- **Offen:** Bedienungshilfen-Recht nach Neubau neu setzen. GIF nicht im README-Raster, Website zeigt Ports nicht. Branch weiter nur lokal.

## 2026-11-08 (Next Prompt, Fortschritt, schlauere Uhr, Garderobe)
- **Next Prompt** (`ReplyQueue.swift`): Antwort während der Agent arbeitet oder wartet geht in die Warteschlange (max. 3, ✕ pro Eintrag), nach jedem `Stop` genau eine. Entscheidungen: Einfügen wartet bis 1,5 s ohne Tastendruck, nicht bei gesperrtem Bildschirm, danach Fokus zurück zur vorherigen App, denn sonst würde es mitten ins Tippen fahren. Nach dem Senden blockiert `inFlight` bis `UserPromptSubmit`, damit die 5-Minuten-Erinnerung (auch `.finished`) nichts doppelt schickt.
- **Fortschritt** (`TodoProgress` in `Session.swift`): liest `TodoWrite`, `TaskCreate`/`TaskUpdate` (Formate aus echten Transkripten geprüft), Codex `update_plan` und `*__update_plan` der Desktop-App. Flügel: Icon + „3/7“, ab 10 Schritten nur die Zahl. Fertige Liste wird beim nächsten Prompt geleert.
- **Uhr:** Countdown „in 8m“ in den letzten 15 min vor einem Termin (nur mit Kalender an), zweite Zeitzone aus fester Stadtliste auf der großen Uhr (Settings → Extras).
- **Garderobe:** War schon an Level gekoppelt (mein Vorschlag war da ungenau). Neu: Ziele über besten Streak und Aufgabenzahl, Party-Hut (100 Tasks), Krone (7 Tage), Heiligenschein (30 Tage), „✦ New: Crown“ auf der Done-Karte. Bug behoben: `NosyFigure` prüfte Level selbst, die Vorschaubilder (level 1) zeigten nie ein Accessoire; Prüfung jetzt in `NosyPet.wearing`.
- Geprüft: Offscreen-Renders aller neuen Zustände, Kompilat-Check aller Task-Listen-Formate, Queue-Ablauf im Recorder mit Stub statt echtem Einfügen.
- **Nicht getestet:** echtes Einfügen aus der Queue mit Fokus-Rückgabe, CGEvent-Tippruhe, echter Kalender-Countdown, alles auf echter Notch.
- **Offen:** alles auf Branch `feat/idle-clock-node-download`, nur lokal, nichts gemergt. Website zeigt die neuen Features noch nicht. `docs/gifs/settings.gif` ist nicht neu aufgenommen.

## 2026-11-08 (Uhr im Leerlauf, Node-Download)
- **Uhr** (`Views/IdleClock.swift`, neuer Zustand `.clock`, niedrigste Priorität vor `.peek`/`.hidden`): rechter Flügel Zeit, links Nosy (ohne Nosy: Wochentag), Doppelpunkt atmet in Gold, Ziffern rollen, dunkler wenn Nosy schläft. Hover: große Uhr + Datum statt „No active sessions“. Settings → Extras, Standard an.
- Entscheidungen: „Nichts läuft“ = kein Agent, keine angezeigte Musik, kein Timer, nichts Ungesehenes. Nur unter echter Notch (sonst dauerhafte schwarze Pille). Im Recorder nur in Szene `clock`, damit die anderen GIFs gleich bleiben. Zeit schlägt `.peek`, sonst flackert sie bei Mausnähe.
- Geprüft per Offscreen-Render (Uhr, Hover, Agent übernimmt, Uhr kommt zurück) und `docs/gifs/clock.gif`. **Nicht** auf echter Notch getestet.
- Achtung: Der rechte Flügel (46 pt) liegt jetzt dauerhaft über Menüleisten-Icons direkt neben der Notch.
- **Website:** `GetNode`-Link holt live die neueste LTS aus `nodejs.org/dist/index.json` (CORS offen) und verlinkt direkt die universelle `.pkg`; Fallback `nodejs.org/en/download`. Im Hero, in der Install-Karte, auf der Copied-Karte und im Finale. Browser-Test ok (v26.13.0).
- **Offen:** Branch `feat/idle-clock-node-download` nicht gemergt/gepusht; Uhr braucht Release, Website geht erst mit Push auf `main` live. Uhr nicht im Website-Grid „Not just agents“ (7. Kachel würde das 3er-Raster brechen).

## 2026-11-07 (Reply bei zwei Claude-Instanzen)
- Ursache: David hat zwei Instanzen von `Claude.app` (gleiche Bundle-ID, zweite mit `--user-data-dir=…/Claude-Zweit`). Reply/Klick hat per Bundle-ID die erste aktiviert → falsches Fenster.
- Fix: Claude- und Cursor-Hooks schicken `X-Host-Pid: $PPID`; die App geht die Prozesskette hoch bis zur ersten regulären App (`TerminalActivator.hostApp`) und aktiviert genau die. Codex-Hooks bewusst unverändert (geänderte Hooks müssten in Codex neu vertraut werden). CLI baut identischen Befehl (geprüft).
- App ersetzt beim Start eigene veraltete Hooks durch den aktuellen Befehl (nur wo schon verbunden). `~/.claude` und `~/.claude-zweit` sind aktualisiert.
- Panne beim Testen: `--install-hooks` mit `CFFIXED_USER_HOME` hat wegen `CLAUDE_CONFIG_DIR` echte Dateien angefasst; `~/.cursor/hooks.json` aus dem Backup zurückgesetzt (war leer), `~/.claude-zweit` nur eigene Hooks geändert.
- Nach jedem lokalen Build: Bedienungshilfen-Recht für die Dev-App neu setzen (neue ad-hoc-Signatur), sonst kann Reply nicht tippen.
- **Offen:** Reply real testen; für andere Nutzer braucht es ein Release (v0.3.1) + npm, sonst fehlt die PID im Hook. Nicht gepusht.

## 2026-11-07 (Nosy + Extras, v0.3.0 vorbereitet)
- **Nosy** (`Sources/NosyNotch/Nosy/`): Figur in SwiftUI (Bohnen-Körper, Stummelarme, Füßchen, ✦-Antenne, 15 Stimmungen, Accessoires), 8 Farben (Standard Obsidian = Randlicht in Agentenfarbe). Design in 3 Runden mit David abgestimmt (`--nosy-sheet <png>` rendert alle Stimmungen/Farben). Augen im linken Flügel statt Agent-Glyphe, folgen der Maus; Peek bei Maus in der Nähe; schläft nach 10 min (nachts 2 min); hängt unter offener Notch, taucht beim Schließen wie in Teer ein (Splash). Klick = kichern.
- **Tamagotchi** (`NosyPet`): Energie/XP/Level/Streak in UserDefaults, fertige Tasks füttern (Demo nicht), Energie-Boden 0,12, keine Schuldgefühle. Level-up-Pill auf der Done-Karte. Settings-Seite „Nosy“ (an/aus, Fortschritt + Reset, Farbe, Garderobe).
- **Extras**: Shelf + AirDrop (Datei-Drag an die Notch), Notices (Laden, 20 %, Bluetooth-Kopfhörer mit L/R/Case – opt-in), Fokus-Timer (Hover-Button, Menüleiste, stummt Agent-Sounds), Kalender (EventKit, opt-in, Heads-up 10 min, Join-Links), **Chat in der Notch** (Transcript lesen, Antwort per ⌘V+Return in die App – braucht Bedienungshilfen – oder `claude --resume -p` / `codex exec resume`). Settings-Seite „Extras“. Info.plist: Kalender- und Bluetooth-Texte.
- Recorder: neue Szenen nosy, level-up, chat, drop-zone, shelf, meeting, focus, charging, airpods; Szenen höher (Nosy hängt unten). Farbige SF-Symbole verlieren im Recorder (`cacheDisplay`) ihre Farbe → `TintedSymbol` (Bitmap) in Notice-/Drop-Karten.
- Website: Sektionen „Meet Nosy“ (SVG-Nosy, Farben, Stimmungen, Teer-Sprung) und „Not just agents“ (MP4s aus `public/demo`). README + `docs/animations.md` aktualisiert, Version 0.3.0.
- Promo-Session hat `promo/REDDIT.md` geschrieben (eigene Commits).
- **Nicht getestet** (keine echte Interaktion möglich, kein Bildschirm-Recht für Screenshots): echter Datei-Drag aus dem Finder, AirDrop-Dialog, Antwort per Eintippen, Kalender-/Bluetooth-Berechtigungen, Akku-Events. Alles nur offscreen gerendert bzw. gebaut.
- Gepusht + Tag `v0.3.0` (David). CI-Smoke-Test schlug fehl: App lebte >1 s nach `/quit` – vermutlich `EKEventStore()` beim Start (blockiert ohne TCC). Fix: Store lazy, Smoke-Test wartet bis 5 s. Tag muss neu gesetzt werden (kein Release/npm war entstanden).

## 2026-11-06 (Fixes nach Security-Check)
- `EventServer`: Requests mit `Origin`/`Sec-Fetch-Site` → 403 (Browser), `Content-Length` < 0 → 0. Nicht `Sec-Fetch-Mode` prüfen: Node-`fetch` (CLI) schickt `sec-fetch-mode: cors`. Getestet auf Port 7899 (`NosyNotch -port 7899`).
- Workflow: `NPM_TOKEN` nur noch im Publish-Schritt.
- GitHub: Beschreibung, Homepage `https://nosynotch.davidkubus.dev`, Topics gesetzt.
- **Release v0.2.0** (CI, universal binary, ad-hoc signiert) und **npm `nosynotch@0.2.0`** veröffentlicht (David per `npm publish`, Browser-Auth). `npx nosynotch --version`/`status` aus der Registry getestet; volle Installation per npx nicht getestet (hätte Davids Dev-Setup ersetzt). npm zeigt nach dem Publish einige Minuten nur `0.0.0-stage`.
- Danach Dev-Build deinstalliert (`npx nosynotch uninstall`) und frisch per `npx nosynotch` installiert: Download aus dem Release klappt, App läuft aus `~/.nosynotch/`, Hooks überall, Browser-Request → 403. Autostart ist nach Neuinstallation aus.
- Push/Tag/Publish macht der Auto-Modus nicht → David führt sie selbst aus.
- **Offen:** GitHub Code security (Secret Scanning, Push Protection, Dependabot, Private Vulnerability Reporting) selbst einschalten; `NPM_TOKEN`-Secret für automatische Publishes (2FA-Bypass-Tokens werden bei npm eingeschränkt → evtl. Trusted Publishing); Actions auf Node-24-Versionen heben (`checkout`/`upload-artifact` v4 = Node 20).

## 2026-11-06 (Security-Check nach Public)
- Git-Historie (133 Commits) sauber: keine Keys/Tokens/.env, Autoren nur noreply-Adressen.
- **Offen (Code):** `EventServer` – (1) negativer `Content-Length` lässt die App abstürzen (Range-Trap in `HTTPRequest`, verifiziert); (2) jede Website kann per `fetch(…, {mode:'no-cors'})` an 127.0.0.1:7823 posten → App beenden (`/quit`), Fake-Events/-Freigabekarten zeigen. Fix-Idee: Requests mit `Origin`- bzw. `Sec-Fetch-*`-Header ablehnen (curl schickt keinen), Content-Length ≥ 0 prüfen.
- **Offen (Repo):** npm-Name `nosynotch` noch nicht veröffentlicht (README sagt `npx nosynotch` → Name kann gesquattet werden); Release v0.2.0 fehlt (package.json 0.2.0, letztes Release v0.1.0); Secret Scanning / Push Protection / Dependabot / Private Vulnerability Reporting aus, `main` ungeschützt, keine SECURITY.md.
- Kleinkram: Workflow `NPM_TOKEN` auf Job-Ebene statt nur im Publish-Schritt, `permissions: contents: write` für alle Läufe; Download im CLI ohne Checksumme.

## 2026-11-06 (Vercel-Fix)
- Webseite war 404: Vercels Git-Integration baut bei jedem Push auf `main` aus dem Repo-Root (Root Directory nicht auf `website/`) → leerer Build hat die per CLI deployte Seite ersetzt. Fix: `vercel.json` im Repo-Root (install/build per `npm --prefix website`, Output `website/dist`). Seite wieder live auf nosynotch.davidkubus.dev und nosynotch.vercel.app.
- Alternative (sauberer, nur David): im Vercel-Projekt Settings → Build & Deployment → Root Directory = `website`, dann kann die Root-`vercel.json` weg.

## 2026-11-06
- **Cursor: Freigabe in der Notch** über `beforeShellExecution` / `beforeMCPExecution` (blockierender Hook mit Token wie bei Claude/Codex). Nur Befehle mit `sandbox: false` warten (das sind die, nach denen Cursor fragt), sandboxed → sofort `{}`. Antwort `{"permission":"allow"|"deny"}`; ✕/45 s/kein App → `{}` → Cursors eigener Dialog. Simuliert getestet (Warten, Freigabe nach postToolUse), Klick auf Allow mit echtem Cursor noch nicht. Settings → Permissions „Cursor: commands outside the sandbox“.
- **Cursor: Kontext-Ring** aus `afterAgentResponse.input_tokens` / `model_params.context` ("256k").
- **Cursor: Usage-Limits nicht möglich** – Cursor gibt keine Limits an Hooks; Daten nur im Web-Dashboard (bräuchte Login-Cookies, bewusst nicht).
- **Leises Fertig auch für Cursor und ChatGPT-App**: ohne Bundle-Hinweis im Hook → Fallback auf die App des Agenten (`com.todesktop.230313mzl4w4u92`, `com.openai.codex` = ChatGPT.app).
- Achtung beim Testen mit curl aus Claude: `__CFBundleIdentifier` der Claude-App wird mitgeschickt → leiser Modus greift.

## 2026-11-06 (18)
- Recorder-Branch in `main` gemergt (nur WORKLOG-Konflikt). `swift build` grün, Demo nicht live laufen gelassen.
- **Website deployed**: Vercel-Projekt `nosynotch` (ddkbs-projects), Root `website/`, live unter https://nosynotch.vercel.app. Domain `nosynotch.davidkubus.dev` ist im Projekt eingetragen, aber **DNS fehlt**: bei Cloudflare CNAME `nosynotch` → `771b02c0492556e1.vercel-dns-017.com` (Proxy aus / DNS only) anlegen.
- Erneut deployen: `cd website && vercel deploy --prod`.
- Solange das Repo privat ist: GitHub-Links auf der Seite → 404 für Besucher, Sternzähler/Version kommen nicht (Fallback v0.2.0).

## 2026-11-06 (17)
- Website-Notch verhält sich wie die App: exakte `NotchShape` (Quad-Flares), App-Feder (response 0.42 / damping 0.74 → 224/22.1), Glow r14 + schwarzer Schatten, Sinus-Shake, blurFade/move/scale-Übergänge; Hover öffnet sofort (Rect + 6 pt), Verlassen schließt sofort; offen 460 pt mit Flügel-Leiste.
- „Welcome back“ entfernt; Hover verwandelt keine Nachricht mehr in die Install-Karte (Markier-Karte bleibt klickbar, Markierung bleibt beim Copy erhalten). Momente schalten immer weiter (auch nach Klick), Kicker „Interactive demo“, Versions-Pill im Hero weg.
- Nach Copy/Download bleibt die Karte offen mit ① ② ③ (Tastenkappen, Spotlight → ⌘V → ↵ bzw. Downloads → Applications → öffnen) + Star-Button. Terminal direkt öffnen geht aus dem Browser nicht (keine URL-Schemes dafür, `.command`-Downloads verlieren Ausführrecht).
- Stern: glänzender Goldstern (Verlauf, Lichtschweif, Funkeln) in Kachel + Karten; 45-s-Karte ist komplett ein Link zu GitHub. Neu: neue Sterne live feiern (Polling alle 90 s), Uhrzeit-Laune 1× pro Besuch (23–5 Uhr „still coding? me too.“, 5–10 Uhr „gm ☀“).
- Recorder-Session (Branch `claude/awesome-einstein-7c9290`, 7 Commits, nicht gemergt): virtuelle Uhr, 60 fps, SCALE, neue GIFs/MP4s. David entscheidet übers Mergen.

## 2026-11-06 (16)
- Website: nur noch TargetCursor (wie sketchy/davidkubus), Umschalter + „How it works“-Pipeline entfernt, Momente ohne Textzeile und ohne Live/Aufnahme-Schalter, Versions-Pill verlinkt das Release.
- Top-Notch: öffnet schon beim Hover die neu gestaltete Install-Karte (App-Icon, tippende Terminalzeile, Kacheln Copy & install / Download / Star mit Zähler, Aurora + Punkteraster, „nah, not today“ → beleidigte Augen). Stern-Bitte nach Copy/Download und nach 45 s (1× pro Besuch, sessionStorage). Extras: „Welcome back“ nach Tab-Wechsel, Einschlafen nach 20 s (zzz) + „oh! hi.“, beim Markieren lustige Sprüche + Copy.
- Nod: läuft komplett über Motion-Springs (kein Re-Render pro Mausbewegung), AirPods mit Stiel, Fortschrittspunkte, Puls bei erkannter Geste.
- `website/public/demo/*.mp4` wird von der Seite nicht mehr genutzt (Recorder-Session schreibt evtl. dorthin) → entscheiden, ob löschen.

## 2026-11-06 (16)
- **Recorder deterministisch**: neue `Clock.swift` (Wanduhr, beim Aufnehmen virtuelle Uhr + Zeitplan). Model-Zeitstempel/Timeouts über `Clock.now()` / `Clock.after()`, Views nutzen `ClockTimeline` / `PeriodicClock` statt `TimelineView`. SwiftUI-Animationen werden per `NSHostingView._renderForTest(interval:)` pro Frame weitergeschoben → Frame N = Zeitpunkt N/fps, keine verlorenen Frames (langsamer Mac = nur längere Aufnahme).
- `FPS` (Standard 60) und `SCALE` (Standard 2, 3 = 1680 px) als Env-Variablen; PNGs parallel kodiert.
- Farbfix: alte Frames hatten das Display-Profil eingebrannt (ffmpeg ignoriert ICC) → GIFs waren blass. Jetzt reines sRGB, MP4 als BT.709 getaggt.
- `record-gifs.sh`: GIF 30 fps / 840 px / 256-Farben-Palette fürs ganze Video; dazu H.264-MP4 (60 fps, 1120 px) + JPG-Poster in `website/public/demo/`. `WEBM=1`, `VIDEO=0`, `GIF_WIDTH/GIF_FPS/GIF_COLORS`. Alles neu aufgenommen (GIFs ~17 MB statt 13 MB, MP4s ~4,5 MB).
- Entscheidung: `_renderForTest` ist unterstrichene SwiftUI-API (stabil seit macOS 10.15, nur im Recorder benutzt) – Alternative wäre Echtzeit mit Drops gewesen.
- Offen: Website nutzt die Poster (`/demo/<name>.jpg`) noch nicht (`poster=` im `<video>` in `Moments.tsx`); ggf. `SCALE=3` für die Website testen.

## 2026-11-05 (15)
- **Website neu** (Version A gewählt; B und Docs entfernt, kein sketchy-Layout mehr): macOS-Menüleiste mit eigener Notch oben am Fenster (Hover „psst… get me“, Ring = Scrollfortschritt, öffnet die Install-Anfrage Deny / Download / Allow; Deny = „Fine. I'll just keep watching.“ bleibt). Hero mit Pfeil „psst, that's me“.
- **Momente live statt GIF**: Notch in React nach den SwiftUI-Views nachgebaut (`website/src/notch/`: Maße 185×32, Flügel 46, 460 breit, Funke mit 10 Strahlen, Codex-Sechseck, Cursor-Würfel, Done/Needs-you/Sessions+Usage/Musik). „Needs you“ ist klickbar. Schalter zeigt alternativ die echte Aufnahme (`public/demo/*.mp4`).
- Weitere Sektionen: Agenten-Karten (Hover weckt das Symbol), „Just nod“ (Maus hoch/runter = Allow, links/rechts = Deny), Hook-Pipeline mit „Try to send something to the internet“ → „nope.“, Finale „Let it watch.“
- Hintergrund: 10 statt 8 Strands, neue Palette `DRAPE_PALETTE` (Indigo → Violett → Magenta → Orange), stärkerer räumlicher Verlauf.
- 5 Cursor (Notch, Spark, Eye, Swarm, System); Umschalter nur in `npm run dev` (Punkt unten rechts, Tasten 1–5), Wahl in localStorage.
- Achtung: Commit `a6fd388` (Limit-Reset, anderer Account) hat meine vorgemerkten Website-Löschungen mitgenommen → zwischen `a6fd388` und `e12c92c` baut die Website nicht. Künftig vor `git commit` nur eigene Dateien stagen (`git add <pfade>`).
- Vorschlag offen: Recorder auf virtuelle Uhr + 60 fps + 3× umbauen (schärfere GIFs fürs README, MP4 für Website).
- Offen: David prüft Bewegung/Cursor live und wählt Cursor; Vercel-Deploy auf `nosynotch.davidkubus.dev`.

## 2026-11-05 (13)
- **Limit-Reset-Benachrichtigung**: Erreicht ein 5h- oder Wochenlimit, das bei ≥ 80 % stand, seine Reset-Zeit → Notch-Karte „Claude/Codex is ready again“ (Ring läuft leer, Pfeil dreht sich), Sound „Hero“, optional Banner. Arbeitet mit den zuletzt bekannten Werten (Timer alle 20 s, vor jedem Update geprüft), feuert auch nach App-Start einmal, wenn der Reset bis zu 12 h her ist; bereits gemeldete Resets in UserDefaults. Settings → Usage, standardmäßig an. GIF `limit-reset.gif`.
- Reddit-Launch-Seite (Artifact) mit Posts für 23 Subreddits erstellt; vor dem Posten: Repo public, `NPM_TOKEN` + Tag, LICENSE.
- Monetarisierung besprochen: GitHub Sponsors über Konto eines Elternteils (Stripe verlangt Volljährigkeit), später Pro-Version über Merchant of Record. Keine Rechtsberatung.

## 2026-11-05 (14)
- **Website** in `website/` (Vite + React 19 + Tailwind 4, gleiches Gerüst/Design wie sketchy-Website). Lokal: `npm --prefix website run dev` (Port 5179 via `.claude/launch.json`).
  - **Version A** (`/`): eigener Nachbau des React-Bits-Pro-Hintergrunds „Spectral Drape“ (Code ist Paywall → selbst geschrieben, nach Davids Bildschirmaufnahme abgestimmt: frontales Punkteraster, Stoff-Falten, Flattern, Brush, Click-Ripples, Parallax). Punktfarben laufen langsam durch die Agentenpalette (`NOSY_PALETTE`). Cursor = Notch-Pille, die sich um Buttons legt.
  - **Version B** (`/b/`): „Nosy“-Konzept: Strichfeld, das zum Cursor schaut (ohne Maus zur Notch), große Notch mit Augen, Funken-Cursor mit Spur.
  - Gemeinsam: Demo-Player (GIFs als MP4 in `public/demo`, ~5 MB), Download-Menü als Notch auf Mac-Screen (Deny / Download .app / Allow kopiert `npx nosynotch` + Konfetti; Deny = beleidigte Augen), Docs unter `/docs/`.
  - `?tick` in der URL rendert Canvas auch im versteckten Tab (nur für Screenshots beim Tunen).
- Offen: David wählt A oder B, dann B/A entfernen; Hintergrund-Bewegung live begutachten; Repo public, `NPM_TOKEN`, Tag v0.2.0; Deploy auf Vercel (`nosynotch.davidkubus.dev`).

## 2026-11-05 (13)
- **CI repariert**: seit „live equalizer“ (7 Runs) rot. Ursache: `macos-15`-Runner baut mit Xcode 16.4 / Swift 6.1, der bei den `TimelineView`+`Canvas`-Animationen (MediaViews, ClaudeSpark, …) mit „unable to type-check … in reasonable time“ abbricht. Lokal (Swift 6.4) kein Problem.
- Entscheidung: Runner auf `macos-26` (aktuelles Xcode) statt jede Animation blind über CI-Runden umzubauen. Zusätzlich Balkenhöhe im Live-Equalizer in eigene Funktion ausgelagert (harmlos, bleibt drin).
- Offen: `actions/checkout@v4` / `upload-artifact@v4` laufen auf Node 20 (Deprecation-Warnung) → bei Gelegenheit auf v5 heben.

## 2026-11-05 (12)
- Codex und Cursor haben jetzt auch **in der Notch** eigene Symbole (Leiste, Sitzungsliste, Settings), abhängig vom Zustand: Codex-Sechseck läuft schneller beim Arbeiten, rückwärts beim Komprimieren, pulsiert beim Warten; Cursor = isometrischer Würfel (an Cursors Logo angelehnt, nicht kopiert), dreht sich beim Arbeiten.
- GIFs mit Codex/Cursor neu: `codex`, `hover`, `usage`, `settings`.
- Frage FPS im Aufnahmefenster: liegt am Recorder (30× pro Sekunde `cacheDisplay` in 2× + PNG auf dem Main-Thread), nicht an der App.

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
