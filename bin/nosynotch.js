#!/usr/bin/env node
// nosynotch CLI – installs, starts and manages Nosy Notch. No dependencies.
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn, spawnSync } = require('child_process');

const pkg = require('../package.json');
const PKG_ROOT = path.resolve(__dirname, '..');
// GitHub repository that hosts the release binaries.
const REPO = 'ddkbs/nosynotch';
const PORT = 7823;
const BASE = `http://127.0.0.1:${PORT}`;
const LABEL = 'dev.davidkubus.nosynotch';
const MARKER = 'nosynotch';
// Names used before the rename to Nosy Notch – cleaned up automatically.
const LEGACY = { marker: 'claude-notch', label: 'dev.davidkubus.claude-notch', process: 'ClaudeNotch', dir: '.claude-notch' };

const HOME = os.homedir();
const DATA_DIR = path.join(HOME, '.nosynotch');
const APP = path.join(DATA_DIR, 'Nosy Notch.app');
const BINARY = path.join(APP, 'Contents', 'MacOS', 'NosyNotch');
const VERSION_FILE = path.join(DATA_DIR, 'version');
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

// Codex (CLI and the Codex mode of the ChatGPT app): ~/.codex/hooks.json. [event, matcher, timeout in s]
const CODEX_EVENTS = [
  ['SessionStart', null, 5],
  ['SessionEnd', null, 3], // Codex caps SessionEnd and Interrupt at 3 s
  ['UserPromptSubmit', null, 5],
  ['PreToolUse', '*', 5],
  ['PostToolUse', '*', 5],
  ['PermissionRequest', '*', 5],
  ['Stop', null, 5],
  ['Interrupt', null, 3],
  ['SubagentStop', null, 5],
  ['PreCompact', null, 5],
];

// Must stay identical to HookInstaller.command(port:agent:) in the Swift app.
// X-Host-Pid lets the app find the exact app instance a session runs in. Not for Codex (changed hooks need re-trust).
const hostPid = (agent) => (agent === 'codex' ? [] : ['-H "X-Host-Pid: $PPID"']);
const hookCommand = (agent = 'claude') =>
  [
    'curl -s -m 2 -X POST',
    "-H 'Content-Type: application/json'",
    "-H 'Expect:'",
    '-H "X-Term-Program: ${TERM_PROGRAM:-}"',
    '-H "X-Bundle-Id: ${__CFBundleIdentifier:-}"',
    ...hostPid(agent),
    '--data-binary @-',
    `'http://127.0.0.1:${PORT}/event?src=${MARKER}${agent === 'claude' ? '' : `&agent=${agent}`}'`,
    '>/dev/null 2>&1 || true',
  ].join(' ');

// Shared secret with the app (see Approvals.swift): the permission hook only prints answers that start with it.
const TOKEN_FILE = path.join(DATA_DIR, 'approval-token');
function approvalToken() {
  try {
    const existing = fs.readFileSync(TOKEN_FILE, 'utf8').trim();
    if (/^[0-9a-f]{16,}$/i.test(existing)) return existing;
  } catch {}
  const token = require('crypto').randomBytes(16).toString('hex');
  fs.mkdirSync(DATA_DIR, { recursive: true });
  fs.writeFileSync(TOKEN_FILE, token, { mode: 0o600 });
  return token;
}

