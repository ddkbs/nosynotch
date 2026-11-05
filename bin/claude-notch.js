#!/usr/bin/env node
// claude-notch CLI – installs, starts and manages the notch helper. No dependencies.
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn, spawnSync } = require('child_process');

const pkg = require('../package.json');
const PKG_ROOT = path.resolve(__dirname, '..');
const REPO = 'ddkbs/claude-notch';
const PORT = 7823;
const BASE = `http://127.0.0.1:${PORT}`;
const LABEL = 'dev.davidkubus.claude-notch';
const MARKER = 'claude-notch';

const HOME = os.homedir();
const DATA_DIR = path.join(HOME, '.claude-notch');
const APP = path.join(DATA_DIR, 'Claude Notch.app');
const BINARY = path.join(APP, 'Contents', 'MacOS', 'ClaudeNotch');
const VERSION_FILE = path.join(DATA_DIR, 'version');
const SETTINGS = path.join(HOME, '.claude', 'settings.json');
const LAUNCH_AGENT = path.join(HOME, 'Library', 'LaunchAgents', `${LABEL}.plist`);

const HOOK_EVENTS = [
  ['SessionStart', null],
  ['SessionEnd', null],
  ['UserPromptSubmit', null],
  ['PreToolUse', '*'],
  ['PostToolUse', '*'],
  ['PostToolUseFailure', '*'],
  ['PermissionRequest', '*'],
  ['Notification', null],
  ['Stop', null],
  ['StopFailure', null],
  ['SubagentStop', null],
  ['PreCompact', null],
];

// Must stay identical to HookInstaller.command(port:) in the Swift app.
const HOOK_COMMAND = [
  'curl -s -m 2 -X POST',
  "-H 'Content-Type: application/json'",
  "-H 'Expect:'",
  '-H "X-Term-Program: ${TERM_PROGRAM:-}"',
  '-H "X-Bundle-Id: ${__CFBundleIdentifier:-}"',
  '--data-binary @-',
  `'http://127.0.0.1:${PORT}/event?src=${MARKER}'`,
  '>/dev/null 2>&1 || true',
].join(' ');

// ───────────────────────────── output helpers ─────────────────────────────

const tty = process.stdout.isTTY;
const c = (code) => (s) => (tty ? `\x1b[${code}m${s}\x1b[0m` : s);
const orange = c('38;5;173');
const green = c('32');
const dim = c('2');
const red = c('31');
const bold = c('1');

const ok = (msg) => console.log(`${green('✓')} ${msg}`);
const info = (msg) => console.log(`${orange('✦')} ${msg}`);
const fail = (msg) => {
  console.error(`${red('✗')} ${msg}`);
  process.exit(1);
};

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const run = (cmd, args, opts = {}) => spawnSync(cmd, args, { stdio: 'ignore', ...opts });
const has = (cmd) => run('/usr/bin/which', [cmd]).status === 0;

// ───────────────────────────── app process ─────────────────────────────

async function isRunning() {
  try {
    const res = await fetch(`${BASE}/health`, { signal: AbortSignal.timeout(800) });
    return res.ok;
  } catch {
    return false;
  }
}

async function start() {
  if (await isRunning()) return ok('Claude Notch läuft bereits.');
  const child = spawn(BINARY, [], { detached: true, stdio: 'ignore' });
  child.unref();
  for (let i = 0; i < 30; i++) {
    await sleep(150);
    if (await isRunning()) return ok(`Claude Notch läuft ${dim(`(${BASE})`)}`);
  }
  fail(`Die App hat nicht geantwortet. Läuft schon etwas anderes auf Port ${PORT}?\n  Teste direkt: "${BINARY}"`);
}

async function stop({ quiet = false } = {}) {
  let stopped = false;
  try {
    const res = await fetch(`${BASE}/quit`, { method: 'POST', signal: AbortSignal.timeout(800) });
    stopped = res.ok;
  } catch {}
  if (!stopped) stopped = run('/usr/bin/pkill', ['-x', 'ClaudeNotch']).status === 0;
  if (stopped) await sleep(400);
  if (!quiet) stopped ? ok('Claude Notch beendet.') : info('Claude Notch lief nicht.');
}

