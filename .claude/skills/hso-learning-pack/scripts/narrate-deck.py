#!/usr/bin/env python3
"""
narrate-deck.py — turn a Marp .md deck into an MP4 with TTS narration.

For each slide: render to PNG, synthesize narration with Kokoro-82M, then
FFmpeg-stitch image + audio into a per-slide MP4 segment. Final concat
produces one MP4.

Usage:
  python narrate-deck.py <deck.md> [voice=af_heart] [output.mp4]

Requires: kokoro-onnx, soundfile, ffmpeg on PATH, marp-cli (via npx).
"""
from __future__ import annotations
import re
import subprocess
import sys
import time
from pathlib import Path
from urllib.request import urlretrieve

# Force UTF-8 stdout on Windows (cp1252 crashes on → · ✓ etc.)
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
    if not (CACHE / name).exists():
        print(f"[download] {name}", flush=True)
        urlretrieve(url, CACHE / name)

# ───────────────── args ─────────────────
deck = Path(sys.argv[1]) if len(sys.argv) > 1 else None
if not deck or not deck.exists():
    print("usage: narrate-deck.py <deck.md> [voice] [out.mp4]")
    sys.exit(1)
voice = sys.argv[2] if len(sys.argv) > 2 else "af_heart"
out_mp4 = Path(sys.argv[3]) if len(sys.argv) > 3 else deck.with_suffix(".mp4")

stage = deck.parent / "_narrate-stage" / deck.stem
stage.mkdir(parents=True, exist_ok=True)
print(f"deck   : {deck}")
print(f"voice  : {voice}")
print(f"stage  : {stage}")
print(f"output : {out_mp4}")

# ───────────────── pronunciation vocab ─────────────────
# Per-project pronunciation overrides for TTS. Kokoro reads ALL-CAPS as letters
# ("HUB" → "H-U-B") and Title Case as a word ("Hub" → "hub"), so brand names
# spoken as words need a Title Case spelling in the narration text. The vocab
# file lets the project maintain those substitutions in one place instead of
# editing every narration JSON.
#
# Lookup order (first hit wins):
#   1. $NARRATION_VOCAB env var (absolute path)
#   2. <deck dir>/narration-vocab.json
#   3. <deck dir parent>/narration-vocab.json   (repo-root convention)
#   4. <deck dir>/scripts/narration-vocab.json  (alongside Deploy scripts)
#
# Schema:
#   {
#     "pronunciations": {
#       "HUB": "Hub",            # uppercase brand spoken as a word
#       "ERISA": "uh-RISS-uh",   # acronym pronounced as a word — hint phonetics
#       "CashHub": "Cash Hub",   # split camelCase product name
#       "401(k)": "four oh one k"
#     }
#   }
#
# Matching is case-sensitive and whole-word (\b boundaries) — so "HUB"
# substitutes inside "HUB International" but "hub" inside "GitHub" is untouched.
import json as _json_vocab
import os as _os_vocab

PRONUNCIATION_VOCAB: dict[str, str] = {}
PRONUNCIATION_VOCAB_SOURCE: str = ""

def _load_pronunciation_vocab(deck_path: Path) -> tuple[dict, str]:
    candidates = []
    env_path = _os_vocab.environ.get("NARRATION_VOCAB", "")
    if env_path:
        candidates.append(Path(env_path))
    candidates += [
        deck_path.parent / "narration-vocab.json",
        deck_path.parent.parent / "narration-vocab.json",
        deck_path.parent / "scripts" / "narration-vocab.json",
    ]
    for p in candidates:
        if p and p.exists():
            try:
                data = _json_vocab.loads(p.read_text(encoding="utf-8"))
                vocab = data.get("pronunciations", {}) if isinstance(data, dict) else {}
                if isinstance(vocab, dict) and vocab:
                    return ({str(k): str(v) for k, v in vocab.items()}, str(p))
            except Exception as e:
                print(f"  ⚠ couldn't parse vocab file {p}: {e}")
    return ({}, "")

PRONUNCIATION_VOCAB, PRONUNCIATION_VOCAB_SOURCE = _load_pronunciation_vocab(deck)
if PRONUNCIATION_VOCAB:
    print(f"vocab  : {len(PRONUNCIATION_VOCAB)} pronunciations from {PRONUNCIATION_VOCAB_SOURCE}")
