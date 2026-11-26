#!/usr/bin/env python3
import importlib.util
import json
import os
import stat
import sys
import tempfile
import types
from pathlib import Path


repo = Path(__file__).resolve().parents[1]
app_path = repo / "features/speech/tts/app.py"


def load_app(config_home: Path, runtime_env: dict[str, str]):
    provider = types.ModuleType("provider")
    provider.DEFAULT_PROVIDER = "kokoro"
    provider.DEFAULT_RATE = "+0%"
    provider.DEFAULT_VOICE = "kokoro-michael"

    async def synthesize_to_file(*_args):
        raise AssertionError("synthesis is not part of this state migration test")

    provider.synthesize_to_file = synthesize_to_file
    sys.modules["provider"] = provider
    os.environ["XDG_CONFIG_HOME"] = str(config_home)
    for name in ("XDG_RUNTIME_DIR", "XDG_CACHE_HOME"):
        os.environ.pop(name, None)
    os.environ.update(runtime_env)

    spec = importlib.util.spec_from_file_location("triton_tts_app", app_path)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


with tempfile.TemporaryDirectory(prefix="triton-tts-state-") as temporary:
    root = Path(temporary)
    config = root / "config"
    runtime = root / "runtime"
    legacy_preferences = config / "regueiro-easytts/preferences.json"
    legacy_preferences.parent.mkdir(parents=True)
    legacy_preferences.write_text(
        json.dumps({"provider": "edge", "voice": "en-US-GuyNeural", "rate": "+25%"}),
        encoding="utf-8",
    )

    app = load_app(config, {"XDG_RUNTIME_DIR": str(runtime)})
    migrated = app.load_preferences()
    assert migrated == {"provider": "edge", "voice": "en-US-GuyNeural", "rate": "+25%"}
    app.save_preferences(**migrated)
    assert json.loads((config / "triton-tts/preferences.json").read_text(encoding="utf-8")) == migrated
    assert legacy_preferences.exists(), "legacy preferences must remain available during migration"
    assert app.RUNTIME == runtime / "triton-tts"
    assert stat.S_IMODE(app.RUNTIME.stat().st_mode) == 0o700

    fallback = root / "cache"
    fallback_app = load_app(config, {"XDG_CACHE_HOME": str(fallback)})
    assert fallback_app.RUNTIME == fallback / "triton-tts/runtime"
    assert stat.S_IMODE(fallback_app.RUNTIME.stat().st_mode) == 0o700

print("Triton TTS state migration and private runtime checks passed.")