// ───────────────────────────── installing the binary ─────────────────────────────

function installedVersion() {
  try {
    return fs.existsSync(BINARY) ? fs.readFileSync(VERSION_FILE, 'utf8').trim() : null;
  } catch {
    return null;
  }
}

async function ensureApp({ force = false } = {}) {
  if (!force && installedVersion() === pkg.version) return;

  fs.mkdirSync(DATA_DIR, { recursive: true });
  const work = fs.mkdtempSync(path.join(DATA_DIR, 'tmp-'));
  try {
    let binary = await download(work);
    if (!binary) binary = buildFromSource(work);
    assembleApp(binary);
    fs.writeFileSync(VERSION_FILE, pkg.version);
    ok(`Claude Notch ${pkg.version} installiert ${dim(`→ ${APP}`)}`);
  } finally {
    fs.rmSync(work, { recursive: true, force: true });
  }
}

/** Fetch the prebuilt universal binary from GitHub Releases. Returns its path or null. */
async function download(work) {
  const url = `https://github.com/${REPO}/releases/download/v${pkg.version}/ClaudeNotch-macos.tar.gz`;
  info(`Lade Claude Notch ${pkg.version} …`);
  try {
    const res = await fetch(url, { redirect: 'follow', signal: AbortSignal.timeout(60_000) });
    if (!res.ok) {
      console.log(dim(`  Kein Release gefunden (${res.status}).`));
      return null;
    }
    const archive = path.join(work, 'ClaudeNotch.tar.gz');
    fs.writeFileSync(archive, Buffer.from(await res.arrayBuffer()));
    if (run('/usr/bin/tar', ['-xzf', archive, '-C', work]).status !== 0) return null;
    const binary = path.join(work, 'ClaudeNotch');
    return fs.existsSync(binary) ? binary : null;
  } catch (e) {
    console.log(dim(`  Download fehlgeschlagen (${e.message}).`));
    return null;
  }
}

/** Fallback: compile locally with the Swift toolchain (Xcode Command Line Tools). */
function buildFromSource(work) {
  if (!has('swift')) {
    fail(
      'Kein fertiges Release verfügbar und kein Swift-Compiler gefunden.\n' +
        `  Installiere die (kostenlosen) Xcode Command Line Tools: ${bold('xcode-select --install')}\n` +
        '  und starte danach `npx claude-notch` erneut.'
    );
  }
  info('Kompiliere aus dem Quellcode (einmalig, ~1 Min.) …');
  const src = path.join(work, 'src');
  fs.mkdirSync(src);
  for (const entry of ['Package.swift', 'Sources']) {
    fs.cpSync(path.join(PKG_ROOT, entry), path.join(src, entry), { recursive: true });
  }
  const build = run('swift', ['build', '-c', 'release'], { cwd: src, stdio: 'inherit' });
  if (build.status !== 0) fail('Build fehlgeschlagen (siehe Ausgabe oben).');
  const binPath = spawnSync('swift', ['build', '-c', 'release', '--show-bin-path'], { cwd: src, encoding: 'utf8' })
    .stdout.trim();
  return path.join(binPath, 'ClaudeNotch');
}

/** Wrap the binary in a minimal .app bundle (needed for macOS notifications) and ad-hoc sign it. */
function assembleApp(binary) {
  fs.rmSync(APP, { recursive: true, force: true });
  fs.mkdirSync(path.dirname(BINARY), { recursive: true });
  fs.mkdirSync(path.join(APP, 'Contents', 'Resources'), { recursive: true });
  fs.copyFileSync(binary, BINARY);
  fs.chmodSync(BINARY, 0o755);
  fs.copyFileSync(path.join(PKG_ROOT, 'Resources', 'Info.plist'), path.join(APP, 'Contents', 'Info.plist'));
  // Ad-hoc signature – no Apple Developer account involved. Files fetched by Node carry no
  // quarantine flag, so Gatekeeper doesn't interfere; strip it anyway just in case.
  run('/usr/bin/codesign', ['--force', '--sign', '-', APP]);
  run('/usr/bin/xattr', ['-dr', 'com.apple.quarantine', APP]);
}