// The PermissionRequest hook waits for Allow / Deny from the notch. Must match HookInstaller.permissionCommand.
const permissionCommand = (agent = 'claude') => {
  const token = approvalToken();
  return [
    'r=$(curl -s -m 590 -X POST',
    "-H 'Content-Type: application/json'",
    "-H 'Expect:'",
    '-H "X-Term-Program: ${TERM_PROGRAM:-}"',
    '-H "X-Bundle-Id: ${__CFBundleIdentifier:-}"',
    ...hostPid(agent),
    '--data-binary @-',
    `'http://127.0.0.1:${PORT}/permission?src=${MARKER}${agent === 'claude' ? '' : `&agent=${agent}`}'`,
    '2>/dev/null);',
    `case "$r" in "${token} "*) printf '%s' "\${r#${token} }";; esac; true`,
  ].join(' ');
};
// Claude Code only passes usage limits to its status line – a silent one forwards them (only if you have none).
// Must match HookInstaller.statusLineCommand.
const STATUS_LINE_COMMAND =
  "curl -s -m 1 -X POST -H 'Content-Type: application/json' -H 'Expect:' --data-binary @- " +
  `'http://127.0.0.1:${PORT}/usage?src=${MARKER}' >/dev/null 2>&1; true`;
// Cursor's agent: ~/.cursor/hooks.json, camelCase events, JSON expected on stdout. Must match HookInstaller.Cursor.
const CURSOR_EVENTS = [
  'sessionStart', 'sessionEnd', 'beforeSubmitPrompt', 'preToolUse', 'postToolUse', 'postToolUseFailure',
  'afterAgentResponse', 'stop', 'subagentStop', 'preCompact',
  'beforeShellExecution', 'beforeMCPExecution',
];
const CURSOR_PERMISSION_EVENTS = new Set(['beforeShellExecution', 'beforeMCPExecution']);
const cursorCommand = (event) =>
  CURSOR_PERMISSION_EVENTS.has(event) ? cursorPermissionCommand() : [
    'curl -s -m 2 -X POST',
    "-H 'Content-Type: application/json'",
    "-H 'Expect:'",
    '-H "X-Term-Program: ${TERM_PROGRAM:-}"',
    '-H "X-Bundle-Id: ${__CFBundleIdentifier:-}"',
    '-H "X-Host-Pid: $PPID"',
    '--data-binary @-',
    `'http://127.0.0.1:${PORT}/event?src=${MARKER}&agent=cursor'`,
    `>/dev/null 2>&1; printf '%s' '${event === 'beforeSubmitPrompt' ? '{"continue":true}' : '{}'}'`,
  ].join(' ');
// Waits for Allow / Deny in the notch, prints `{}` when there's no decision. Must match HookInstaller.Cursor.
function cursorPermissionCommand() {
  const token = approvalToken();
  return [
    'r=$(curl -s -m 55 -X POST',
    "-H 'Content-Type: application/json'",
    "-H 'Expect:'",
    '-H "X-Term-Program: ${TERM_PROGRAM:-}"',
    '-H "X-Bundle-Id: ${__CFBundleIdentifier:-}"',
    '-H "X-Host-Pid: $PPID"',
    '--data-binary @-',
    `'http://127.0.0.1:${PORT}/permission?src=${MARKER}&agent=cursor'`,
    '2>/dev/null);',
    `case "$r" in "${token} "*) printf '%s' "\${r#${token} }";; *) printf '%s' '{}';; esac`,
  ].join(' ');
}
const cursorDir = () => path.join(HOME, '.cursor');
const cursorAvailable = () => fs.existsSync(cursorDir()) || fs.existsSync('/Applications/Cursor.app');
const cursorHooksFile = () => path.join(cursorDir(), 'hooks.json');
const ownEntry = (e) => typeof e?.command === 'string' && e.command.includes(MARKER);
function cursorHooksInstalled() {
  const hooks = readSettings(cursorHooksFile()).hooks || {};
  return CURSOR_EVENTS.every((name) => (hooks[name] || []).some((e) => e?.command === cursorCommand(name)));
}
function installCursorHooks() {
  const file = cursorHooksFile();
  const settings = readSettings(file);
  const hooks = settings.hooks || {};
  for (const name of CURSOR_EVENTS) hooks[name] = [...(hooks[name] || []).filter((e) => !ownEntry(e)), { command: cursorCommand(name), timeout: CURSOR_PERMISSION_EVENTS.has(name) ? 60 : 5 }];
  settings.version = settings.version ?? 1;
  settings.hooks = hooks;
  writeSettings(file, settings);
  ok(`Hooks added to ${pretty(file)}`);
}
function removeCursorHooks() {
  const file = cursorHooksFile();
  if (!fs.existsSync(file)) return;
  const settings = readSettings(file);
  if (!settings.hooks) return;
  for (const name of Object.keys(settings.hooks)) {
    if (!Array.isArray(settings.hooks[name])) continue;
    const rest = settings.hooks[name].filter((e) => !ownEntry(e));
    if (rest.length) settings.hooks[name] = rest;
    else delete settings.hooks[name];
  }
  writeSettings(file, settings);
  ok(`Hooks removed from ${pretty(file)}.`);
}

