#!/usr/bin/env bash
#
# uninstall-fedora.sh — remove everything installed by install-fedora.sh.
#
#   ./scripts/uninstall-fedora.sh            # keep whisper models (~/.local/share/opencode-voice)
#   ./scripts/uninstall-fedora.sh --purge    # also delete models and config

set -euo pipefail

AUTOSTART=no
for arg in "$@"; do
    case "$arg" in
        --purge) AUTOSTART=yes ;;
        -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
        *) echo "unknown argument: $arg" >&2; exit 2 ;;
    esac
done

say() { printf '\n==> %s\n' "$*"; }

say "Stop and disable systemd user service"
systemctl --user stop opencode-voice 2>/dev/null || true
systemctl --user disable opencode-voice 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/opencode-voice.service"

say "Remove binaries"
rm -f "$HOME/.local/bin/opencode-voice" "$HOME/.local/bin/opencode-voice-run"

say "Remove GNOME launchers"
rm -f "$HOME/.local/share/applications/opencode-voice.desktop"
rm -f "$HOME/.local/share/applications/opencode-voice-global.desktop"
rm -f "$HOME/.config/autostart/opencode-voice.desktop" 2>/dev/null || true

say "Remove udev input ACL"
if [ -f /etc/udev/rules.d/99-opencode-voice-uaccess.rules ]; then
    if sudo -n true 2>/dev/null; then
        sudo rm -f /etc/udev/rules.d/99-opencode-voice-uaccess.rules
        sudo udevadm control --reload-rules
    else
        echo "Manual: sudo rm /etc/udev/rules.d/99-opencode-voice-uaccess.rules && sudo udevadm control --reload-rules"
    fi
else
    echo "No udev rule found (was never installed)."
fi

if [ "$AUTOSTART" = yes ]; then
    say "Purge config and whisper models"
    rm -rf "$HOME/.config/opencode-voice"
    rm -rf "$HOME/.local/share/opencode-voice"
else
    say "Kept: ~/.config/opencode-voice and ~/.local/share/opencode-voice (re-run install to reuse)"
fi
