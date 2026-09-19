#!/usr/bin/env bash
set -euo pipefail

manifest="${1:-}"
bundle="${2:-}"
[[ -r "$manifest" && -r "$bundle" ]] || { echo "Usage: $0 release-manifest.json bundle.tar.gz" >&2; exit 64; }

read -r expected actual version <<EOF
$(python3 - "$manifest" "$bundle" <<'PY'
import hashlib, json, pathlib, sys
manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
bundle = pathlib.Path(sys.argv[2])
actual = hashlib.sha256(bundle.read_bytes()).hexdigest()
print(manifest["sha256"], actual, manifest["version"])
PY
)
EOF
[[ "$expected" == "$actual" ]] || { echo "Checksum mismatch" >&2; exit 1; }

if tar -tzf "$bundle" | awk '$0 ~ /^\// || $0 ~ /(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}'; then :; else
    echo "Unsafe archive paths detected" >&2
    exit 1
fi

printf 'Verified Northstar Guard %s (%s)\n' "$version" "$actual"
