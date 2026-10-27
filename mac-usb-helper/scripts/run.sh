#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
xcodebuild -scheme LanUSBHelper -configuration Debug -derivedDataPath "$ROOT/build" build
exec "$ROOT/build/Build/Products/Debug/LanUSBHelper" "$@"
