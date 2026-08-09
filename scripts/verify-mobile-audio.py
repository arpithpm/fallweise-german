#!/usr/bin/env python3
"""Verify mobile audio without flooding the public playback endpoint."""
from __future__ import annotations

import argparse
import hashlib
import json
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESOURCES = ROOT / "FallweiseIOS" / "Fallweise" / "Resources"
MODEL = "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice"
SPEAKER = "Vivian"
RATE = "1.0"
ORIGIN = "https://fallweise-voice-session.arpithpmuddi-0ee.workers.dev/audio"


def deployed_url(text: str) -> str:
    source = f"{MODEL}|{SPEAKER}|{RATE}|{text}"
    digest = hashlib.sha256(source.encode()).hexdigest()
    return f"{ORIGIN}/{digest}.wav"


def curriculum_texts() -> dict[str, list[str]]:
    texts: dict[str, list[str]] = {}
    for level in ("a1", "a2", "b1"):
        level_texts: list[str] = []
        data = json.loads((RESOURCES / f"{level}-vocabulary.json").read_text())
        for word in data["items"]:
            level_texts.append(f"{word['article']} {word['de']}" if word["article"] else word["de"])
            level_texts.append(word["example"])
        texts[level] = list(dict.fromkeys(filter(None, level_texts)))
    return texts


def verify(text: str) -> tuple[str, str | None]:
    request = urllib.request.Request(
        deployed_url(text), method="HEAD", headers={"User-Agent": "FallweiseAudioAudit/1.0"}
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            if response.status != 200:
                return text, f"HTTP {response.status}"
            if response.headers.get_content_type() != "audio/wav":
                return text, f"unexpected type {response.headers.get_content_type()}"
    except (urllib.error.URLError, TimeoutError) as error:
        return text, str(error)
    return text, None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sample-per-level", type=int, default=10)
    args = parser.parse_args()
    by_level = curriculum_texts()
    local_failures = []
    samples = []
    for level, texts in by_level.items():
        for text in texts:
            local_path = ROOT / "work" / "tts-cache" / deployed_url(text).rsplit("/", 1)[-1]
            if not local_path.exists() or local_path.stat().st_size <= 1_000:
                local_failures.append((level, text))
        step = max(1, len(texts) // args.sample_per_level)
        samples.extend(texts[::step][: args.sample_per_level])
    results = [verify(text) for text in samples]
    failures = [(text, error) for text, error in results if error]
    total = sum(map(len, by_level.values()))
    print(f"local_checked={total} local_missing={len(local_failures)} deployed_sampled={len(samples)} deployed_failed={len(failures)}")
    for level, text in local_failures[:30]:
        print(f"LOCAL_MISSING\t{level}\t{text}")
    for text, error in failures[:30]:
        print(f"FAIL\t{text}\t{error}")
    return 1 if failures or local_failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
