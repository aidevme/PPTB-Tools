#!/usr/bin/env python3
"""
kokoro-smoke-test.py — narrate the first N slides of a Marp markdown deck
using Kokoro-82M (CPU-only, free, local).

Usage:
  python3 kokoro-smoke-test.py <slide.md> [num_slides=3] [voice=af_heart]

Voices to try: af_heart, af_sky, af_bella, am_adam, am_michael, bf_emma,
bm_george (a=American female/male, b=British female/male).
"""
import re
import sys
from pathlib import Path
from urllib.request import urlretrieve

# Windows console defaults to cp1252; force UTF-8 so → / ✓ / · don't crash prints.
try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

CACHE = Path.home() / ".cache" / "kokoro-onnx"
CACHE.mkdir(parents=True, exist_ok=True)

MODEL_URL  = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx"
VOICES_URL = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin"

for name, url in [("kokoro-v1.0.onnx", MODEL_URL), ("voices-v1.0.bin", VOICES_URL)]:
    p = CACHE / name
    if not p.exists():
        print(f"[download] {name} ({url}) ...", flush=True)
        urlretrieve(url, p)

# --- Args ---
src = Path(sys.argv[1]) if len(sys.argv) > 1 else None
if not src or not src.exists():
    print("usage: kokoro-smoke-test.py <slide.md> [num_slides] [voice]")
    sys.exit(1)
n_slides = int(sys.argv[2]) if len(sys.argv) > 2 else 3
voice    = sys.argv[3] if len(sys.argv) > 3 else "af_heart"

# --- Parse Marp ---
md = src.read_text(encoding="utf-8")
md = re.sub(r"^---\n.*?\n---\n", "", md, count=1, flags=re.DOTALL)  # drop frontmatter
slides = md.split("\n---\n")

def clean(text: str) -> str:
    text = re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL)   # marp directives
    text = re.sub(r"<[^>]+>", " ", text)                       # HTML tags
    text = re.sub(r"```.*?```", " ", text, flags=re.DOTALL)    # code fences
    text = re.sub(r"[*_`#>]", "", text)                        # md emphasis
    text = re.sub(r"\|", " ", text)                            # table pipes
    text = re.sub(r"[-=]{3,}", " ", text)                      # rulers
    text = re.sub(r"\s+", " ", text).strip()
    return text

narration = ". ".join(t for s in slides[:n_slides] if (t := clean(s)))
print(f"\nNarrating {min(n_slides, len(slides))} of {len(slides)} slides ({len(narration)} chars)")
print(f"Voice: {voice}\n")
print(f"--- text being narrated ---\n{narration[:600]}{'...' if len(narration) > 600 else ''}\n")

# --- Synthesize ---
from kokoro_onnx import Kokoro
import soundfile as sf
import time

print("[synth] loading Kokoro-82M...", flush=True)
kokoro = Kokoro(str(CACHE / "kokoro-v1.0.onnx"), str(CACHE / "voices-v1.0.bin"))

t0 = time.time()
samples, sr = kokoro.create(narration, voice=voice, speed=1.0, lang="en-us")
elapsed = time.time() - t0
duration = len(samples) / sr

out = src.with_suffix(".smoke.wav")
sf.write(out, samples, sr)

print(f"\n✓ wrote {out}")
print(f"  duration  : {duration:.1f}s of audio")
print(f"  render    : {elapsed:.1f}s wall clock")
print(f"  realtime  : {duration/elapsed:.1f}×")
