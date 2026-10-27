#!/usr/bin/env python3
"""Static checks for the Luau in src/ when Studio isn't available (e.g. cloud agents).

Usage: python3 tools/check_luau.py [src_dir]          exit code 1 if anything is found

Checks:
  structure   every function/if/for/while/do/repeat block is closed, brackets balance
              (a missing `end` stops a whole script from loading)
  references  Module.field / Config.FIELD / A.helper used anywhere is defined in that module
              (typos only fail at runtime, when the line runs)
  unused      locals and local functions defined but never used (leftovers from edits)

Not a type checker: Studio's Script Analysis (or luau-lsp) still has the final word.
The checks were validated against deliberately broken copies (a deleted `end`, an extra `end`,
a missing bracket, three misspelt references); keep them catching those if you change this file.
"""
import glob
import os
import re
import sys
from collections import defaultdict

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "src"))
FILES = sorted(glob.glob(os.path.join(ROOT, "**", "*.luau"), recursive=True))
problems = []


def report(path, line, msg):
    problems.append(f"{os.path.relpath(path, ROOT)}:{line}: {msg}")


# --- tokenizer ---------------------------------------------------------------------------
def tokens(src):
    i, n, line = 0, len(src), 1
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if c.isspace():
            i += 1
            continue
        if src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:])
            if m:
                j = src.find("]" + m.group(1) + "]", i)
                line += src[i:j].count("\n")
                i = j + len(m.group(1)) + 2
            else:
                j = src.find("\n", i)
                i = n if j < 0 else j
            continue
        m = re.match(r"\[(=*)\[", src[i:])
        if m:
            j = src.find("]" + m.group(1) + "]", i)
            line += src[i:j].count("\n")
            yield ("<str>", line)
            i = j + len(m.group(1)) + 2
            continue
        if c in "\"'`":
            j = i + 1
            while src[j] != c:
                j += 2 if src[j] == "\\" else 1
            yield ("<str>", line)
            i = j + 1
            continue
        m = re.match(r"[A-Za-z_]\w*", src[i:])
        if m:
            yield (m.group(0), line)
            i += len(m.group(0))
            continue
        m = re.match(r"0x[0-9a-fA-F_]+|\d[\d_]*(\.\d+)?([eE][+-]?\d+)?", src[i:])
        if m:
            yield ("<num>", line)
            i += len(m.group(0))
            continue
        for op in ("...", "..=", "==", "~=", "<=", ">=", "+=", "-=", "*=", "/=", "//", "..", "::", "->"):
            if src.startswith(op, i):
                yield (op, line)
                i += len(op)
                break
        else:
            yield (c, line)
            i += 1


# an `if` after one of these starts an if-expression, which takes no `end`
EXPR_BEFORE = {"=", "(", ",", "return", "..", "{", "and", "or", "not", "[", "+", "-", "*", "/",
               "==", "~=", "<", ">", "<=", ">=", "..=", "+=", "-=", "in"}
PAIRS = {"(": ")", "{": "}", "[": "]"}


def check_structure(path, src):
    stack, prev = [], None
    for t, line in tokens(src):
        if t in PAIRS:
            stack.append((t, line))
        elif t in PAIRS.values():
            top = stack.pop() if stack else None
            if not top or PAIRS.get(top[0]) != t:
                report(path, line, f"'{t}' doesn't match {top[0] + ' from line ' + str(top[1]) if top else 'anything'}")
                return
        elif t == "if" and prev not in EXPR_BEFORE:
            stack.append(("if", line))
        elif t in ("function", "for", "while", "repeat"):
            stack.append((t, line))
        elif t == "do":
            if stack and stack[-1][0] in ("for", "while"):
                stack[-1] = ("loop", stack[-1][1])
            else:
                stack.append(("do", line))
        elif t == "until":
            top = stack.pop() if stack else None
            if not top or top[0] != "repeat":
                report(path, line, "'until' without 'repeat'")
                return
        elif t == "end":
            top = stack.pop() if stack else None
            if not top or top[0] not in ("if", "function", "loop", "do"):
                report(path, line, f"'end' with nothing to close{' (inside ' + top[0] + ' from line ' + str(top[1]) + ')' if top else ''}")
                return
        prev = t
    for kind, line in stack:
        report(path, line, f"'{kind}' opened here is never closed")


# --- references ----------------------------------------------------------------------------
def strip(src):
    src = re.sub(r"--\[(=*)\[.*?\]\1\]", "", src, flags=re.S)
    src = re.sub(r'"(\\.|[^"\\\n])*"', '""', src)
    return re.sub(r"--[^\n]*", "", src)


def module_name(path):
    base = os.path.basename(path)
    return os.path.basename(os.path.dirname(path)) if base.startswith("init.") else base.split(".")[0]


REQUIRE = re.compile(r'local (\w+)\s*=\s*require\([^\n]*?(?:WaitForChild\("(\w+)"\)|script\.Parent(?:\.Parent)?\.(\w+))\)')


def check_references():
    defs = defaultdict(set)
    for f in FILES:
        s = strip(open(f, encoding="utf-8").read())
        m = module_name(f)
        tbl = re.search(r"^local (\w+) = \{\}", s, re.M)
        t = tbl.group(1) if tbl else m
        defs[m] |= set(re.findall(r"\b" + t + r"\.([A-Za-z_]\w*)\s*=[^=]", s))
        defs[m] |= set(re.findall(r"function " + t + r"[.:]([A-Za-z_]\w*)", s))
        defs[m] |= set(re.findall(r"export type (\w+)", s))
        if m == "Net":
            defs["Net.V"] = set(re.findall(r"function V\.(\w+)", s))
    for f in FILES:
        raw = open(f, encoding="utf-8").read()
        s = strip(raw)
        aliases = {a: (b or c) for a, b, c in REQUIRE.findall(raw)}
        if os.sep + os.path.join("LondonServer", "Activities") + os.sep in f and not os.path.basename(f).startswith("init."):
            aliases["A"] = "Activities"  # activity modules get the framework passed in as A
        for alias, mod in aliases.items():
            if mod not in defs:
                continue
            for m in re.finditer(r"\b" + alias + r"\.([A-Za-z_]\w*)", s):
                name = m.group(1)
                if name not in defs[mod] and not (mod == "Net" and name == "V"):
                    report(f, s[: m.start()].count("\n") + 1, f"{alias}.{name} is not defined in {mod}")
        for m in re.finditer(r"\bV\.(\w+)\(", s):
            if m.group(1) not in defs["Net.V"]:
                report(f, s[: m.start()].count("\n") + 1, f"V.{m.group(1)} is not a Net validator")


# --- unused --------------------------------------------------------------------------------
# Known and harmless: helpers in the user's original greybox builder, kept on purpose.
KNOWN_UNUSED = {("MapGreybox", "ROADMAT"), ("MapGreybox", "tPoly"), ("MapGreybox", "tDisc")}


def check_unused(path, src):
    s = strip(src)
    for m in re.finditer(r"^\s*local (?:function )?(\w+)", s, re.M):
        name = m.group(1)
        if (module_name(path), name) in KNOWN_UNUSED:
            continue
        if len(re.findall(r"(?<![\w.:])" + name + r"\b", s)) <= 1:
            report(path, s[: m.start()].count("\n") + 1, f"'{name}' is defined but never used")


for f in FILES:
    src = open(f, encoding="utf-8").read()
    check_structure(f, src)
    check_unused(f, src)
check_references()

for p in problems:
    print(p)
print(f"{len(FILES)} files checked: {len(problems)} problem(s)")
sys.exit(1 if problems else 0)
