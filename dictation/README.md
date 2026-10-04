# Local dictation

This is a small, local speech-to-text feature for the QuickShell setup. It is
not a desktop application and does not have its own global shortcut.

`Super+T` is a release-triggered toggle: tap once to start listening and tap it
again to stop. QuickShell displays the current state and recognized text under
the top bar.

## Install

The source, model, and build output intentionally stay outside this repository:

```sh
./dictation/install.sh
```

The installer uses a pinned `whisper.cpp` release and stores its engine, model,
and one machine-local settings file in `$XDG_DATA_HOME/regueiro-dictation`
(normally `~/.local/share/regueiro-dictation`). The repo itself contains only
the setup, controller, and QuickShell UI.

Run this once after pulling the dotfiles on each machine:

```sh
./dictation/install.sh
```

It selects the fastest available backend in this order: CUDA, Vulkan, then
CPU. It also chooses `large-v3-turbo` only for NVIDIA GPUs with at least 4 GB
VRAM; other machines start with the smaller, dependable `small` model. The
selected model/backend are persisted in `settings.json`, so the Hyprland
binding needs no per-machine edits.

Override either choice only when wanted:

```sh
REGUEIRO_DICTATION_MODEL=small ./dictation/install.sh
REGUEIRO_DICTATION_BACKEND=cpu ./dictation/install.sh
```

System requirements are `git`, `cmake`, `python3`, `pkg-config`, `pw-record`
(PipeWire), and SDL2 development files. `wl-copy` and `wtype` enable automatic
clipboard copy/paste. The installer prints concise Arch/Fedora/FreeBSD package
hints when required helpers are missing. Vulkan acceleration is selected when
both `glslc` and Vulkan development files are installed; otherwise CPU remains
the safe fallback.

## Machine profiles

- **RTX laptop with 4 GB+ VRAM:** automatic CUDA + `large-v3-turbo`.
- **2 GB NVIDIA laptop (for example MX250):** automatic Vulkan + `small` when
  Vulkan build tools are installed; CPU + `small` remains functional otherwise.
- **AMD or Intel:** automatic Vulkan + `small` when available; otherwise CPU +
  `small`.
- **FreeBSD:** CPU + `small` is the dependable baseline; Vulkan is selected
  automatically when its Wayland/PipeWire and Vulkan toolchain are present.

For a Fedora Hyprland laptop, this is the usual one-time prerequisite install:

```sh
sudo dnf install git cmake python3 pkgconf-pkg-config SDL2-devel pipewire-utils \
  wl-clipboard wtype vulkan-loader-devel glslc
```

Then pull/deploy the dotfiles and run `./dictation/install.sh`. The script
prints the backend and model it selected; no Hyprland or Quickshell edits are
needed per machine.

## Behaviour and safety

- Inference is fully local; the microphone audio and text do not leave the
  machine.
- On completion, the text is copied to the Wayland clipboard and then pasted
  into the currently focused application using `wtype` to send `Ctrl+V`. The
  clipboard remains the fallback if focus changes or `wtype` is unavailable.
- `wl-copy` and `wtype` are optional runtime helpers: without either, the OSD
  still displays the finalized transcription.

The transcription is deliberately left unmodified apart from removing bogus
bracketed sound captions such as `[Clock ticking]`.
