#!/usr/bin/env python3
"""Drop comments and indentation from a built bundle, and PROVE nothing else changed.

Every execute makes the client compile the whole bundle text, and roughly 40% of dist/ez-rbx-ui.lua
is comments and indentation. This removes them and nothing else. It is not obfuscation and not
minification: names, strings and statements are untouched, and every newline is kept, so a runtime
error still points at the same line of the same bundle.

The proof: the input and the output are compiled by PUC `luac` (5.x) under the same chunk name,
WITH line information, and the two bytecode files must be byte-identical; otherwise nothing is
written and the exit code is 1. PUC luac is used because LuaJIT's bytecode is not deterministic
(its string-hash seed is random, so one file compiled twice differs). No luac, no output: the
script refuses rather than ship an unverified bundle.

    python3 scripts/slim.py dist/ez-rbx-ui.lua            # in place
    python3 scripts/slim.py in.lua out.lua
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile

LONG_OPEN = re.compile(r'\[(=*)\[')


def _long_bracket(src: str, at: int) -> tuple[int | None, int]:
    m = LONG_OPEN.match(src, at)
    return (len(m.group(1)), m.end()) if m else (None, 0)


def slim(src: str) -> str:
    out, i, n = [], 0, len(src)
    line_start = True
    while i < n:
        c = src[i]
        if line_start and c in ' \t':
            i += 1
            continue
        line_start = False
        if c == '-' and src.startswith('--', i):
            level, end = _long_bracket(src, i + 2)
            if level is not None:  # --[==[ block comment ]==]: keep only the newlines it spanned
                close = ']' + '=' * level + ']'
                j = src.find(close, end)
                if j < 0:
                    raise ValueError('unterminated block comment at offset %d' % i)
                out.append('\n' * src.count('\n', i, j + len(close)))
                i = j + len(close)
                continue
            j = src.find('\n', i)  # line comment: up to, not including, its newline
            i = n if j < 0 else j
            continue
        if c in '"\'':  # short string, copied verbatim (escapes included)
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == '\\':
                    j += 1
                elif src[j] == '\n':
                    raise ValueError('unfinished string at offset %d' % i)
                j += 1
            out.append(src[i:j + 1])
            i = j + 1
            continue
        if c == '[':
            level, end = _long_bracket(src, i)
            if level is not None:  # long string, copied verbatim
                close = ']' + '=' * level + ']'
                j = src.find(close, end)
                if j < 0:
                    raise ValueError('unterminated long string at offset %d' % i)
                out.append(src[i:j + len(close)])
                i = j + len(close)
                continue
        if c == '\n':
            while out and out[-1] in (' ', '\t'):
                out.pop()
            out.append('\n')
            i += 1
            line_start = True
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def find_luac() -> str | None:
    for name in ('luac5.4', 'luac5.3', 'luac5.1', 'luac'):
        path = shutil.which(name)
        if path:
            return path
    return None


def same_bytecode(luac: str, a_text: str, b_text: str) -> bool:
    """Compile both under the same chunk name, with line info; True when byte-identical."""
    with tempfile.TemporaryDirectory() as tmp:
        outs = []
        for tag, text in (('a', a_text), ('b', b_text)):
            d = os.path.join(tmp, tag)
            os.mkdir(d)
            with open(os.path.join(d, 'bundle.lua'), 'w', encoding='utf-8') as f:
                f.write(text)
            res = subprocess.run([luac, '-o', 'out.luac', 'bundle.lua'], cwd=d, capture_output=True, text=True)
            if res.returncode != 0:
                raise RuntimeError('luac rejected the %s side: %s' % (
                    'input' if tag == 'a' else 'output', res.stderr.strip()))
            with open(os.path.join(d, 'out.luac'), 'rb') as f:
                outs.append(f.read())
        return outs[0] == outs[1]


def main(argv: list[str]) -> int:
    if len(argv) not in (2, 3):
        print(__doc__.strip().splitlines()[-2].strip(), file=sys.stderr)
        return 2
    src_path = argv[1]
    dst_path = argv[2] if len(argv) == 3 else src_path
    luac = find_luac()
    if not luac:
        print('slim: no PUC luac found (luac5.4/luac); refusing to write an unverified bundle', file=sys.stderr)
        return 1
    with open(src_path, encoding='utf-8') as f:
        src = f.read()
    out = slim(src)
    if not same_bytecode(luac, src, out):
        print('slim: %s compiles differently once slimmed; nothing written' % src_path, file=sys.stderr)
        return 1
    with open(dst_path, 'w', encoding='utf-8') as f:
        f.write(out)
    before, after = len(src.encode('utf-8')), len(out.encode('utf-8'))
    print('slim: %s %d -> %d bytes (%.0f%%), bytecode and line numbers identical'
          % (dst_path, before, after, 100.0 * after / before))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