else:
    print("vocab  : (none — add narration-vocab.json next to deck or repo root to override pronunciations)")

def apply_pronunciation_vocab(text: str) -> str:
    """Whole-word, case-sensitive substitution for project-specific pronunciations.
    Longer keys first so 'CashHub' substitutes before 'Hub'."""
    if not PRONUNCIATION_VOCAB:
        return text
    for key in sorted(PRONUNCIATION_VOCAB.keys(), key=len, reverse=True):
        repl = PRONUNCIATION_VOCAB[key]
        text = re.sub(rf"(?<!\w){re.escape(key)}(?!\w)", repl, text)
    return text

# ───────────────── parse slides ─────────────────
md = deck.read_text(encoding="utf-8")
md = re.sub(r"^---\r?\n.*?\r?\n---\r?\n", "", md, count=1, flags=re.DOTALL)  # frontmatter
slides_raw = re.split(r"\r?\n---\r?\n", md)
print(f"slides : {len(slides_raw)}")

def parse_blocks(text: str) -> list[tuple[str, str]]:
    """Parse a slide's markdown into [(kind, text), ...] blocks.
    Kinds: 'h1' / 'h2' / 'h3' / 'bullet' / 'paragraph'.
    Comments, code fences, and HTML are stripped. The kind drives the pause
    length that follows the block during synthesis."""
    # Strip comments, code fences, raw HTML tags (keep inner text of tags)
    text = re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL)
    text = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
    text = re.sub(r"<[^>]+>", " ", text)
    # Images and link wrappers
    text = re.sub(r"!\[.*?\]\(.*?\)", "", text)
    text = re.sub(r"\[(.*?)\]\(.*?\)", r"\1", text)

    blocks: list[tuple[str, str]] = []
    paragraph_buf: list[str] = []

    def flush_paragraph():
        if paragraph_buf:
            joined = " ".join(paragraph_buf).strip()
            if joined:
                blocks.append(("paragraph", joined))
        paragraph_buf.clear()

    for raw_line in text.split("\n"):
        line = raw_line.strip()
        if not line:
            flush_paragraph()
            continue
        # Heading: ### Title
        m = re.match(r"^(#{1,6})\s+(.+?)\s*#*$", line)
        if m:
            flush_paragraph()
            level = min(len(m.group(1)), 3)
            blocks.append((f"h{level}", m.group(2).strip()))
            continue
        # Bullet: - item, * item, + item, 1. item
        m = re.match(r"^(?:[-*+]|\d+\.)\s+(.+)$", line)
        if m:
            flush_paragraph()
            # Strip md emphasis markers from bullet text
            bullet = re.sub(r"[*_`]", "", m.group(1)).strip()
            if bullet:
                blocks.append(("bullet", bullet))
            continue
        # Table separators or horizontal rules
        if re.match(r"^[-=|: ]{3,}$", line):
            continue
        # Table row → flatten cells into a comma-separated phrase
        if line.startswith("|"):
            cells = [c.strip() for c in line.strip("|").split("|") if c.strip()]
            if cells:
                paragraph_buf.append(", ".join(cells) + ".")
            continue
        # Regular text — keep emphasis marker stripping minimal so words stay
        cleaned = re.sub(r"[*_`]", "", line).strip()
        if cleaned:
            paragraph_buf.append(cleaned)

    flush_paragraph()
    return blocks

# Pause durations (seconds) inserted *after* each block. Tuned for natural pacing.
PAUSE_AFTER = {
    "h1":        1.0,
    "h2":        0.7,
    "h3":        0.55,
    "bullet":    0.40,
    "paragraph": 0.45,
}
# Additional silence appended to the end of every slide's WAV — gives the
# viewer a breath between slides on top of the trailing-block pause.
SLIDE_END_PAUSE = 0.6


# ───────────────── speakable text normalizer ─────────────────
# Kokoro reads literal characters: "$72" → "dollar 72", "0.5%" → "zero point
# five percent", "401(k)" → "four oh one open paren k close paren". These
# rules rewrite the text into something a human narrator would actually say.
def _money_phrase(value: str, scale: str) -> str:
    scale = scale.lower()
    units = {"k": "thousand", "m": "million", "b": "billion", "t": "trillion"}
    if scale in units:
        return f"{value} {units[scale]} dollars"
    return f"{value} dollars"

