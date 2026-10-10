#!/usr/bin/env bash

# Install the machine-local Kokoro runtime and model weights.
# Safe to re-run after git pull; tracked code stays in Git while the large
# environment and model files remain ignored per machine.
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
runtime="$root/.kokoro"
models="$root/.kokoro-model"
requirements="$root/requirements-kokoro.txt"
release="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.1"

install_runtime() {
    if command -v uv >/dev/null 2>&1; then
        uv venv --python 3.11 "$runtime"
        uv pip install --python "$runtime/bin/python" --upgrade -r "$requirements"
    else
        python3 -m venv "$runtime"
        "$runtime/bin/python" -m pip install --upgrade pip
        "$runtime/bin/python" -m pip install --upgrade -r "$requirements"
    fi
}

install_package() {
    if command -v uv >/dev/null 2>&1; then
        uv pip install --python "$runtime/bin/python" --upgrade "$1"
    else
        "$runtime/bin/python" -m pip install --upgrade "$1"
    fi
}

cuda_vram_mib() {
    nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null \
        | awk 'NF { if ($1 > maximum) maximum = $1 } END { if (maximum) print maximum }'
}

install_backend() {
    local vram
    vram="$(cuda_vram_mib || true)"
    if [[ -n "$vram" && "$vram" -ge 3072 ]]; then
        install_package 'onnxruntime-gpu==1.31.0'
        echo 'Kokoro backend: NVIDIA CUDA.'
    elif command -v lspci >/dev/null 2>&1 && lspci | grep -qiE '(VGA|3D).*Intel'; then
        # OpenVINO's AUTO target tries the integrated GPU first and uses CPU
        # only when a driver or operation cannot run there.
        install_package 'onnxruntime-openvino==1.24.1'
        echo 'Kokoro backend: Intel iGPU via OpenVINO (CPU fallback).'
    else
        install_package 'onnxruntime==1.31.0'
        echo 'Kokoro backend: CPU.'
    fi
}

download() {
    local name="$1" temporary
    [[ -s "$models/$name" ]] && return
    temporary="$models/$name.part"
    rm -f "$temporary"
    curl --fail --location --retry 3 --output "$temporary" "$release/$name"
    mv "$temporary" "$models/$name"
}

install_runtime
install_backend
mkdir -p "$models"
download kokoro-v1.0.onnx
download voices-v1.0.bin

echo "Kokoro is ready. Device selection is automatic: CUDA (3 GB+ NVIDIA), then Intel iGPU through OpenVINO, then CPU."