const commandFor = (event, agent) => (event === 'PermissionRequest' ? permissionCommand(agent) : hookCommand(agent));
const timeoutFor = (event, fallback = 5) => (event === 'PermissionRequest' ? 600 : fallback);

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
  if (await isRunning()) return ok('Nosy Notch is already running.');
  const child = spawn(BINARY, [], { detached: true, stdio: 'ignore' });
  child.unref();
  for (let i = 0; i < 30; i++) {
    await sleep(150);
    if (await isRunning()) return ok(`Nosy Notch is running ${dim(`(${BASE})`)}`);
  }
  fail(`The app did not respond. Is something else using port ${PORT}?\n  Try it directly: "${BINARY}"`);
}

async function openSettings() {
  if (!(await isRunning())) fail('Nosy Notch is not running – start it with `npx nosynotch`.');
  await fetch(`${BASE}/settings`, { method: 'POST', signal: AbortSignal.timeout(800) });
  ok('Settings opened.');
}

async function stop({ quiet = false } = {}) {
  let stopped = false;
  try {
    const res = await fetch(`${BASE}/quit`, { method: 'POST', signal: AbortSignal.timeout(800) });
    stopped = res.ok;
  } catch {}
  if (!stopped) stopped = run('/usr/bin/pkill', ['-x', 'NosyNotch']).status === 0;
  if (stopped) await sleep(400);
  if (!quiet) stopped ? ok('Nosy Notch stopped.') : info('Nosy Notch was not running.');
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
    ok(`Nosy Notch ${pkg.version} installed ${dim(`→ ${APP}`)}`);
  } finally {
    fs.rmSync(work, { recursive: true, force: true });
  }
}

/** Fetch the prebuilt universal binary from GitHub Releases. Returns its path or null. */
async function download(work) {
  const url = `https://github.com/${REPO}/releases/download/v${pkg.version}/NosyNotch-macos.tar.gz`;
  info(`Downloading Nosy Notch ${pkg.version} …`);
  try {
    const res = await fetch(url, { redirect: 'follow', signal: AbortSignal.timeout(60_000) });
    if (!res.ok) {
      console.log(dim(`  No release found (${res.status}).`));
      return null;
    }
    const archive = path.join(work, 'NosyNotch.tar.gz');
    fs.writeFileSync(archive, Buffer.from(await res.arrayBuffer()));
    if (run('/usr/bin/tar', ['-xzf', archive, '-C', work]).status !== 0) return null;
    const binary = path.join(work, 'NosyNotch');
    return fs.existsSync(binary) ? binary : null;
  } catch (e) {
    console.log(dim(`  Download failed (${e.message}).`));
    return null;
  }
}

