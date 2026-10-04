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
