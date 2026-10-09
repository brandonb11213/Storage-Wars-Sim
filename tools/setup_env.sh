#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/env.sh
mkdir -p "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$STORAGE_WARS_RUNTIME/godot"
release=https://github.com/godotengine/godot/releases/download/4.6.3-stable
if ! command -v godot >/dev/null || [[ "$(godot --version)" != 4.6.3.* ]]; then
  binary=Godot_v4.6.3-stable_linux.x86_64.zip
  curl -fsSL --retry 2 "$release/$binary" -o "$STORAGE_WARS_RUNTIME/$binary"
  (cd "$STORAGE_WARS_RUNTIME"; printf '%s  %s\n' a035258da32b77f966a5376f9fa29c30a6adde826a85ba918e1605bd1fc9823eba7d85f1dd5e748956bd2ba72827c0025ffa11bb82aec91128c407a2e723c99c "$binary" | sha512sum -c -)
  unzip -o "$STORAGE_WARS_RUNTIME/$binary" -d "$STORAGE_WARS_RUNTIME/godot"
  ln -sf Godot_v4.6.3-stable_linux.x86_64 "$STORAGE_WARS_RUNTIME/godot/godot"
  rm "$STORAGE_WARS_RUNTIME/$binary"
  export PATH="$STORAGE_WARS_RUNTIME/godot:$PATH"
fi
templates="$XDG_DATA_HOME/godot/export_templates/4.6.3.stable"
if [ ! -s "$templates/web_nothreads_release.zip" ] || [ ! -s "$templates/web_nothreads_debug.zip" ]; then
  archive=Godot_v4.6.3-stable_export_templates.tpz
  # Official release SHA-512, pinned from SHA512-SUMS.txt. Never bypass verification.
  if [ ! -s "$STORAGE_WARS_RUNTIME/$archive" ]; then
    curl -fsSL --retry 2 "$release/$archive" -o "$STORAGE_WARS_RUNTIME/$archive"
  fi
  (cd "$STORAGE_WARS_RUNTIME"; printf '%s  %s\n' da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68 "$archive" | sha512sum -c -)
  mkdir -p "$templates"
  python3 - "$STORAGE_WARS_RUNTIME/$archive" "$templates" <<'PY'
import pathlib, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as archive:
    for name in ('web_nothreads_release.zip', 'web_nothreads_debug.zip', 'version.txt'):
        pathlib.Path(sys.argv[2], name).write_bytes(archive.read('templates/' + name))
PY
  rm "$STORAGE_WARS_RUNTIME/$archive"
fi
godot --headless --editor --path . --import
printf 'Godot and verified single-threaded web templates are ready.\n'