// ───────────────────────────── hooks ─────────────────────────────

function readSettings() {
  if (!fs.existsSync(SETTINGS)) return {};
  const text = fs.readFileSync(SETTINGS, 'utf8');
  if (!text.trim()) return {};
  try {
    return JSON.parse(text);
  } catch (e) {
    fail(`${SETTINGS} ist kein gültiges JSON (${e.message}). Bitte manuell prüfen.`);
  }
}

function writeSettings(settings) {
  fs.mkdirSync(path.dirname(SETTINGS), { recursive: true });
  if (fs.existsSync(SETTINGS)) fs.copyFileSync(SETTINGS, `${SETTINGS}.claude-notch.bak`);
  fs.writeFileSync(SETTINGS, JSON.stringify(settings, null, 2) + '\n');
}

const isOurs = (group) =>
  Array.isArray(group?.hooks) && group.hooks.some((h) => typeof h?.command === 'string' && h.command.includes(MARKER));

function hooksInstalled() {
  const hooks = readSettings().hooks || {};
  return HOOK_EVENTS.every(([name]) => (hooks[name] || []).some(isOurs));
}

function installHooks() {
  const settings = readSettings();
  const hooks = settings.hooks || {};
  for (const [name, matcher] of HOOK_EVENTS) {
    const groups = (hooks[name] || []).filter((g) => !isOurs(g));
    const group = { hooks: [{ type: 'command', command: HOOK_COMMAND, timeout: 5 }] };
    if (matcher) group.matcher = matcher;
    groups.push(group);
    hooks[name] = groups;
  }
  settings.hooks = hooks;
  writeSettings(settings);
  ok(`Hooks in ${SETTINGS.replace(HOME, '~')} eingetragen ${dim('(Backup: settings.json.claude-notch.bak)')}`);
  console.log(dim('  Bereits laufende Claude-Code-Sessions einmal neu starten, damit sie die Hooks laden.'));
}

function removeHooks() {
  if (!fs.existsSync(SETTINGS)) return;
  const settings = readSettings();
  if (!settings.hooks) return;
  for (const name of Object.keys(settings.hooks)) {
    const groups = Array.isArray(settings.hooks[name]) ? settings.hooks[name].filter((g) => !isOurs(g)) : settings.hooks[name];
    if (Array.isArray(groups) && groups.length === 0) delete settings.hooks[name];
    else settings.hooks[name] = groups;
  }
  if (Object.keys(settings.hooks).length === 0) delete settings.hooks;
  writeSettings(settings);
  ok('Hooks entfernt.');
}

// ───────────────────────────── autostart (LaunchAgent) ─────────────────────────────

function autostart(on) {
  const domain = `gui/${process.getuid()}`;
  if (on) {
    fs.mkdirSync(path.dirname(LAUNCH_AGENT), { recursive: true });
    fs.writeFileSync(
      LAUNCH_AGENT,
      `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${LABEL}</string>
  <key>ProgramArguments</key><array><string>${BINARY}</string></array>
  <key>RunAtLoad</key><true/>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
`
    );
    ok('Autostart beim Login aktiviert.');
  } else if (fs.existsSync(LAUNCH_AGENT)) {
    run('/bin/launchctl', ['bootout', `${domain}/${LABEL}`]);
    fs.rmSync(LAUNCH_AGENT);
    ok('Autostart deaktiviert.');
  } else {
    info('Autostart war nicht aktiv.');
  }
}

// ───────────────────────────── demo ─────────────────────────────