def speakable(text: str) -> str:
    """Normalize numbers, currency, percentages, common abbreviations.
    Also strips markdown emphasis markers as a final safety net — these can
    leak through from headings, table cells, callout blocks, etc., and Kokoro
    reads literal asterisks as 'asterisk asterisk Carrier asterisk asterisk'."""
    # Strip markdown emphasis markers FIRST — order matters: ** before *
    text = re.sub(r"\*\*(.+?)\*\*", r"\1", text)   # **bold** → bold
    text = re.sub(r"__(.+?)__",     r"\1", text)   # __bold__ → bold
    text = re.sub(r"~~(.+?)~~",     r"\1", text)   # ~~strike~~ → strike
    text = re.sub(r"(?<!\*)\*(?!\*)([^*\n]+?)\*(?!\*)", r"\1", text)  # *italic*
    text = re.sub(r"(?<!_)_(?!_)([^_\n]+?)_(?!_)",     r"\1", text)   # _italic_
    text = re.sub(r"`+([^`\n]+?)`+", r"\1", text)  # `code` → code
    # Any orphaned markers left over (unmatched **, *, _, `) — drop them
    text = re.sub(r"[*_`]+", "", text)

    # HTML entities (often leak from copy-pasted source or HTML-in-markdown)
    import html as _html
    text = _html.unescape(text)
    # Anything else that's literal & in the wild → "and" (M&A, AT&T, etc.)
    text = re.sub(r"\s*&\s*", " and ", text)

    # Stray formatting characters that aren't useful spoken
    text = text.replace("→", ", then ").replace("·", ", ").replace("—", ", ").replace("–", ", ")
    text = text.replace("…", " ").replace(" ", " ")  # nbsp

    # Approximation prefix
    text = re.sub(r"~\s*\$", "about $", text)
    text = re.sub(r"~\s*(\d)", r"about \1", text)

    # Currency with scale suffix: $4.77B → 4.77 billion dollars, $9M → 9 million dollars
    text = re.sub(
        r"\$(\d+(?:\.\d+)?)\s*([KkMmBbTt])\b",
        lambda m: _money_phrase(m.group(1), m.group(2)),
        text,
    )
    # Currency with magnitude word: $1.6 billion → 1.6 billion dollars
    text = re.sub(
        r"\$(\d+(?:\.\d+)?)\s+(thousand|million|billion|trillion)\b",
        r"\1 \2 dollars",
        text,
        flags=re.IGNORECASE,
    )
    # Plain currency: $5/mo, $9.99, $500K already handled above
    text = re.sub(r"\$(\d+(?:\.\d+)?)(?!\d)", r"\1 dollars", text)

    # Percentages: 25% → 25 percent
    text = re.sub(r"(\d+(?:\.\d+)?)\s*%", r"\1 percent", text)

    # Per-unit: /mo, /yr, /hr
    text = re.sub(r"\s*/\s*mo\b",  " per month",  text, flags=re.IGNORECASE)
    text = re.sub(r"\s*/\s*yr\b",  " per year",   text, flags=re.IGNORECASE)
    text = re.sub(r"\s*/\s*hr\b",  " per hour",   text, flags=re.IGNORECASE)
    text = re.sub(r"\s*/\s*day\b", " per day",    text, flags=re.IGNORECASE)
    text = re.sub(r"\s*/\s*sec\b", " per second", text, flags=re.IGNORECASE)

    # Retirement-plan codes that look like algebra: 401(k) / 403(b) / 457(b)
    text = re.sub(r"\b401\s*\(\s*k\s*\)", "four oh one k",   text, flags=re.IGNORECASE)
    text = re.sub(r"\b403\s*\(\s*b\s*\)", "four oh three b", text, flags=re.IGNORECASE)
    text = re.sub(r"\b457\s*\(\s*b\s*\)", "four fifty seven b", text, flags=re.IGNORECASE)

    # ERISA sections: 3(21) / 3(38) / 3(16) / 408(b)(2) / 404(c)
    text = re.sub(r"\b(?:§|section\s+)?3\s*\(\s*21\s*\)", "section three twenty-one",  text, flags=re.IGNORECASE)
    text = re.sub(r"\b(?:§|section\s+)?3\s*\(\s*38\s*\)", "section three thirty-eight", text, flags=re.IGNORECASE)
    text = re.sub(r"\b(?:§|section\s+)?3\s*\(\s*16\s*\)", "section three sixteen",     text, flags=re.IGNORECASE)
    text = re.sub(r"\b(?:§|section\s+)?408\s*\(\s*b\s*\)\s*\(\s*2\s*\)", "section four oh eight b two", text, flags=re.IGNORECASE)
    text = re.sub(r"\b(?:§|section\s+)?404\s*\(\s*c\s*\)", "section four oh four c", text, flags=re.IGNORECASE)

    # Versions: v2, v3.5
    text = re.sub(r"\bv(\d+(?:\.\d+)?)\b", r"version \1", text)

    # M&A → "M and A"  (commonly used as a verb-adjacent phrase)
    text = re.sub(r"\bM&A\b", "M and A", text)
    text = re.sub(r"\bP&C\b", "P and C", text)

    # Ranges: 5-10 → "five to ten" — only when surrounded by digits + word break
    text = re.sub(r"(\d)\s*[-–]\s*(\d)", r"\1 to \2", text)

    # Decade references: 2026-2027 (after the dash rule above this becomes "2026 to 2027" already)
    # If left untouched, Kokoro reads "2026" as "twenty twenty six" which is fine

    # Common abbreviations that read badly as letters or words
    abbrev_map = {
        r"\be\.g\.": "for example",
        r"\bi\.e\.": "that is",
        r"\betc\.":  "et cetera",
        r"\bvs\.?":  "versus",
        r"\bw/":     "with",
        r"\bw/o":    "without",
        r"\bcf\.":   "compare",
    }
    for pat, repl in abbrev_map.items():
        text = re.sub(pat, repl, text, flags=re.IGNORECASE)

    # Project-specific pronunciation overrides (narration-vocab.json) — applied
    # AFTER the generic rules above so they can override e.g. "HUB" before the
    # abbreviation handlers touch it.
    text = apply_pronunciation_vocab(text)

    # Collapse whitespace from all the substitutions
    text = re.sub(r"\s+", " ", text).strip()
    # Ensure block ends with a period for natural sentence falloff
    if text and text[-1] not in ".!?":
        text += "."
    return text

