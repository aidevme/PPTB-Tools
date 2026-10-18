"""Validate skills against the Agent Skills specification with the skills-ref reference library.

Run through validate-skills.ps1, which uses the pinned skills-ref in agent-src/sync/.venv-skills-ref.

Each SKILL.md is read as UTF-8 (skills-ref's own reader uses the platform encoding, cp1252 on Windows), parsed with
skills-ref's parser and checked with its validate_metadata, after setting aside CLIENT_EXTENSION_KEYS: frontmatter
keys a client documents beyond the specification that this repository relies on. Everything else is the
specification's rules unchanged: the allowed fields, name format and folder match, and the length limits.
"""

import sys
from pathlib import Path

from skills_ref.errors import ParseError
from skills_ref.parser import parse_frontmatter
from skills_ref.validator import validate_metadata

# Claude Code reads `argument-hint` from the top level of the frontmatter, so it can't move under `metadata`.
# Add a key here only when a client documents it; repository conventions (layer, scope) belong in `metadata`.
CLIENT_EXTENSION_KEYS = {"argument-hint"}


def skill_dirs(paths: list[str]) -> list[Path]:
    """The skill folders under each path: the path itself when it holds a SKILL.md, else every folder below it."""
    found: list[Path] = []
    for raw in paths:
        path = Path(raw)
        if (path / "SKILL.md").is_file():
            found.append(path)
        elif path.is_dir():
            found.extend(sorted(p.parent for p in path.rglob("SKILL.md")))
        else:
            found.append(path)  # reported as missing below
    return found


def check(skill_dir: Path) -> list[str]:
    """The specification problems in one skill folder; empty when it's valid."""
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.is_file():
        return [f"Missing required file: {skill_md}"]
    try:
        metadata, _ = parse_frontmatter(skill_md.read_text(encoding="utf-8"))
    except ParseError as error:
        return [str(error)]
    spec_metadata = {key: value for key, value in metadata.items() if key not in CLIENT_EXTENSION_KEYS}
    return validate_metadata(spec_metadata, skill_dir)


def main(argv: list[str]) -> int:
    dirs = skill_dirs(argv or ["agent-src/skills"])
    if not dirs:
        print("No SKILL.md found.")
        return 1
    failed = 0
    for skill_dir in dirs:
        problems = check(skill_dir)
        if problems:
            failed += 1
            print(f"FAIL {skill_dir}")
            for problem in problems:
                print(f"     - {problem}")
        else:
            print(f"ok   {skill_dir}")
    print(f"\n{len(dirs) - failed} valid, {failed} invalid (skills-ref, Agent Skills specification).")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
