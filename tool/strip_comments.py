"""Strip comments from source files without touching string literals.

A naive regex pass corrupts this codebase: `'you@example.com or username'`
contains a `//`-like sequence, `RegExp(r'^[a-z0-9._-]+$')` contains `//`-free
but quote-heavy content, and `'https://api.github.com/repos'` contains a real
`//`. So this walks each file with a small state machine that understands
string literals (including Dart raw/triple-quoted strings and `$interpolation`)
and only discards text that the compiler treats as a comment.

Functional directives are preserved: `@Suppress(...)` annotations, `// ignore:`
analyzer directives and `# pragma:` lines are not comments in any meaningful
sense - deleting them changes the build.

Usage:
    python tool/strip_comments.py [--check] [paths...]
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# Slash-comment languages (Dart, Kotlin, Java, JS, C-family).
SLASH_EXTS = {".dart", ".kt", ".kts", ".java", ".js", ".jsx", ".ts"}

# Hash-comment languages handled line-wise.
HASH_EXTS = {".yaml", ".yml", ".properties", ".cmake", ".pro", ".rc",
             ".ps1", ".psm1", ".sh", ".conf", ".toml"}

# Block-comment-only markup.
XML_EXTS = {".xml", ".plist", ".storyboard", ".xib", ".entitlements",
            ".xcworkspacedata", ".xcscheme", ".xcsettings", ".manifest",
            ".rules", ".html", ".pbxproj", ".lock", ".metadata"}

# Lines that look like comments but are consumed by tooling.
DIRECTIVE_RE = re.compile(
    r"^\s*(@Suppress\b|//\s*ignore:|//\s*ignore_for_file:|#\s*pragma:|"
    r"#\s*noqa|//\s*noinspection|#\s*ignore|eslint-|@ts-|#\s*type:)"
)

TRIPLE_QUOTES = ('"""', "'''")


def _blank_collapse(text: str) -> str:
    """Drop trailing spaces and squeeze runs of blank lines down to one."""
    out: list[str] = []
    blanks = 0
    for line in text.split("\n"):
        line = line.rstrip()
        if line:
            blanks = 0
            out.append(line)
        else:
            blanks += 1
            if blanks <= 1:
                out.append("")
    # A comment that occupied its own line leaves the line empty; do not let
    # that accumulate at the top of the file or just before a closing brace.
    while out and not out[0]:
        out.pop(0)
    while out and not out[-1]:
        out.pop()
    collapsed: list[str] = []
    for line in out:
        if not line and collapsed:
            prev = collapsed[-1]
            # A blank line left behind by removing a comment is incidental when
            # it sits next to a brace or before indented code. Blank lines that
            # deliberately separate declarations start at column 0, so those
            # survive.
            if prev.strip() in ("{", "}", "</", "") or line != line.lstrip() or prev != prev.lstrip():
                continue
        collapsed.append(line)
    return "\n".join(collapsed) + "\n"


def strip_slash_comments(src: str) -> str:
    """Remove // and /* */ comments, honouring string literals and raw strings."""
    out: list[str] = []
    i, n = 0, len(src)
    # Interpolation depth for Dart `$id` / `${expr}` inside a string.
    interp: list[int] = []

    while i < n:
        ch = src[i]

        # Line comment.
        if ch == "/" and i + 1 < n and src[i + 1] == "/":
            line_start = src.rfind("\n", 0, i) + 1
            if DIRECTIVE_RE.match(src[line_start:i] + src[i:i + 40]):
                j = src.find("\n", i)
                j = n if j < 0 else j
                out.append(src[i:j])
                i = j
                continue
            j = src.find("\n", i)
            i = n if j < 0 else j
            # Trim whitespace the removed comment left behind.
            while out and out[-1] in (" ", "\t"):
                out.pop()
            continue

        # Block comment.
        if ch == "/" and i + 1 < n and src[i + 1] == "*":
            j = src.find("*/", i + 2)
            end = n if j < 0 else j + 2
            # Was anything but whitespace before the comment on this line?
            line_start = src.rfind("\n", 0, i) + 1
            if src[line_start:i].strip():
                while out and out[-1] in (" ", "\t"):
                    out.pop()
                if out and out[-1] not in ("", "\n", "(", "[", "{"):
                    out.append(" ")
            else:
                while out and out[-1] in (" ", "\t"):
                    out.pop()
                # The comment occupied a whole line, so drop the blank line it
                # leaves behind (but keep the final newline of the file).
                if out and out[-1] == "\n":
                    out.pop()
                    front = "".join(out)
                    if front.rstrip("\n").strip():
                        out = [front]
            i = end
            continue

        # String literal.
        if ch in ('"', "'"):
            triple = src[i:i + 3] in TRIPLE_QUOTES
            quote = src[i:i + 3] if triple else ch
            # Raw strings (Dart r'...') take no escapes.
            raw = i > 0 and src[i - 1] == "r" and (
                i < 2 or not (src[i - 2].isalnum() or src[i - 2] == "_")
            )
            out.append(quote)
            i += len(quote)
            while i < n:
                if not raw and src[i] == "\\":
                    out.append(src[i:i + 2])
                    i += 2
                    continue
                if src.startswith(quote, i):
                    out.append(quote)
                    i += len(quote)
                    break
                if not raw and src[i] == "$" and not triple:
                    # Dart interpolation: emit it verbatim so braces inside the
                    # expression are not mistaken for code structure.
                    if i + 1 < n and src[i + 1] == "{":
                        out.append("${")
                        i += 2
                        depth = 1
                        while i < n and depth:
                            if src[i] == "{":
                                depth += 1
                            elif src[i] == "}":
                                depth -= 1
                            out.append(src[i])
                            i += 1
                        continue
                    m = re.match(r"\$[A-Za-z_][A-Za-z0-9_]*", src[i:])
                    if m:
                        out.append(m.group(0))
                        i += len(m.group(0))
                        continue
                out.append(src[i])
                i += 1
            continue

        out.append(ch)
        i += 1

    return _blank_collapse("".join(out))


