#!/usr/bin/env bash
# Installs the Flutter SDK (stable) for headless development.
# Usable as the setup script of a Claude Code cloud environment, in a
# GitHub Codespace (.devcontainer) or on any Linux box.
set -euo pipefail

FLUTTER_DIR="${FLUTTER_DIR:-/opt/flutter}"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  base=https://storage.googleapis.com/flutter_infra_release/releases
  archive=$(curl -fsSL "$base/releases_linux.json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
h = d["current_release"]["stable"]
print(next(r["archive"] for r in d["releases"] if r["hash"] == h))')
  echo "Installing Flutter from $archive"
  mkdir -p "$(dirname "$FLUTTER_DIR")"
  curl -fsSL "$base/$archive" | tar -xJ -C "$(dirname "$FLUTTER_DIR")"
fi

git config --global --add safe.directory "$FLUTTER_DIR"
export PATH="$FLUTTER_DIR/bin:$PATH"
grep -q "$FLUTTER_DIR/bin" ~/.bashrc 2>/dev/null ||
  echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> ~/.bashrc

flutter config --no-analytics --enable-web >/dev/null
flutter precache --web
flutter --version
