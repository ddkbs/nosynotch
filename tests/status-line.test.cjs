const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const { spawnSync } = require('node:child_process');

const source = fs.readFileSync(path.join(__dirname, '../bin/nosynotch.js'), 'utf8');
const helpers = source.slice(source.indexOf('const STATUS_LINE_COMMAND ='), source.indexOf("// Cursor's agent:"));
function harness(current) {
  const context = vm.createContext({ PORT: 7823, MARKER: 'nosynotch', current });
  vm.runInContext(helpers, context);
  return { context, install: () => vm.runInContext('usageStatusLine(current)', context) };
}

test('preserves options and wraps only once across reinstalls', () => {
  const original = { type: 'command', command: 'cat', padding: 3 };
  const h = harness(original);
  const wrapped = h.install();
  assert.equal(wrapped.padding, 3);
  assert.equal(wrapped.nosynotchOriginalStatusLine, original);
  h.context.current = wrapped;
  assert.equal(h.install().command, wrapped.command);
});

test('forwards identical JSON and preserves custom stdout, stderr and exit status even if curl fails', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'nosy-status-'));
  try {
    fs.writeFileSync(path.join(dir, 'curl'), '#!/bin/sh\ncat > "$NOSY_CAPTURE"\nexit 7\n', { mode: 0o700 });
    const original = { type: 'command', command: `cat; printf "it's visible\\n"; printf 'diagnostic' >&2; exit 23` };
    const { command } = harness(original).install();
    const input = '{"rate_limits":{"five_hour":{"used_percentage":42}},"text":"`$()"}\n\n';
    const result = spawnSync('/bin/sh', ['-c', command], {
      input, encoding: 'utf8', env: { ...process.env, PATH: `${dir}:${process.env.PATH}`, NOSY_CAPTURE: path.join(dir, 'payload') },
    });
    assert.equal(fs.readFileSync(path.join(dir, 'payload'), 'utf8'), input);
    assert.equal(result.stdout, input + "it's visible\n");
    assert.equal(result.stderr, 'diagnostic');
    assert.equal(result.status, 23);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('uninstall restores the exact original configuration', () => {
  const original = { type: 'command', command: 'cat', padding: 2 };
  const h = harness(original);
  const settings = { statusLine: h.install() };
  Object.assign(h.context, {
    fs: { existsSync: () => true }, readSettings: () => settings,
    writeSettings: () => {}, ok: () => {}, pretty: () => '', dim: () => '',
  });
  const start = source.indexOf('function removeHooksIn(');
  const end = source.indexOf('\nfunction ', start + 1);
  vm.runInContext(source.slice(start, end), h.context);
  vm.runInContext("removeHooksIn('settings.json')", h.context);
  assert.equal(settings.statusLine, original);
});

test('keeps unsupported formats and supports an absent or legacy silent status line', () => {
  const custom = { type: 'future', command: 'cat' };
  assert.equal(harness(custom).install(), custom);
  const first = harness(undefined).install();
  const next = harness(first).install();
  assert.equal(first.command, next.command);
  assert.equal(next.nosynotchOriginalStatusLine, undefined);
});
