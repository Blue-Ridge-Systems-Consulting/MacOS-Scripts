#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCE="$ROOT/macOS-Northstar-AV"
VERSION="${1:-$(tr -d '[:space:]' < "$SOURCE/update-channel/VERSION")}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Version must be semantic, e.g. 1.0.0" >&2; exit 64; }

OUT="$ROOT/dist/northstar-guard-$VERSION"
rm -rf "$OUT"
mkdir -p "$OUT"
BUNDLE="$OUT/northstar-guard-$VERSION.tar.gz"
tar -czf "$BUNDLE" -C "$ROOT" macOS-Northstar-AV
SHA256="$(shasum -a 256 "$BUNDLE" | awk '{print $1}')"

python3 - "$OUT/release-manifest.json" "$VERSION" "$(basename "$BUNDLE")" "$SHA256" <<'PY'
import json, sys
path, version, bundle, sha256 = sys.argv[1:]
payload = {
    "schema": "northstar-release/v1",
    "product": "Northstar Guard",
    "version": version,
    "bundle": bundle,
    "sha256": sha256,
    "upgrade": {
        "macos": "macOS-Northstar-AV/install-northstar-guard.sh --upgrade",
        "fedora": "macOS-Northstar-AV/fedora-cosmic/install.sh --upgrade",
        "linux": "macOS-Northstar-AV/server-headless/install.sh --upgrade"
    }
}
with open(path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
PY
printf 'Built %s\nManifest: %s\n' "$BUNDLE" "$OUT/release-manifest.json"