async function demo() {
  if (!(await isRunning())) fail('Claude Notch läuft nicht – starte es mit `npx claude-notch`.');
  const sid = `demo-${process.pid}`;
  const cwd = process.cwd();
  const send = (name, extra = {}) =>
    fetch(`${BASE}/event`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Term-Program': process.env.TERM_PROGRAM || '' },
      body: JSON.stringify({ hook_event_name: name, session_id: sid, cwd, ...extra }),
    });
  const steps = [
    [0, 'SessionStart'],
    [400, 'UserPromptSubmit', { prompt: 'Refactor the parser' }],
    [2500, 'PreToolUse', { tool_name: 'Grep', tool_input: { pattern: 'func parse' } }],
    [1200, 'PostToolUse', { tool_name: 'Grep' }],
    [800, 'PreToolUse', { tool_name: 'Edit', tool_input: { file_path: 'Sources/Parser.swift' } }],
    [1500, 'PostToolUse', { tool_name: 'Edit' }],
    [500, 'Notification', { message: 'Claude needs your permission to use Bash', notification_type: 'permission_prompt' }],
    [3500, 'PreToolUse', { tool_name: 'Bash', tool_input: { command: 'npm test', description: 'Run tests' } }],
    [2500, 'PostToolUse', { tool_name: 'Bash' }],
    [1500, 'Stop', { last_assistant_message: 'Parser refactored – alle 42 Tests grün.' }],
    [8000, 'SessionEnd'],
  ];
  info('Spiele Demo ab – schau auf die Notch …');
  for (const [delay, name, extra] of steps) {
    await sleep(delay);
    await send(name, extra);
  }
  ok('Demo fertig.');
}

// ───────────────────────────── commands ─────────────────────────────

async function status() {
  const running = await isRunning();
  console.log(`${bold('Claude Notch')} ${dim(pkg.version)}`);
  console.log(`  App:        ${running ? green('läuft') : dim('gestoppt')}  ${dim(installedVersion() ? APP : 'nicht installiert')}`);
  console.log(`  Hooks:      ${hooksInstalled() ? green('installiert') : dim('nicht installiert')}`);
  console.log(`  Autostart:  ${fs.existsSync(LAUNCH_AGENT) ? green('an') : dim('aus')}`);
}

function help() {
  console.log(`${orange('✦')} ${bold('claude-notch')} ${dim(pkg.version)} – Claude-Code-Status in der MacBook-Notch

  ${bold('npx claude-notch')}              installieren (falls nötig), Hooks eintragen, starten
  ${bold('npx claude-notch stop')}         beenden
  ${bold('npx claude-notch restart')}      neu starten
  ${bold('npx claude-notch status')}       Status anzeigen
  ${bold('npx claude-notch demo')}         alle Animationen vorführen
  ${bold('npx claude-notch autostart')}    beim Login starten  ${dim('(autostart off zum Abschalten)')}
  ${bold('npx claude-notch hooks')}        nur Hooks eintragen ${dim('(hooks off zum Entfernen)')}
  ${bold('npx claude-notch update')}       neueste Binary neu laden
  ${bold('npx claude-notch uninstall')}    alles entfernen (App, Hooks, Autostart)
`);
}

async function main() {
  const [cmd = 'start', arg] = process.argv.slice(2);
  const off = arg === 'off' || arg === 'remove';

  if (['help', '--help', '-h'].includes(cmd)) return help();
  if (['--version', '-v'].includes(cmd)) return console.log(pkg.version);
  if (process.platform !== 'darwin') fail('claude-notch läuft nur auf macOS.');

  switch (cmd) {
    case 'start':
      await ensureApp();
      if (!hooksInstalled()) installHooks();
      await start();
      console.log(dim('  Tipp: `npx claude-notch demo` zeigt alle Animationen, `npx claude-notch autostart` startet es beim Login.'));
      break;
    case 'stop':
      await stop();
      break;
    case 'restart':
      await stop({ quiet: true });
      await ensureApp();
      await start();
      break;
    case 'status':
      await status();
      break;
    case 'demo':
      await demo();
      break;
    case 'autostart':
      if (!off) await ensureApp();
      autostart(!off);
      break;
    case 'hooks':
    case 'install-hooks':
      off ? removeHooks() : installHooks();
      break;
    case 'uninstall-hooks':
      removeHooks();
      break;
    case 'update':
      await stop({ quiet: true });
      await ensureApp({ force: true });
      await start();
      break;
    case 'uninstall':
      await stop({ quiet: true });
      removeHooks();
      if (fs.existsSync(LAUNCH_AGENT)) autostart(false);
      fs.rmSync(DATA_DIR, { recursive: true, force: true });
      ok('Claude Notch komplett entfernt.');
      break;
    default:
      help();
      process.exitCode = 1;
  }
}

main().catch((e) => fail(e.stack || String(e)));
