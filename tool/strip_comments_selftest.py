"""Self-test for tool/strip_comments.py.

Asserts the stripper removes comments while leaving string literals and
build-critical directives intact. Run before applying it to the tree.
"""

import importlib.util
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "sc", Path(__file__).resolve().parent / "strip_comments.py"
)
sc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sc)

D = chr(36)
results = []


def check(name, got, want):
    ok = got == want
    results.append(ok)
    print(("[PASS] " if ok else "[FAIL] ") + name)
    if not ok:
        print("        got : " + repr(got))
        print("        want: " + repr(want))


check(
    "// inside a URL string is not a comment",
    sc.strip_slash_comments('final u = "https://x.com/a";\n'),
    'final u = "https://x.com/a";\n',
)
check(
    "email string containing no slash is untouched",
    sc.strip_slash_comments('// c\nfinal e = "you@example.com or username";\n'),
    'final e = "you@example.com or username";\n',
)
check(
    "raw regex string is untouched",
    sc.strip_slash_comments('// c\nstatic final _re = RegExp(r"^[a-z0-9._-]+' + D + '");\n'),
    'static final _re = RegExp(r"^[a-z0-9._-]+' + D + '");\n',
)
check(
    "escaped quote does not end the string early",
    sc.strip_slash_comments('// c\nfinal s = "a\\"//notcomment";\n'),
    'final s = "a\\"//notcomment";\n',
)
check(
    "inline block comment keeps a separator",
    sc.strip_slash_comments("/* hi */ void f() {}\n"),
    " void f() {}\n",
)
check(
    "block comment on its own line is removed cleanly",
    sc.strip_slash_comments("void f() {\n  /* hi */\n  g();\n}\n"),
    "void f() {\n  g();\n}\n",
)
check(
    "string interpolation is preserved verbatim",
    sc.strip_slash_comments('// c\nfinal s = "' + D + '{a} // b";\n'),
    'final s = "' + D + '{a} // b";\n',
)
check(
    "triple-quoted string is preserved verbatim",
    sc.strip_slash_comments('// c\nfinal s = """a // b""";\n'),
    'final s = """a // b""";\n',
)
check(
    "@Suppress annotation survives",
    sc.strip_slash_comments('@Suppress("DEPRECATION")\nNotification.Builder(this)\n'),
    '@Suppress("DEPRECATION")\nNotification.Builder(this)\n',
)
check(
    "// ignore: analyzer directive survives",
    sc.strip_slash_comments("// ignore: foo\nvoid f() {}\n"),
    "// ignore: foo\nvoid f() {}\n",
)
check(
    "trailing // comment is removed",
    sc.strip_slash_comments("final a = 1; // note\nfinal b = 2;\n"),
    "final a = 1;\nfinal b = 2;\n",
)
check(
    "leading blank lines are dropped",
    sc.strip_slash_comments("// a\n// b\nfinal x = 1;\n"),
    "final x = 1;\n",
)
check(
    "hash comments, quoting respected",
    sc.strip_hash_comments('a: 1  # trailing\n# whole\nb: "x # y"\n'),
    'a: 1\n\nb: "x # y"\n',
)
check(
    "xml block comments removed",
    sc.strip_block_comments("<a>\n  <!-- c -->\n  <b/>\n</a>\n"),
    "<a>\n  <b/>\n</a>\n",
)

print()
print("ALL PASS" if all(results) else f"{results.count(False)} FAILED")
sys.exit(0 if all(results) else 1)
