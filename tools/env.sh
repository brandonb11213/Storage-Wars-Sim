#!/usr/bin/env bash
# Source from any working directory before using the pinned Godot or test tools.
export STORAGE_WARS_RUNTIME="${STORAGE_WARS_RUNTIME:-/workspace/.runtime}"
export XDG_CACHE_HOME="$STORAGE_WARS_RUNTIME/cache"
export XDG_DATA_HOME="$STORAGE_WARS_RUNTIME/data"
export XDG_CONFIG_HOME="$STORAGE_WARS_RUNTIME/config"
if [ -x "$STORAGE_WARS_RUNTIME/godot/Godot_v4.6.3-stable_linux.x86_64" ]; then
  export PATH="$STORAGE_WARS_RUNTIME/godot:$PATH"
fi