slide_blocks = [parse_blocks(s) for s in slides_raw]
# Render-friendly per-slide preview text for the log only
narrations = [
    " ".join(b[1] for b in blocks)[:200] or "."
    for blocks in slide_blocks
]

# If a sibling <deck>.narration.json exists, prefer its per-slide narration
# text — that's the LLM-rewritten / hand-authored version that sounds natural.
import json as _json
narration_json_path = deck.with_suffix(".narration.json")
narration_override = None
if narration_json_path.exists():
    print(f"\n[override] using narration from {narration_json_path.name}")
    try:
        data = _json.loads(narration_json_path.read_text(encoding="utf-8"))
        narration_override = data.get("slides", [])
        if len(narration_override) != len(slides_raw):
            print(f"  ⚠ narration JSON has {len(narration_override)} entries but deck has {len(slides_raw)} slides — using JSON for indices in range")
    except Exception as e:
        print(f"  ⚠ couldn't parse narration JSON, falling back to markdown ({e})")
        narration_override = None

# ───────────────── render PNG per slide via marp-cli ─────────────────
# Theme resolution order: $HSO_THEME_CSS env var, project-local themes/,
# learning-pack-builder skill, presentation-builder skill. The project-local
# location is preferred so the pipeline is portable across machines (Windows
# Python can't read WSL ~/.claude paths).
repo_root = deck.parent.resolve()
theme_candidates = [
    Path(__import__("os").environ.get("HSO_THEME_CSS", "")) if __import__("os").environ.get("HSO_THEME_CSS") else None,
    repo_root / "themes" / "hso-theme.css",
    Path(__file__).resolve().parent / "hso-theme.css",
    Path.home() / ".claude" / "skills" / "learning-pack-builder" / "themes" / "hso-theme.css",
    Path.home() / ".claude" / "skills" / "presentation-builder" / "hso-theme.css",
]
theme_css = next((p for p in theme_candidates if p and p.exists()), None)
if theme_css is None:
    print("⚠  HSO theme CSS not found in any candidate location:")
    for p in theme_candidates:
        if p: print(f"     {p}")
    print("    Marp will fall back to default styling. Slides will not match the rest of the pack.")
    sys.exit(2)
