# Fedora Workstation — Setup & Runbook

Maintainer: William Power (Powerworks fork of [mathew-cf/opencode-voice](https://github.com/mathew-cf/opencode-voice)).

This doc covers the fork's Fedora packaging layer. For upstream usage, model
sizes, and CLI flags see the [README](README.md).

## Prerequisites (Fedora 44 Workstation)

- rust ≥ 1.70 (`dnf install rust`), cmake, gcc, clang-devel (`libclang` for bindgen), alsa-lib-devel
- PipeWire audio (default on Fedora Workstation) — `cpal` finds the mic through it
- User in the `input` group for global hotkeys (`usermod -aG input $USER`, relogin)
  - inside a rootless systemd user service, setgroups() is blocked; the global
    hotkey then needs the udev `uaccess` ACL (auto-installed when passwordless
    sudo is available, else a manual sudo printed by the install script)
- The OpenCode background service must be running (it normally is: `opencode service status`)

## Install (one shot)

```sh
./scripts/install-fedora.sh                  # + GNOME session systemd service
./scripts/install-fedora.sh --with-autostart # additionally start at login
```

The script: builds release, copies binaries to `~/.local/bin`, generates
`~/.config/opencode-voice/opencode-voice.conf` (auto-filled server password,
chmod 600), downloads the Whisper model, installs + enables the systemd user
unit, registers GNOME launchers. Re-runnable; safe across upstream pulls.

## Layout after install

| Path | Purpose |
|---|---|
| `~/.local/bin/opencode-voice-run` | **recommended entry point** — wrapper |
| `~/.config/opencode-voice/opencode-voice.conf` | env config (port / password / model) |
| `~/.config/systemd/user/opencode-voice.service` | systemd user unit |
| `~/.local/share/opencode-voice/models/` | whisper .bin model(s) |
| `~/.local/share/applications/opencode-voice{-global}.desktop` | GNOME launchers |

## Daily operation

**Holds-ZERO-focus global mode (recommended):**
Add the *OpenCode Voice (Global Hotkey)* launcher, or run:

```sh
~/.local/bin/opencode-voice-run --hotkey right_ctrl --no-push-to-talk
```

Hold **right Ctrl** anywhere (works system-wide via evdev), release → the
transcript lands in the OpenCode prompt and submits.

**Terminal push-to-talk mode:**
run `Opencode Voice` from Activities, or in any terminal:

```sh
~/.local/bin/opencode-voice-run
```

Hold **SPACE**, release → transcribe & submit. Works best with the terminal focused.

**Auto-submit toggle:** append `--no-auto-submit` to either mode to get the
transcript in the prompt *without* sending, so you can edit first.

## Service control

```sh
systemctl --user status opencode-voice
journalctl --user -fu opencode-voice   # logs (health, transcripts, errors)
systemctl --user restart opencode-voice
~/.local/bin/opencode-voice devices    # mic enumeration (ALSA/PulseAudio via cpal)
~/.local/bin/opencode-voice keys       # valid --hotkey / --key names
```

The systemd unit starts the `opencode-voice-run` wrapper, which **re-discovers
the OpenCode service port on every launch** — a `opencode service restart`
does not break it. Random edge case: if OpenCode isn't up yet when the service
starts, it fails once and systemd restarts it (Restart=on-failure); or restart
after starting OpenCode.

## Config reference (`opencode-voice.conf`)

```bash
OPENCODE_VOICE_PORT=                # empty = auto-discover (recommended)
OPENCODE_SERVER_PASSWORD=...        # filled at install; from opencode service.json
OPENCODE_VOICE_MODEL=tiny.en        # tiny.en|base.en|small.en|tiny|base|small
```

Model default is **tiny.en** (~75 MB) — tuned for this 4-core box. See
[OPTIMIZATION.md](OPTIMIZATION.md) for a sizing table and tuning targets.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Authentication required` / 401 | `OPENCODE_SERVER_PASSWORD` empty or stale | refresh conf from `~/.config/opencode/service.json`; `systemctl --user restart opencode-voice` |
| `Whisper model not found` | model never downloaded | `opencode-voice setup --model tiny.en` |
| Global hotkey silent (systemd service) | setgroups() not allowed in rootless user manager — service can't join `input`; or uaccess ACL not applied | apply the udev rule from step 8 of install (~/.config/systemd/user service only; desktop-session launchers use your ambient `input` group and work regardless) |
| No `input` group membership | evdev open fails even in session launchers | `sudo usermod -aG input $(whoami)` + re-login |
| Global hotkey dead in GNOME | evdev event devices rw | confirm `/dev/input/event*` readable+writable and user in `input` group |
| systemd unit shows `inactive (dead)` | port fallback raced `opencode service restart` | `systemctl --user restart opencode-voice` |
| transcripts land in wrong session | OpenCode session API mismatch (upstream branch `use-session-api`) | run one instance only; stop extras |

## Uninstall

```sh
./scripts/uninstall-fedora.sh            # keep whisper models + conf
./scripts/uninstall-fedora.sh --purge    # remove everything
```
