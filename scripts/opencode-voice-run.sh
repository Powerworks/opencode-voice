#!/usr/bin/env bash
# opencode-voice-run — launch wrapper for the Fedora Workstation setup.
#
# Sources ~/.config/opencode-voice/opencode-voice.conf, auto-discovers the
# OpenCode background-service port (it changes whenever the service restarts),
# then execs the opencode-voice binary. Extra CLI args are passed through and
# override the wrapper's defaults (clap accepts repeated flags, last wins).
set -euo pipefail

CONF="${OPCODE_VOICE_CONF:-$HOME/.config/opencode-voice/opencode-voice.conf}"
BIN="${OPCODE_VOICE_BIN:-$HOME/.local/bin/opencode-voice}"

if [ -r "$CONF" ]; then
    # shellcheck disable=SC1090
    . "$CONF"
    export OPENCODE_VOICE_PORT="${OPENCODE_VOICE_PORT:-}"
    export OPENCODE_SERVER_PASSWORD="${OPENCODE_SERVER_PASSWORD:-}"
    export OPENCODE_VOICE_MODEL="${OPENCODE_VOICE_MODEL:-}"
fi

# The OpenCode background service picks its port at startup; rediscover it on
# every launch so nothing goes stale after `opencode service restart`.
if [ -z "${OPENCODE_VOICE_PORT:-}" ]; then
    PORT="$("$HOME/.opencode/bin/opencode" service status 2>/dev/null \
        | grep -oE 'http://127\.0\.0\.1:[0-9]+' | grep -oE '[0-9]+$' || true)"
    OPENCODE_VOICE_PORT="${PORT:-49374}"   # fallback only; valid until restart
fi

OPENCODE_VOICE_MODEL="${OPENCODE_VOICE_MODEL:-tiny.en}"

if [ ! -x "$BIN" ]; then
    echo "opencode-voice binary not found at $BIN -- run scripts/install-fedora.sh" >&2
    exit 1
fi

exec "$BIN" --port "$OPENCODE_VOICE_PORT" --model "$OPENCODE_VOICE_MODEL" "$@"