print(f"theme  : {theme_css}")
print(f"\n[marp] rendering slide PNGs ...")
png_dir = stage / "png"
png_dir.mkdir(exist_ok=True)
subprocess.run([
    "npx", "--yes", "@marp-team/marp-cli@latest",
    str(deck),
    "--images", "png",
    "--image-scale", "2",
    "--theme-set", str(theme_css),
    "--allow-local-files",
    "-o", str(png_dir / "slide.png"),
], check=True, shell=(sys.platform == "win32"))
pngs = sorted(png_dir.glob("slide.*.png"))
print(f"[marp] {len(pngs)} PNGs rendered")

if len(pngs) != len(narrations):
    print(f"⚠ slide count mismatch: {len(pngs)} pngs vs {len(narrations)} narration chunks — capping at min")
n = min(len(pngs), len(narrations))

# ───────────────── synth audio per slide ─────────────────
print(f"\n[tts] loading Kokoro-82M ...")
from kokoro_onnx import Kokoro
import soundfile as sf

kokoro = Kokoro(str(CACHE / "kokoro-v1.0.onnx"), str(CACHE / "voices-v1.0.bin"))
wav_dir = stage / "wav"
wav_dir.mkdir(exist_ok=True)

def chunk_text(text: str, max_chars: int = 350) -> list[str]:
    """Split text on sentence boundaries; each chunk <= max_chars.
    Kokoro has a 510-token phoneme limit. Phoneme density varies; conservative
    char cap + a try/halve safety net (synth_chunk below) handles edge cases."""
    sentences = re.split(r"(?<=[.!?])\s+", text.strip())
    chunks, current = [], ""
    for s in sentences:
        if not s:
            continue
        if len(current) + len(s) + 1 <= max_chars:
            current = (current + " " + s).strip()
        else:
            if current:
                chunks.append(current)
            while len(s) > max_chars:
                split_at = s.rfind(",", 0, max_chars)
                if split_at < max_chars // 2:
                    split_at = s.rfind(" ", 0, max_chars)
                if split_at <= 0:
                    split_at = max_chars
                chunks.append(s[:split_at].strip())
                s = s[split_at:].strip()
            current = s
    if current:
        chunks.append(current)
    return chunks


def synth_chunk(kokoro, text: str, voice: str, depth: int = 0):
    """Synthesize a chunk; if Kokoro's 510-phoneme limit fires, split in
    half and try each half recursively. Returns (samples, sr)."""
    try:
        return kokoro.create(text, voice=voice, speed=1.0, lang="en-us")
    except IndexError:
        if depth >= 5 or len(text) < 40:
            # Truncate as last resort to avoid infinite recursion
            return kokoro.create(text[:200], voice=voice, speed=1.0, lang="en-us")
        # Split roughly in half on the nearest space/punctuation
        mid = len(text) // 2
        split_at = max(text.rfind(".", 0, mid), text.rfind(",", 0, mid), text.rfind(" ", 0, mid))
        if split_at <= 0:
            split_at = mid
        left = text[:split_at].strip()
        right = text[split_at:].strip()
        import numpy as np
        s1, sr = synth_chunk(kokoro, left, voice, depth + 1)
        s2, _  = synth_chunk(kokoro, right, voice, depth + 1)
        return np.concatenate([s1, s2]), sr

import numpy as np