/** Fallback: compile locally with the Swift toolchain (Xcode Command Line Tools). */
function buildFromSource(work) {
  if (!has('swift')) {
    fail(
      'No prebuilt release available and no Swift compiler found.\n' +
        `  Install the (free) Xcode Command Line Tools: ${bold('xcode-select --install')}\n` +
        '  and run `npx nosynotch` again.'
    );
  }
  info('Compiling from source (one-time, ~1 min) …');
  const src = path.join(work, 'src');
  fs.mkdirSync(src);
  for (const entry of ['Package.swift', 'Sources']) {
    fs.cpSync(path.join(PKG_ROOT, entry), path.join(src, entry), { recursive: true });
  }
  const build = run('swift', ['build', '-c', 'release'], { cwd: src, stdio: 'inherit' });
  if (build.status !== 0) fail('Build failed (see output above).');
  const binPath = spawnSync('swift', ['build', '-c', 'release', '--show-bin-path'], { cwd: src, encoding: 'utf8' })
    .stdout.trim();
  return path.join(binPath, 'NosyNotch');
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

/**
 * Every Claude Code config directory: ~/.claude, $CLAUDE_CONFIG_DIR and ~/.claude-* folders that look
 * like one (people with several accounts point CLAUDE_CONFIG_DIR at e.g. ~/.claude-work).
 * Must stay in sync with HookInstaller.configDirectories in the Swift app.
 */
function configDirs() {
  const dirs = [path.join(HOME, '.claude')];
  const env = process.env.CLAUDE_CONFIG_DIR;
  if (env) dirs.push(path.resolve(env.replace(/^~(?=$|\/)/, HOME)));
  for (const name of fs.readdirSync(HOME).sort()) {
    if (!/^\.claude[-_]/.test(name) || name === '.claude-notch') continue;
    const dir = path.join(HOME, name);
    if (['settings.json', 'projects', '.credentials.json'].some((f) => fs.existsSync(path.join(dir, f)))) dirs.push(dir);
  }
  const seen = new Set();
  return dirs.filter((d) => {
    let real = d;
    try {
      real = fs.realpathSync(d);
    } catch {}
    if (seen.has(real)) return false;
    seen.add(real);
    return true;
  });
}

const settingsFiles = () => configDirs().map((d) => path.join(d, 'settings.json'));
const pretty = (p) => p.replace(HOME, '~');

function readSettings(file) {
  if (!fs.existsSync(file)) return {};
  const text = fs.readFileSync(file, 'utf8');
  if (!text.trim()) return {};
  try {
    return JSON.parse(text);
  } catch (e) {
    fail(`${file} is not valid JSON (${e.message}). Please check it manually.`);
  }
}

function writeSettings(file, settings) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  // Keep the file as it was before we touched it: once our hooks are in, the backup isn't replaced again.
  if (fs.existsSync(file)) {
    const backup = `${file}.nosynotch.bak`;
    const touched = [MARKER, LEGACY.marker].some((m) => fs.readFileSync(file, 'utf8').includes(m));
    if (!touched || !fs.existsSync(backup)) fs.copyFileSync(file, backup);
  }
  fs.writeFileSync(file, JSON.stringify(settings, null, 2) + '\n');
}

const isOurs = (group) =>
  Array.isArray(group?.hooks) &&
  group.hooks.some((h) => typeof h?.command === 'string' && [MARKER, LEGACY.marker].some((m) => h.command.includes(m)));

// Only the current command counts – hooks from an older version get replaced.
const isCurrent = (command) => (group) => Array.isArray(group?.hooks) && group.hooks.some((h) => h?.command === command);

function hooksInstalledIn(file, events = HOOK_EVENTS, agent = 'claude') {
  const hooks = readSettings(file).hooks || {};
  return events.every(([name]) => (hooks[name] || []).some(isCurrent(commandFor(name, agent))));
}

const codexHome = () => {
  const env = process.env.CODEX_HOME;
  return env ? env.replace(/^~(?=$|\/)/, HOME) : path.join(HOME, '.codex');
};
const codexAvailable = () => fs.existsSync(codexHome());
const codexHooksFile = () => path.join(codexHome(), 'hooks.json');
const codexHooksInstalled = () => hooksInstalledIn(codexHooksFile(), CODEX_EVENTS, 'codex');

const hooksInstalled = () =>
  settingsFiles().every((f) => hooksInstalledIn(f)) &&
  (!codexAvailable() || codexHooksInstalled()) &&
  (!cursorAvailable() || cursorHooksInstalled());

