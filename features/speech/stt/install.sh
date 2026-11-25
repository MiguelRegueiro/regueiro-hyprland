#!/usr/bin/env bash

# Bootstrap local dictation for this machine. Source, model, and settings live
# outside the dotfiles repository under XDG_DATA_HOME.
set -euo pipefail

data_root="${XDG_DATA_HOME:-$HOME/.local/share}/regueiro-dictation"
source_dir="$data_root/whisper.cpp"
model_dir="$data_root/models"
settings_file="$data_root/settings.json"
version="v1.7.4"
requested_model="${REGUEIRO_DICTATION_MODEL:-auto}"
requested_backend="${REGUEIRO_DICTATION_BACKEND:-auto}"

fail() { printf 'Easy dictation setup: %s\n' "$*" >&2; exit 1; }

for command in git cmake python3 pkg-config; do
    command -v "$command" >/dev/null 2>&1 || fail "missing $command"
done

if ! command -v pw-record >/dev/null 2>&1; then
    cat >&2 <<'EOF'
Easy dictation setup: PipeWire's pw-record is required for microphone capture.
  Arch:    sudo pacman -S pipewire
  Fedora:  sudo dnf install pipewire-utils
  FreeBSD: sudo pkg install pipewire
EOF
    exit 1
fi

if ! pkg-config --exists sdl2; then
    cat >&2 <<'EOF'
Easy dictation setup: SDL2 development files are required for microphone capture.
  Arch:    sudo pacman -S sdl2-compat
  Fedora:  sudo dnf install SDL2-devel
  FreeBSD: sudo pkg install sdl2
EOF
    exit 1
fi

if ! command -v wl-copy >/dev/null 2>&1 || ! command -v wtype >/dev/null 2>&1; then
    cat >&2 <<'EOF'
Note: wl-copy and/or wtype are missing. Dictation will still transcribe, but
clipboard delivery or automatic pasting will be unavailable.
  Arch:    sudo pacman -S wl-clipboard wtype
  Fedora:  sudo dnf install wl-clipboard wtype
  FreeBSD: sudo pkg install wl-clipboard wtype
EOF
fi

select_model() {
    case "$requested_model" in
        small|large-v3-turbo) printf '%s\n' "$requested_model"; return ;;
        auto) ;;
        *) fail "REGUEIRO_DICTATION_MODEL must be auto, small, or large-v3-turbo" ;;
    esac

    # Turbo needs substantially more VRAM. A modest NVIDIA laptop such as an
    # MX250 therefore starts with small; capable machines retain Turbo.
    if command -v nvidia-smi >/dev/null 2>&1; then
        local vram
        vram="$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -dc '0-9')"
        if [[ "${vram:-0}" -ge 4096 ]]; then
            printf '%s\n' 'large-v3-turbo'
            return
        fi
    fi
    printf '%s\n' 'small'
}

select_backend() {
    case "$requested_backend" in
        cuda)
            command -v nvcc >/dev/null 2>&1 || fail "CUDA requested but nvcc is unavailable"
            printf '%s\n' cuda
            return
            ;;
        vulkan)
            command -v glslc >/dev/null 2>&1 && pkg-config --exists vulkan || fail "Vulkan requested but glslc or Vulkan development files are unavailable"
            printf '%s\n' vulkan
            return
            ;;
        cpu) printf '%s\n' cpu; return ;;
        auto) ;;
        *) fail "REGUEIRO_DICTATION_BACKEND must be auto, cuda, vulkan, or cpu" ;;
    esac

    if command -v nvcc >/dev/null 2>&1; then
        printf '%s\n' cuda
    elif command -v glslc >/dev/null 2>&1 && pkg-config --exists vulkan; then
        printf '%s\n' vulkan
    else
        printf '%s\n' cpu
    fi
}

model_name="$(select_model)"
backend="$(select_backend)"
model_path="$model_dir/ggml-${model_name}.bin"
build_stamp="$source_dir/build/.regueiro-dictation-backend"

mkdir -p "$data_root" "$model_dir"
if [[ ! -d "$source_dir/.git" ]]; then
    git clone --depth 1 --branch "$version" https://github.com/ggml-org/whisper.cpp.git "$source_dir"
else
    git -C "$source_dir" fetch --depth 1 origin "refs/tags/$version"
    git -C "$source_dir" checkout --detach FETCH_HEAD
fi

cmake_args=(-DWHISPER_SDL2=ON -DCMAKE_BUILD_TYPE=Release)
case "$backend" in
    cuda) cmake_args+=(-DGGML_CUDA=ON); echo "Backend: CUDA." ;;
    vulkan) cmake_args+=(-DGGML_VULKAN=ON); echo "Backend: Vulkan." ;;
    cpu) echo "Backend: CPU." ;;
esac

if [[ "$backend" == cpu && "$requested_backend" == auto ]]; then
    cat <<'EOF'
Note: no GPU build toolchain was found, so CPU is the safe fallback. To enable
cross-vendor Vulkan acceleration, install Vulkan development files plus glslc,
then rerun this script.
EOF
fi

if [[ ! -x "$source_dir/build/bin/whisper-cli" ]] || [[ ! -f "$build_stamp" ]] || [[ "$(<"$build_stamp")" != "$version:$backend" ]]; then
    cmake -E rm -rf "$source_dir/build"
    cmake -S "$source_dir" -B "$source_dir/build" "${cmake_args[@]}"
    cmake --build "$source_dir/build" --target whisper-cli --parallel
    printf '%s\n' "$version:$backend" > "$build_stamp"
else
    echo "Reusing existing $backend engine."
fi

if [[ ! -f "$model_path" ]]; then
    "$source_dir/models/download-ggml-model.sh" "$model_name" "$model_dir"
fi

printf '{"model":"%s","backend":"%s"}\n' "$model_name" "$backend" > "$settings_file"
test -x "$source_dir/build/bin/whisper-cli"
echo "Dictation ready: $backend + $model_name"
echo "Settings: $settings_file"
