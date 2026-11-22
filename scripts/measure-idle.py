#!/usr/bin/env python3
"""Record a manually controlled macOS CPU scenario; never assert an absolute CPU limit."""
import argparse
import datetime
import json
import platform
import re
import subprocess
import urllib.request
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scenario', required=True, choices=[
        'compact-idle', 'compact-active', 'hidden-stationary', 'hidden-moving-pointer', 'expanded', 'closing', 'paused-media', 'minimized-settings'])
    parser.add_argument('--pid', type=int)
    parser.add_argument('--samples', type=int, default=7, help='Includes an initial sample that is discarded')
    parser.add_argument('--interval', type=int, default=5)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--diagnostics-url', help='Optional local /diagnostics endpoint to verify UI state')
    args = parser.parse_args()
    if args.samples < 2 or args.interval < 1:
        parser.error('Use at least two samples and an interval of at least one second')
    pid = args.pid
    if pid is None:
        matches = subprocess.check_output(['pgrep', '-x', 'NosyNotch'], text=True).split()
        if len(matches) != 1:
            parser.error('Expected exactly one NosyNotch instance; use --pid')
        pid = int(matches[0])
    command = subprocess.check_output(['ps', '-p', str(pid), '-o', 'comm='], text=True).strip()
    def ui_state():
        if not args.diagnostics_url:
            return None
        try:
            with urllib.request.urlopen(args.diagnostics_url, timeout=2) as response:
                return json.load(response)
        except Exception as error:
            return {'error': str(error)}

    state_before = ui_state()
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    result = subprocess.run(['/usr/bin/top', '-l', str(args.samples), '-s', str(args.interval),
                             '-pid', str(pid), '-stats', 'pid,cpu,time,threads'],
                            check=True, capture_output=True, text=True)
    rows = re.findall(r'^\s*' + str(pid) + r'\s+([\d.]+)\s+(\S+)\s+(\S+)', result.stdout, re.MULTILINE)
    if len(rows) != args.samples:
        raise RuntimeError(f'Expected {args.samples} samples, got {len(rows)}; app may have exited')
    cpu = [float(row[0]) for row in rows[1:]]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.with_suffix('.top.txt').write_text(result.stdout)
    report = {
        'started_at_utc': started, 'scenario_operator_supplied': args.scenario,
        'os': platform.platform(), 'pid': pid, 'command': command,
        'interval_seconds': args.interval, 'cpu_percent_samples': cpu,
        'mean_cpu_percent': sum(cpu) / len(cpu), 'max_cpu_percent': max(cpu),
        'ui_state_before': state_before, 'ui_state_after': ui_state(),
        'note': 'Initial top sample discarded. Visibility and pointer state must be controlled manually. '
                'Match settings and background workload across builds; CPU is not a pass/fail assertion.',
    }
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