t0 = time.time()
total_audio = 0.0
for i in range(n):
    wav_path = wav_dir / f"slide-{i+1:03d}.wav"
    if wav_path.exists():
        total_audio += sf.info(wav_path).duration
        print(f"  [{i+1:02d}/{n}] cached")
        continue

    # Prefer JSON-supplied narration when available — that's the hand- or
    # LLM-authored conversational version. Fall back to parsed markdown.
    if narration_override is not None and i < len(narration_override) and narration_override[i].strip():
        # Apply the project pronunciation vocab even to hand-authored narration —
        # that's the whole point of having a vocab file, and the narrator JSON
        # otherwise bypasses speakable().
        spoken_text = apply_pronunciation_vocab(narration_override[i].strip())
        all_samples = []
        sr_out = None
        for ch in chunk_text(spoken_text):
            samples, sr = synth_chunk(kokoro, ch, voice)
            if sr_out is None:
                sr_out = sr
            all_samples.append(samples)
        # No per-block pauses needed — the narration is one continuous flow
    else:
        blocks = slide_blocks[i]
        if not blocks:
            sr_out = 24000
            sf.write(wav_path, np.zeros(int(sr_out * 1.5), dtype=np.float32), sr_out)
            total_audio += 1.5
            print(f"  [{i+1:02d}/{n}]   1.5s  (silent placeholder)")
            continue
        all_samples = []
        sr_out = None
        for kind, block_text in blocks:
            spoken = speakable(block_text)
            if not spoken:
                continue
            for ch in chunk_text(spoken):
                samples, sr = synth_chunk(kokoro, ch, voice)
                if sr_out is None:
                    sr_out = sr
                all_samples.append(samples)
            pause_sec = PAUSE_AFTER.get(kind, 0.35)
            all_samples.append(np.zeros(int(sr_out * pause_sec), dtype=np.float32))

    # Inter-slide pause appended to every slide (natural breath between slides)
    if sr_out is not None:
        all_samples.append(np.zeros(int(sr_out * SLIDE_END_PAUSE), dtype=np.float32))

    merged = np.concatenate(all_samples) if all_samples else np.zeros(0, dtype=np.float32)
    sf.write(wav_path, merged, sr_out or 24000)
    dur = len(merged) / (sr_out or 24000)
    total_audio += dur
    if narration_override is not None and i < len(narration_override) and narration_override[i].strip():
        src_tag = "json"
        print(f"  [{i+1:02d}/{n}] {dur:5.1f}s  ({src_tag}, {len(narration_override[i])} chars)")
    else:
        kinds = " ".join(k for k, _ in slide_blocks[i])
        print(f"  [{i+1:02d}/{n}] {dur:5.1f}s  blocks={len(slide_blocks[i])}  [{kinds}]")
synth_elapsed = time.time() - t0
print(f"[tts] {n} slides in {synth_elapsed:.0f}s; total audio {total_audio:.0f}s ({total_audio/max(synth_elapsed,1):.1f}× realtime)")

# ───────────────── ffmpeg: per-slide segment ─────────────────
print(f"\n[ffmpeg] building per-slide segments ...")
seg_dir = stage / "segments"
seg_dir.mkdir(exist_ok=True)
concat_list = stage / "concat.txt"
lines = []
for i in range(n):
    png = png_dir / f"slide.{i+1:03d}.png"
    wav = wav_dir / f"slide-{i+1:03d}.wav"
    seg = seg_dir / f"seg-{i+1:03d}.mp4"
    if not seg.exists():
        subprocess.run([
            "ffmpeg", "-y", "-loglevel", "error",
            "-loop", "1", "-i", str(png),
            "-i", str(wav),
            "-c:v", "libx264", "-tune", "stillimage", "-pix_fmt", "yuv420p",
            "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2",
            "-c:a", "aac", "-b:a", "192k",
            "-shortest",
            str(seg),
        ], check=True)
    # FFmpeg concat demuxer needs forward-slash absolute paths on Windows.
    # Single-quote-escape per https://trac.ffmpeg.org/wiki/Concatenate
    lines.append(f"file '{seg.resolve().as_posix()}'")
    print(f"  [{i+1:02d}/{n}] {seg.name}")
# Write as ASCII so PowerShell + ffmpeg agree on encoding (no BOM)
concat_list.write_text("\n".join(lines), encoding="ascii")

print(f"\n[ffmpeg] concatenating into {out_mp4} ...")
# Re-encode during concat — AAC priming samples in per-segment files cause
# audio to drift ahead of video at slide boundaries when concat'd with -c copy.
subprocess.run([
    "ffmpeg", "-y", "-loglevel", "error",
    "-f", "concat", "-safe", "0",
    "-i", str(concat_list.resolve()),
    "-c:v", "libx264", "-tune", "stillimage", "-pix_fmt", "yuv420p",
    "-preset", "veryfast", "-crf", "22",
    "-c:a", "aac", "-b:a", "192k",
    "-movflags", "+faststart",
    str(out_mp4.resolve()),
], check=True)

size_mb = out_mp4.stat().st_size / 1_000_000
print(f"\n✓ wrote {out_mp4}")
print(f"  size      : {size_mb:.1f} MB")
print(f"  duration  : {total_audio:.0f}s ({total_audio/60:.1f} min)")
print(f"  slides    : {n}")