function installHooks() {
  for (const file of settingsFiles()) installHooksIn(file);
  console.log(dim('  Restart Claude Code sessions that are already running so they pick up the hooks.'));
  if (codexAvailable()) {
    installHooksIn(codexHooksFile(), CODEX_EVENTS, 'codex');
    console.log(dim('  Codex runs new hooks only after you trust them once:'));
    console.log(dim('  ChatGPT app → Codex → Settings → Hooks, or type /hooks in the Codex CLI.'));
  }
  if (cursorAvailable()) installCursorHooks();
}

function installHooksIn(file, events = HOOK_EVENTS, agent = 'claude') {
  const settings = readSettings(file);
  const hooks = settings.hooks || {};
  for (const [name, matcher, timeout = 5] of events) {
    const groups = (hooks[name] || []).filter((g) => !isOurs(g));
    const group = { hooks: [{ type: 'command', command: commandFor(name, agent), timeout: timeoutFor(name, timeout) }] };
    if (matcher) group.matcher = matcher;
    groups.push(group);
    hooks[name] = groups;
  }
  settings.hooks = hooks;
  if (agent === 'claude' && !settings.statusLine) settings.statusLine = { type: 'command', command: STATUS_LINE_COMMAND };
  writeSettings(file, settings);
  ok(`Hooks added to ${pretty(file)} ${dim(`(backup: ${path.basename(file)}.nosynotch.bak)`)}`);
}

function removeHooks() {
  for (const file of settingsFiles()) removeHooksIn(file);
  removeHooksIn(codexHooksFile());
  removeCursorHooks();
}

function removeHooksIn(file) {
  if (!fs.existsSync(file)) return;
  const settings = readSettings(file);
  const ownStatusLine = typeof settings.statusLine?.command === 'string' && settings.statusLine.command.includes(MARKER);
  if (ownStatusLine) delete settings.statusLine;
  if (!settings.hooks && !ownStatusLine) return;
  settings.hooks = settings.hooks || {};
  for (const name of Object.keys(settings.hooks)) {
    const groups = Array.isArray(settings.hooks[name]) ? settings.hooks[name].filter((g) => !isOurs(g)) : settings.hooks[name];
    if (Array.isArray(groups) && groups.length === 0) delete settings.hooks[name];
    else settings.hooks[name] = groups;
  }
  if (Object.keys(settings.hooks).length === 0) delete settings.hooks;
  writeSettings(file, settings);
  ok(`Hooks removed from ${pretty(file)}.`);
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
    ok('Autostart at login enabled.');
  } else if (fs.existsSync(LAUNCH_AGENT)) {
    run('/bin/launchctl', ['bootout', `${domain}/${LABEL}`]);
    fs.rmSync(LAUNCH_AGENT);
    ok('Autostart disabled.');
  } else {
    info('Autostart was not enabled.');
  }
}

// ───────────────────────────── migration from claude-notch ─────────────────────────────

/** Removes what the pre-rename version (claude-notch) left behind and keeps its autostart setting. */
function migrateLegacy() {
  const oldAgent = path.join(HOME, 'Library', 'LaunchAgents', `${LEGACY.label}.plist`);
  const oldDir = path.join(HOME, LEGACY.dir);
  const hadAutostart = fs.existsSync(oldAgent);
  // An old app would keep port 7823 busy.
  const killed = run('/usr/bin/pkill', ['-x', LEGACY.process]).status === 0;
  if (!hadAutostart && !fs.existsSync(oldDir)) return false;

  info('Migrating from claude-notch to Nosy Notch …');
  if (killed) run('/bin/sleep', ['0.4']);
  if (hadAutostart) {
    run('/bin/launchctl', ['bootout', `gui/${process.getuid()}/${LEGACY.label}`]);
    fs.rmSync(oldAgent, { force: true });
  }
  fs.rmSync(oldDir, { recursive: true, force: true });
  return hadAutostart;
}

