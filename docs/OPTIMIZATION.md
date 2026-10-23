# Optimization Guide (Powerworks fork)

Your tuning surface: **model size · threads · audio path · auto-submit policy · hotkey ergonomics**.
Everything below is measured intuition for a 4-core / 15 GB Fedora Workstation — re-derive numbers on your box with the snippets given.

## 1. Model size ladder (whisper.cpp, CPU, 16 kHz mono)

| Model | Disk | ≈RAM (load) | ≈latency for ~5 s utterance (4 cores) | Verdict |
|---|---|---|---|---|
| `tiny.en` | 75 MB | ~150 MB | ~1–2 s | **default** — dictation speed winner |
| `base.en` | 142 MB | ~290 MB | ~2–4 s | better accuracy, still tolerable |
| `small.en` | 466 MB | ~1.2 GB | ~6–12 s | too laggy for live dictation |
| `tiny`/`base` (multilingual) | same | same | same | only if accents demand it |

Switch via `OPENCODE_VOICE_MODEL` in `~/.config/opencode-voice/opencode-voice.conf`
or `opencode-voice setup --model <name>` → restart the service. One model per
session is loaded once; tiny→base without restart is not hot-swappable.

## 2. Threads

whisper-rs doesn't currently thread-set from the CLI. The wrapper's systemd unit
runs `Nice=5` idle I/O, so Whisper shares cores politely with the UI. Real fix
(see §6): expose `n_threads` through `WhisperParams`. While you wait, the knob is
`--max-timeslice`… no: use the model size. Small boxes: tiny is the thread lever.

## 3. Audio path latency budget

cpal → PipeWire (PulseAudio compat) → capture at 16 kHz. Expect:

- push-to-talk release → visible "transcribing" ≈ device readout + model inference.
- ~10–20 ms audio buffering overhead is normal; don't chase it.

If `devices` lists nothing: `systemctl --user restart pipewire pipewire-pulse`, re-run.

## 4. Auto-submit vs review-first

`scripts/opencode-voice-run.sh --no-auto-submit` leaves the transcript in the
prompt without sending — good for prompting LLMs (typos, names, paths matter).
With a good mic, auto-submit (default) is the 0-friction mode.

## 5. Hotkeys

- Terminal PTT: `space` (needs focus) — easiest to debug.
- Global: `--hotkey right_ctrl -‑no-push-to-talk` via evdev. Requires input-group rw on
  `/dev/input/event*` — already true on this box (`williampower` ∈ `input`).
- Autocomplete: bind keys like `pause` exist too — `opencode-voice keys`.

Two instances writing to the same prompt will double-spend: keep one.

## 6. Bigger structural upgrades (fork ideas)

1. **Expose `n_threads` + `initial_prompt`** — `WhisperParams` already has them;
   a CLI flag in `config.rs` + a few lines in `src/app` gets you a
   coding-vocabulary prompt bias (`initial_prompt` with identifiers like
   `k8s, kustomize, Terraform` tends to clean dictation sharply).
2. **Streaming transcription** — whisper.cpp supports chunked/timestamped
   realtime decode; wire `new_segment_callback` to a streaming UI instead of
   record-release-transcribe. Biggest perceived-latency win available.
3. **Vosk / sherpa-onnx backend swap** — `src/transcribe/engine.rs` is the
   single seam (`WhisperEngine` behind one `transcribe()` call). If you ever
   need far lower footprint (e.g., an LXC or a Pi), a vosk-based engine
   (~50 MB models, china-fast) drops in there without touching UI/audio.
4. **evdev listening filter** — the current hotkey watcher reads all event
   nodes; filtering to devices containing `Keyboard` in name halves wakeups.
5. **Systemd hardening** — `ProtectSystem=strict`, private tmp, no-new-privileges
   once input-group is replaced by a uaccess udev rule (trade-off note: uaccess
   per-device rules are cleaner than group membership if untrusted apps run locally).

## 7. Dictation prompt-bias (free accuracy)

tiny.en + `initial_prompt` injecting domain vocabulary is a pure win at zero
model cost:

```
"the instruction is a technical brief. Terms: event modeling, command, projection, causality."
```

Implement in the fork as `APP_INITIAL_PROMPT` config; see §6 item 1.