def strip_hash_comments(src: str) -> str:
    """Remove whole-line and trailing # comments, honouring quotes."""
    out: list[str] = []
    for line in src.split("\n"):
        if DIRECTIVE_RE.match(line):
            out.append(line.rstrip())
            continue
        stripped = _strip_trailing_hash(line)
        out.append(stripped.rstrip())
    return _blank_collapse("\n".join(out))


def _strip_trailing_hash(line: str) -> str:
    quote: str | None = None
    for idx, ch in enumerate(line):
        if quote:
            if ch == quote:
                quote = None
            continue
        if ch in ('"', "'"):
            quote = ch
            continue
        # A '#' starting a line, or preceded by whitespace, begins a comment.
        if ch == "#" and (idx == 0 or line[idx - 1] in " \t"):
            return line[:idx]
    return line


def strip_block_comments(src: str) -> str:
    """Remove <!-- ... --> blocks, leaving quoted attribute text alone."""
    out: list[str] = []
    i, n = 0, len(src)
    while i < n:
        if src.startswith("<!--", i):
            j = src.find("-->", i + 4)
            i = n if j < 0 else j + 3
            # Drop indentation the comment occupied.
            while out and out[-1] in (" ", "\t"):
                out.pop()
            if out and out[-1] == "\n" and src.startswith("\n", i):
                i += 1
            continue
        out.append(src[i])
        i += 1
    return _blank_collapse("".join(out))


def strip_file(path: Path) -> tuple[str, str]:
    original = path.read_text(encoding="utf-8")
    ext = path.suffix.lower()
    if ext in SLASH_EXTS:
        updated = strip_slash_comments(original)
    elif ext in HASH_EXTS:
        updated = strip_hash_comments(original)
    elif ext in XML_EXTS:
        updated = strip_block_comments(original)
    else:
        raise ValueError(f"unsupported extension: {path}")
    return original, updated


def collect_targets(explicit: list[str]) -> list[Path]:
    if explicit:
        return [Path(p) if Path(p).is_absolute() else REPO / p for p in explicit]
    exts = SLASH_EXTS | HASH_EXTS | XML_EXTS
    roots = ["lib", "test", "android/app/src/main", "tool", "firebase_tests"]
    # Root-level config that also carries comments.
    roots += ["analysis_options.yaml", "pubspec.yaml"]
    skip_dirs = {"build", ".dart_tool", "node_modules", ".git", ".gradle"}
    found: list[Path] = []
    for root in roots:
        base = REPO / root
        if base.is_file():
            if base.suffix.lower() in exts:
                found.append(base)
            continue
        if not base.exists():
            continue
        for path in base.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in exts:
                continue
            if any(part in skip_dirs for part in path.parts):
                continue
            found.append(path)
    return sorted(found)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true",
                        help="report files that still contain comments")
    parser.add_argument("paths", nargs="*")
    args = parser.parse_args()

    targets = collect_targets(args.paths)
    changed = 0
    failures: list[str] = []

    for path in targets:
        try:
            original, updated = strip_file(path)
        except Exception as exc:  # noqa: BLE001 - surfaced below
            failures.append(f"{path}: {exc}")
            continue
        if original != updated:
            changed += 1
            if args.check:
                print(f"has comments: {path.relative_to(REPO)}")
            else:
                path.write_text(updated, encoding="utf-8")

    if failures:
        print("FAILED:", file=sys.stderr)
        for f in failures:
            print(f"  {f}", file=sys.stderr)
        return 2

    verb = "would change" if args.check else "updated"
    print(f"{verb} {changed} of {len(targets)} files")
    return 1 if args.check and changed else 0


if __name__ == "__main__":
    raise SystemExit(main())
