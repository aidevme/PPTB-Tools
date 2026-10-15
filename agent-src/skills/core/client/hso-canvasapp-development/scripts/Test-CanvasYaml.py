#!/usr/bin/env python3
"""
Test-CanvasYaml.py - pre-pack validator for Power Apps canvas .pa.yaml source.

WHY THIS EXISTS
    'pac canvas pack' does NOT validate the YAML it packs - it packs broken YAML happily - and
    'pac canvas validate' was removed in pac 2.10.1. Power Apps Studio is therefore the only
    validator, and the feedback loop through pack -> import -> Studio is minutes long. This
    catches the two failure modes that actually bite, in under a second, before you pack.

WHAT IT CHECKS
    1. The file parses as YAML at all.
    2. THE ': ' TRAP. A property value starting with '=' is a YAML PLAIN scalar, so its double
       quotes are literal characters, not string delimiters. Any ': ' inside the Power Fx is
       then read as a nested mapping and the parse fails - or worse, silently mis-parses.
       The fix is always the same: use a '|' block scalar for that property.
    3. MODERN-VS-CLASSIC property mix-ups. Bare control names ('Label', 'Button', 'TextInput')
       resolve to the MODERN controls, which expose a much smaller property set than the classic
       ones people write from memory. The deny-list below is not guesswork - every entry was
       reported verbatim by Power Apps Studio as "PA2108 : Unknown property '<X>' for control
       type '<Y>'" on the AP-984 import, 2026-08-11.

USAGE
    python Test-CanvasYaml.py <path-to-Src-folder-or-file> [...]

EXIT CODES
    0 = clean, 1 = problems found (details on stdout), 2 = bad invocation.
"""

import os
import re
import sys

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML is required.  pip install pyyaml")
    sys.exit(2)


# A mapping line whose value is a plain scalar starting with '='  ->  "  Text: =\"a: b\""
PLAIN_FORMULA = re.compile(r'^(\s*)([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(=.*?)\s*$')
# A mapping line that opens a block scalar                        ->  "  Text: |"
BLOCK_OPENER = re.compile(r'^(\s*)([A-Za-z_][A-Za-z0-9_]*)\s*:\s*[|>][-+0-9]*\s*$')
CONTROL_LINE = re.compile(r'^\s*Control:\s*(\S+)\s*$', re.MULTILINE)

# Properties the MODERN control does NOT expose, keyed by bare control name.
# Every entry below was reported verbatim by Studio as PA2108 on the AP-984 import (2026-08-11).
# The fix is always the same: use the Classic/ sibling, which owns these.
_RADIUS = ["RadiusTopLeft", "RadiusTopRight", "RadiusBottomLeft", "RadiusBottomRight"]
# value = (denied properties, fix hint). Only claim a Classic/ sibling where one is CONFIRMED to
# exist - Classic/TextInput and Classic/Button are both proven in this repo; Classic/Label is NOT,
# so the honest advice for Label is to drop the properties rather than to guess at a control name.
MODERN_DENY = {
    "Label": (list(_RADIUS),
              "drop these (rounded corners are cosmetic). A 'Classic/Label' is UNCONFIRMED - "
              "do not swap to it on spec, it costs a whole import round trip if wrong."),
    "Button": (["Fill", "HoverFill", "PressedFill", "Color", "HoverColor",
                "PressedColor", "Size"] + _RADIUS,
               "use 'Classic/Button' - CONFIRMED to own all of these."),
    "TextInput": (["Default", "HintText"],
                  "use 'Classic/TextInput' - CONFIRMED to own these."),
}


def scan_text(path, text):
    """Line-level checks that a parsed tree cannot see, because a bad line stops the parse."""
    problems = []
    lines = text.splitlines()

    block_indent = None  # inside a block scalar while indent > this
    for n, line in enumerate(lines, 1):
        stripped = line.strip()

        # Track whether we are inside a '|' block scalar - its contents are exempt.
        if block_indent is not None:
            indent = len(line) - len(line.lstrip())
            if stripped and indent <= block_indent:
                block_indent = None
            else:
                continue

        m = BLOCK_OPENER.match(line)
        if m:
            block_indent = len(m.group(1))
            continue

        m = PLAIN_FORMULA.match(line)
        if m:
            value = m.group(3)
            # The trap: ': ' anywhere inside a plain-scalar Power Fx value.
            if ": " in value:
                problems.append(
                    "%s:%d  THE ': ' TRAP - property '%s' is a PLAIN scalar containing ': '.\n"
                    "        %s\n"
                    "        FIX: make it a '|' block scalar:\n"
                    "            %s: |\n"
                    "              %s"
                    % (path, n, m.group(2), stripped, m.group(2), value)
                )

    return problems


def scan_tree(path, tree):
    """Structural checks against the parsed document."""
    problems = []

    def walk(node, name=None):
        if isinstance(node, dict):
            ctrl = node.get("Control")
            props = node.get("Properties")
            if ctrl in MODERN_DENY and isinstance(props, dict):
                denied, fix = MODERN_DENY[ctrl]
                hits = [p for p in denied if p in props]
                if hits:
                    problems.append(
                        "%s  MODERN/CLASSIC MIX-UP on '%s' - bare '%s' is the MODERN control and "
                        "does not expose: %s\n"
                        "        Studio will reject each with PA2108 'Unknown property'.\n"
                        "        FIX: %s"
                        % (path, name or "?", ctrl, ", ".join(hits), fix)
                    )
            for k, v in node.items():
                walk(v, k if isinstance(k, str) else name)
        elif isinstance(node, list):
            for v in node:
                walk(v)

    walk(tree)
    return problems


def count_controls(text):
    return len(CONTROL_LINE.findall(text))


def check_file(path):
    with open(path, "r", encoding="utf-8-sig") as fh:
        text = fh.read()

    problems = scan_text(path, text)

    try:
        tree = yaml.safe_load(text)
    except yaml.YAMLError as ex:
        problems.append("%s  DOES NOT PARSE AS YAML\n        %s" % (path, str(ex).replace("\n", "\n        ")))
        return problems, 0

    problems.extend(scan_tree(path, tree))
    return problems, count_controls(text)


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2

    targets = []
    for arg in argv[1:]:
        if os.path.isdir(arg):
            for root, _dirs, files in os.walk(arg):
                for f in sorted(files):
                    if f.endswith(".pa.yaml"):
                        targets.append(os.path.join(root, f))
        elif os.path.isfile(arg):
            targets.append(arg)
        else:
            print("ERROR: not found - %s" % arg)
            return 2

    if not targets:
        print("ERROR: no .pa.yaml files found")
        return 2

    all_problems = []
    total_controls = 0
    for t in targets:
        problems, controls = check_file(t)
        total_controls += controls
        all_problems.extend(problems)
        status = "FAIL" if problems else "ok"
        print("  [%s] %s  (%d controls)" % (status, t, controls))

    print("")
    if all_problems:
        print("=== %d PROBLEM(S) - DO NOT PACK ===" % len(all_problems))
        for p in all_problems:
            print("")
            print(p)
        return 1

    print("=== CLEAN - %d file(s), %d controls - safe to pack ===" % (len(targets), total_controls))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
