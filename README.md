# opencode-voice

> ## ⚠️ Fork note (Powerworks / Fedora Workstation)
>
> This fork adds a Fedora layer:
> - **libclang/LLVM 22 + bindgen 0.69/0.71 failure work-around**: modern
>   libclang renders `whisper_full_params` opaque; `.cargo/config.toml`
>   forces the crate to use its shipped `src/bindings.rs` instead of
>   regenerating (layout-checked by the crate's own tests).
> - the vendored `whisper.h` renames two anonymous C structs
>   (`greedy`/`beam_search`) so a future bindgen run also works; layout-identical.
> - a systemd user service + GNOME launchers; a wrapper that auto-discovers the
>   OpenCode service port; `tiny.en` as default model for 4-core boxes.
> Full setup: `docs/FEDORA-SETUP.md`. Tuning surface: `docs/OPTIMIZATION.md`.
> Uninstall with `scripts/uninstall-fedora.sh`. Everything below is unchanged upstream.

**Voice control for [OpenCode](https://opencode.ai)**

Everything runs on your machine — no cloud services, no API keys, no audio leaves your device.

```
Microphone → whisper.cpp → text → OpenCode
```

---

## Install

```bash
cargo install opencode-voice
```

> Requires Rust 1.70+, cmake, and a C compiler. See [Building from source](BUILDING.md) for details.

## Setup

Download a transcription model (~150 MB):

```bash
opencode-voice setup
```

## Run

Start OpenCode with its HTTP server, then start opencode-voice in a separate terminal:

```bash
opencode --port 4096
opencode-voice --port 4096
```

Hold **space** to record, release to transcribe and send. Press **q** to quit.

---

## Options

| Flag | Default | Description |
|------|---------|-------------|
| `--port <n>` | *(required)* | OpenCode server port |
| `--model <size>` | `base.en` | Whisper model (see below) |
| `--device <name>` | system default | Audio input device |
| `--key <name>` | `space` | Toggle key for recording |
| `--hotkey <name>` | `right_option` | Global hotkey (system-wide) |
| `--no-global` | — | Disable global hotkey |
| `--no-push-to-talk` | — | Toggle mode instead of hold-to-talk |
| `--no-auto-submit` | — | Don't auto-submit; leave transcript in prompt for review |
| `--no-handle-prompts` | — | Don't handle OpenCode permission/question prompts via voice |

### Models

English-only models are fine-tuned on English and generally more accurate. Multilingual models support 99 languages and may help with some accents, but the biggest improvement for accent robustness comes from using a larger model size.

| Model | Type | Size |
|-------|------|------|
| `tiny.en` | English-only | ~75 MB |
| `base.en` | English-only (default) | ~142 MB |
| `small.en` | English-only | ~466 MB |
| `tiny` | Multilingual | ~75 MB |
| `base` | Multilingual | ~142 MB |
| `small` | Multilingual | ~466 MB |

Environment variables: `OPENCODE_VOICE_PORT`, `OPENCODE_VOICE_MODEL`, `OPENCODE_SERVER_PASSWORD`.

## Other commands

```
opencode-voice setup [--model <MODEL>]   Download whisper model
opencode-voice devices                   List audio input devices
opencode-voice keys                      List key names for --key / --hotkey
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Can't connect to OpenCode | Make sure OpenCode is running with `--port` |
| No speech detected | Speak closer to mic, try `--model small.en`, check `opencode-voice devices` |
| Whisper model not found | Run `opencode-voice setup` |
| Global hotkeys don't work (macOS) | Grant Accessibility permission in System Settings, or use `--no-global` |
| Auth errors (401) | Set `OPENCODE_SERVER_PASSWORD` env var |
| Build failures | See [Building from source](BUILDING.md) |

## Platform support

| Platform | Status |
|----------|--------|
| macOS | Fully supported (requires Accessibility permission for global hotkeys) |
| Linux | Supported (ALSA or PulseAudio) |
| Windows | Not supported |

## License

Apache 2.0 — see [LICENSE](LICENSE).
