#!/usr/bin/env python3
"""Prepare persistent previews; stdout is an original-path -> preview-URL map."""
import concurrent.futures
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def prepare(source, cache):
    try:
        stat = source.stat()
        key = hashlib.sha256(f"v1:{source}:{stat.st_size}:{stat.st_mtime_ns}".encode()).hexdigest()
        target = cache / f"{key}.jpg"
        with (cache / f"{key}.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            if not target.is_file():
                converter = shutil.which("magick")
                if not converter:
                    return str(source), source.as_uri()
                fd, tmp = tempfile.mkstemp(suffix=".jpg", dir=cache)
                os.close(fd)
                try:
                    subprocess.run([converter, "-limit", "thread", "1", str(source) + "[0]",
                                    "-auto-orient", "-thumbnail", "1536x950>", "-strip",
                                    "-interlace", "none", "-quality", "85", "jpg:" + tmp],
                                   check=True, timeout=30, stdout=subprocess.DEVNULL,
                                   stderr=subprocess.PIPE)
                    os.replace(tmp, target)
                finally:
                    if os.path.exists(tmp):
                        os.unlink(tmp)
        return str(source), target.as_uri()
    except (OSError, subprocess.SubprocessError) as error:
        print(f"Wallpaper preview failed for {source.name}: {error}", file=sys.stderr)
        return str(source), source.as_uri()


def main():
    folder = Path(sys.argv[1]).absolute()
    cache = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "quickshell/wallpaper-thumbnails-v1"
    cache.mkdir(parents=True, exist_ok=True)
    sources = sorted(p for p in folder.iterdir() if p.is_file() and p.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"})
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        result = dict(pool.map(lambda p: prepare(p, cache), sources))
    print(json.dumps(result))


if __name__ == "__main__":
    main()