// ───────────────────────────── demo ─────────────────────────────

async function demo() {
  if (!(await isRunning())) fail('Nosy Notch is not running – start it with `npx nosynotch`.');
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
    [1500, 'Stop', { last_assistant_message: 'Parser refactored – all 42 tests pass.' }],
    [8000, 'SessionEnd'],
  ];
  info('Playing the demo – watch your notch …');
  for (const [delay, name, extra] of steps) {
    await sleep(delay);
    await send(name, extra);
  }
  ok('Demo finished.');
}

// ───────────────────────────── commands ─────────────────────────────

async function status() {
  const running = await isRunning();
  console.log(`${bold('Nosy Notch')} ${dim(pkg.version)}`);
  console.log(`  App:        ${running ? green('running') : dim('stopped')}  ${dim(installedVersion() ? APP : 'not installed')}`);
  const files = settingsFiles();
  files.forEach((file, i) => {
    const label = i === 0 ? '  Hooks:      ' : '              ';
    console.log(`${label}${hooksInstalledIn(file) ? green('✓') : dim('–')} ${pretty(path.dirname(file))}`);
  });
  if (codexAvailable()) {
    console.log(`  Codex:      ${codexHooksInstalled() ? green('✓') : dim('–')} ${pretty(codexHooksFile())}`);
  }
  if (cursorAvailable()) {
    console.log(`  Cursor:     ${cursorHooksInstalled() ? green('✓') : dim('–')} ${pretty(cursorHooksFile())}`);
  }
  console.log(`  Autostart:  ${fs.existsSync(LAUNCH_AGENT) ? green('on') : dim('off')}`);
}

function help() {
  console.log(`${orange('✦')} ${bold('nosynotch')} ${dim(pkg.version)} – Claude Code, Codex & Cursor in your MacBook notch

  ${bold('npx nosynotch')}              install (if needed), add hooks, start
  ${bold('npx nosynotch stop')}         stop
  ${bold('npx nosynotch restart')}      restart
  ${bold('npx nosynotch status')}       show status
  ${bold('npx nosynotch settings')}     open the settings window
  ${bold('npx nosynotch demo')}         play every animation
  ${bold('npx nosynotch autostart')}    start at login      ${dim('(autostart off to disable)')}
  ${bold('npx nosynotch hooks')}        only add the hooks  ${dim('(hooks off to remove)')}
  ${bold('npx nosynotch update')}       download the latest binary
  ${bold('npx nosynotch uninstall')}    remove everything (app, hooks, autostart)
`);
}

async function main() {
  const [cmd = 'start', arg] = process.argv.slice(2);
  const off = arg === 'off' || arg === 'remove';

  if (['help', '--help', '-h'].includes(cmd)) return help();
  if (['--version', '-v'].includes(cmd)) return console.log(pkg.version);
  if (process.platform !== 'darwin') fail('nosynotch only runs on macOS.');

  switch (cmd) {
    case 'start': {
      const hadAutostart = migrateLegacy();
      await ensureApp();
      if (hadAutostart) autostart(true);
      if (!hooksInstalled()) installHooks();
      await start();
      console.log(`\n  ${bold('Done!')} Look at your notch the next time Claude, Codex or Cursor works.`);
      console.log(dim('  Settings: click ✦ in the menu bar → Settings…  (or `npx nosynotch settings`)'));
      console.log(dim('  Try it:   `npx nosynotch demo` plays every animation.'));
      break;
    }
    case 'stop':
      await stop();
      break;
    case 'settings':
      await openSettings();
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
      migrateLegacy();
      removeHooks();
      if (fs.existsSync(LAUNCH_AGENT)) autostart(false);
      fs.rmSync(DATA_DIR, { recursive: true, force: true });
      ok('Nosy Notch completely removed.');
      break;
    default:
      help();
      process.exitCode = 1;
  }
}

main().catch((e) => fail(e.stack || String(e)));
