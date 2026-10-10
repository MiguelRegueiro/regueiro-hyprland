# EasyTTS

Personal browser-based text-to-speech server. It listens on this machine's
Tailscale IPv4 address by default, so other devices on the tailnet can open
the address printed at startup.

## Run

```sh
./easytts/runtts.sh
```

The first run creates `easytts/.venv/`; it is local to each machine and is not
tracked by Git. Set `EASYTTS_HOST` or `EASYTTS_PORT` to override the default
address or port.

## Start with Hyprland

Hyprland starts EasyTTS automatically without opening a browser. The startup
script is idempotent, so restarting Hyprland will not create another server.
Open the printed URL (or `http://127.0.0.1:8765` when Tailscale is unavailable)
whenever you want it.

## Native clipboard reading

`F7` reads the current clipboard without opening a browser. It sends the text
to the same EasyTTS service and shows a Quickshell OSD while speech is being
prepared and read. `F8` pauses/resumes a current EasyTTS reading, then falls
back to the normal media play/pause action when no reading is active.

The provider boundary lives in `provider.py`. It is the only module that knows
how text becomes an MP3, so replacing Edge TTS with a local voice engine later
does not require changing the API, shortcut, OSD, or web UI.

## Local Kokoro setup

The local Kokoro runtime and its model weights are intentionally machine-local
and are not stored in Git. After cloning or pulling this repository on a new
machine, run once:

```sh
./easytts/setup-local-tts.sh
```

The setup downloads roughly 360 MB of model files and installs the separate
Kokoro Python runtime. It is safe to run again after future pulls.

Kokoro automatically uses CUDA on NVIDIA GPUs with at least 3 GB of VRAM. On
the 2 GB MX250 laptop it instead uses the Intel iGPU through OpenVINO, with CPU
fallback if the Intel driver cannot execute part of the model. Set
`EASYTTS_KOKORO_DEVICE=cpu` or `=cuda` only to override that automatic choice.
The worker releases its model process five seconds after the last synthesis, so
it does not reserve VRAM while idle.
