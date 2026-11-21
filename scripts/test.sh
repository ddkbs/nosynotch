#!/usr/bin/env bash
# Run characterization tests with Xcode or standalone Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")/.."

TEST_SWIFT_ARGS=(--disable-xctest)
developer_dir="$(xcode-select -p)"
if [[ "$developer_dir" == */CommandLineTools ]]; then
  if [[ -z "${SDKROOT:-}" && -d "$developer_dir/SDKs/MacOSX26.5.sdk" ]]; then
    export SDKROOT="$developer_dir/SDKs/MacOSX26.5.sdk"
  fi
  # SwiftBuild can omit this plugin during incremental module emission.
  testing_plugin="$developer_dir/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
  if [[ -f "$testing_plugin" ]]; then
    TEST_SWIFT_ARGS+=(-Xswiftc -load-plugin-library -Xswiftc "$testing_plugin")
  fi
fi
swift test "${TEST_SWIFT_ARGS[@]}" "$@"
