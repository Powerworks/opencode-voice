#!/usr/bin/env bash
#
# install-fedora.sh — one-shot setup of opencode-voice on Fedora Workstation.
#
#   ./scripts/install-fedora.sh                   # core: deps, build, config, systemd
#   ./scripts/install-fedora.sh --with-autostart  # + GNOME autostart launcher
#
# Idempotent — safe to re-run after pulling upstream changes.
# Requires a sudo prompt on first run (dnf package install).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF_DIR="$HOME/.config/opencode-voice"
MODEL="${OPCODE_VOICE_MODEL:-tiny.en}"
AUTOSTART=no
for arg in "$@"; do
    case "$arg" in
        --with-autostart) AUTOSTART=yes ;;
        -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
        *) echo "unknown argument: $arg" >&2; exit 2 ;;
    esac
done

say() { printf '\n==> %s\n' "$*"; }

# --- 1. system dependencies --------------------------------------------------
say "Check system deps: cmake, gcc, pkg-config, alsa-lib-devel, pipewire-alsa, clang-devel"
MISSING=0
for dep in cmake gcc pkg-config; do
    command -v "$dep" >/dev/null 2>&1 || { echo "missing: $dep"; MISSING=1; }
done
rpm -q clang-devel alsa-lib-devel pipewire-alsa >/dev/null 2>&1 || MISSING=1
if [ "$MISSING" -ne 0 ] && command -v dnf >/dev/null 2>&1; then
    sudo -n dnf install -y cmake gcc pkg-config alsa-lib-devel pipewire-alsa clang-devel 2>/dev/null \
        || sudo dnf install -y cmake gcc pkg-config alsa-lib-devel pipewire-alsa clang-devel
fi

# --- 2. build -----------------------------------------------------------------
say "cargo build --release (first run compiles whisper.cpp — several minutes)"
command -v cargo >/dev/null 2>&1 || { echo "cargo missing: install via dnf rustup or rust package" >&2; exit 1; }
cargo build --release --manifest-path "$REPO_DIR/Cargo.toml"

# --- 3. install binaries -------------------------------------------------------
say "Install binaries to ~/.local/bin"
mkdir -p "$HOME/.local/bin"
install -m 755 "$REPO_DIR/target/release/opencode-voice"      "$HOME/.local/bin/opencode-voice"
install -m 755 "$REPO_DIR/scripts/opencode-voice-run.sh"      "$HOME/.local/bin/opencode-voice-run"
echo "Entry point: ~/.local/bin/opencode-voice-run"

# --- 4. config -----------------------------------------------------------------
say "Write $CONF_DIR/opencode-voice.conf (chmod 600)"
mkdir -p "$CONF_DIR"
SERV_JSON="$HOME/.config/opencode/service.json"
PW=""
if [ -f "$SERV_JSON" ]; then
    PW="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["password"])' "$SERV_JSON" 2>/dev/null || true)"
else
    echo "WARNING: $SERV_JSON not found — OPENCODE_SERVER_PASSWORD left empty." >&2
    echo "         Create: opencode service / see docs/FEDORA-SETUP.md" >&2
fi
sed -e "s|^OPENCODE_SERVER_PASSWORD=.*|OPENCODE_SERVER_PASSWORD=$PW|" \
    -e "s|^OPENCODE_VOICE_MODEL=.*|OPENCODE_VOICE_MODEL=$MODEL|" \
    "$REPO_DIR/packaging/fedora/opencode-voice.conf.example" > "$CONF_DIR/opencode-voice.conf"
chmod 600 "$CONF_DIR/opencode-voice.conf"

# --- 5. whisper model ----------------------------------------------------------
say "Download whisper model '$MODEL'"
"$HOME/.local/bin/opencode-voice" setup --model "$MODEL"

# --- 6. systemd user service ---------------------------------------------------
say "systemd user unit → enable --now"
mkdir -p "$HOME/.config/systemd/user"
install -m 644 "$REPO_DIR/packaging/fedora/opencode-voice.service" \
    "$HOME/.config/systemd/user/opencode-voice.service"
systemctl --user daemon-reload
systemctl --user enable --now opencode-voice

# --- 7. GNOME launchers ---------------------------------------------------------
say "GNOME app launchers → ~/.local/share/applications"
mkdir -p "$HOME/.local/share/applications"
install -m 644 "$REPO_DIR/packaging/fedora/opencode-voice.desktop" \
    "$HOME/.local/share/applications/opencode-voice.desktop"
install -m 644 "$REPO_DIR/packaging/fedora/opencode-voice-global.desktop" \
    "$HOME/.local/share/applications/opencode-voice-global.desktop"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
if [ "$AUTOSTART" = yes ]; then
    mkdir -p "$HOME/.config/autostart"
    install -m 644 "$REPO_DIR/packaging/fedora/opencode-voice.desktop" \
        "$HOME/.config/autostart/opencode-voice.desktop"
    echo "Autostart launcher installed."
fi

# --- 8. udev ACL for /dev/input -----------------------------------------------
# Allows the global hotkey listener inside the rootless systemd --user
# service, where SupplementaryGroups= is not permitted (setgroups() needs
# CAP_SETGID the user manager doesn't have). Uses the uaccess tag: logind
# attaches a user ACL to the device while a session is active.
say "udev → /dev/input/event* ACL (uaccess tag)"
if sudo -n true 2>/dev/null; then
    sudo install -m 644 "$REPO_DIR/packaging/fedora/99-opencode-voice-uaccess.rules" \
        /etc/udev/rules.d/99-opencode-voice-uaccess.rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger --subsystem-match=input --action=change
    echo "ACL installed — session user has rw on /dev/input/event* (world-visible perms root:input 660)"
else
    echo "SKIP — /etc/udev/rules.d not writable without sudo."
    echo "To enable the global hotkey inside the systemd user service:"
    echo "  sudo install -m 644 packaging/fedora/99-opencode-voice-uaccess.rules /etc/udev/rules.d/"
    echo "  sudo udevadm control --reload-rules && sudo udevadm trigger --subsystem-match=input --action=change"
fi

# --- 8. verify ------------------------------------------------------------------
say "Done. Next steps:"
echo "  journalctl --user -fu opencode-voice        # watch first run"
echo "  ~/.local/bin/opencode-voice devices         # confirm microphone is listed"
echo "  ~/.local/bin/opencode-voice keys            # list hotkey names"
echo "  Then hold SPACE (or RIGHT CTRL via the Global launcher) and speak."
