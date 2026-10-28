#!/usr/bin/env python3
"""Converts the Luau used in src/ into plain Lua 5.4/5.5 so it can run in a test harness
(tools/luau_test.py) without Roblox. Line numbers are kept identical, so errors point at the
right line of the original file.

Handles the subset this code base uses:
  type annotations (locals, parameters, return types), `::` casts, `type` / `export type`
  statements, compound assignment (`+=` `-=` `*=` `/=` `//=` `%=` `^=` `..=`), if-expressions,
  `continue`, generalized iteration (`for k, v in t do`).
Not handled (not used here): string interpolation, generic functions, `continue` in repeat loops.
"""
import re
import sys

KEYWORDS = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in",
            "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"}
OPS = ["...", "//=", "..=", "==", "~=", "<=", ">=", "+=", "-=", "*=", "/=", "%=", "^=", "//", "..",
       "::", "->"]
COMPOUND = {"+=": "+", "-=": "-", "*=": "*", "/=": "/", "//=": "//", "%=": "%", "^=": "^", "..=": ".."}
BINARY = {"+", "-", "*", "/", "//", "%", "^", "..", "==", "~=", "<", ">", "<=", ">=", "and", "or"}
UNARY = {"not", "-", "#"}
OPEN = {"(": ")", "[": "]", "{": "}"}
EXPR_BEFORE = {"=", "(", ",", "return", "..", "{", "and", "or", "not", "[", "+", "-", "*", "/", "//",
               "%", "^", "==", "~=", "<", ">", "<=", ">=", "..=", "+=", "-=", "*=", "/=", "//=", "%=",
               "^=", "in", "then", "else", "do"}


class Tok:
    __slots__ = ("kind", "text", "s", "e", "line")

    def __init__(self, kind, text, s, e, line):
        self.kind, self.text, self.s, self.e, self.line = kind, text, s, e, line

    def __repr__(self):
        return f"{self.text}@{self.line}"


def tokenize(src):
    toks, i, n, line = [], 0, len(src), 1
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
                j = n if j < 0 else j + len(m.group(1)) + 2
            else:
                j = src.find("\n", i)
                j = n if j < 0 else j
            line += src[i:j].count("\n")
            i = j
            continue
        m = re.match(r"\[(=*)\[", src[i:])
        if m:
            j = src.find("]" + m.group(1) + "]", i) + len(m.group(1)) + 2
            toks.append(Tok("str", src[i:j], i, j, line))
            line += src[i:j].count("\n")
            i = j
            continue
        if c in "\"'":
            j = i + 1
            while src[j] != c:
                j += 2 if src[j] == "\\" else 1
            toks.append(Tok("str", src[i:j + 1], i, j + 1, line))
            i = j + 1
            continue
        m = re.match(r"[A-Za-z_]\w*", src[i:])
        if m:
            t = m.group(0)
            toks.append(Tok("kw" if t in KEYWORDS else "name", t, i, i + len(t), line))
            i += len(t)
            continue
        m = re.match(r"0[xX][0-9a-fA-F_]+|\d[\d_]*(\.\d*)?([eE][+-]?\d+)?|\.\d+([eE][+-]?\d+)?", src[i:])
        if m:
            toks.append(Tok("num", m.group(0), i, i + len(m.group(0)), line))
            i += len(m.group(0))
            continue
        for op in OPS:
            if src.startswith(op, i):
                toks.append(Tok("op", op, i, i + len(op), line))
                i += len(op)
                break
        else:
            toks.append(Tok("op", c, i, i + 1, line))
            i += 1
    toks.append(Tok("eof", "", n, n, line))
    return toks


class Converter:
    def __init__(self, src):
        self.src = src
        self.t = tokenize(src)
        self.edits = []  # (start, end, text, seq)
        self.seq = 0
        self.removed = set()  # token indexes already removed
        self.ifexpr = set()  # token indexes of `if` that are expressions

    # -- edits --------------------------------------------------------------------------
    def insert(self, pos, text):
        self.seq += 1
        self.edits.append((pos, pos, text, self.seq))

    def remove(self, i, j):
        """Remove tokens i..j-1 (keeping newlines)."""
        if i >= j:
            return
        for k in range(i, j):
            self.removed.add(k)
        s, e = self.t[i].s, self.t[j - 1].e
        self.seq += 1
        self.edits.append((s, e, None, self.seq))

    def apply(self):
        out, pos = [], 0
        for s, e, text, _ in sorted(self.edits, key=lambda x: (x[0], x[1] != x[0], x[3])):
            if s < pos:
                continue  # inside an earlier removal
            out.append(self.src[pos:s])
            if text is None:
                out.append("\n" * self.src[s:e].count("\n") + " ")
            else:
                out.append(text)
            pos = e
        out.append(self.src[pos:])
        return "".join(out)

    # -- scanners -----------------------------------------------------------------------
    def tx(self, i):
        return self.t[i].text

    def skip_group(self, i):
        """i at an opening bracket; returns the index after the matching close."""
        depth = 0
        while True:
            x = self.tx(i)
            if self.t[i].kind == "op" and x in OPEN:
                depth += 1
            elif self.t[i].kind == "op" and x in (")", "]", "}"):
                depth -= 1
                if depth == 0:
                    return i + 1
            elif self.t[i].kind == "eof":
                raise SyntaxError(f"unclosed bracket from line {self.t[i].line}")
            i += 1

    def opens_block(self, i):
        tok = self.t[i]
        if tok.kind != "kw":
            return False
        if tok.text == "if":
            return not (i in self.ifexpr or self.is_ifexpr(i))
        return tok.text in ("function", "do", "repeat")

    def skip_function_body(self, i):
        """i at `function`; returns the index after its matching `end`."""
        depth, k = 0, i
        while True:
            tok = self.t[k]
            if tok.kind == "eof":
                raise SyntaxError(f"unclosed function from line {self.t[i].line}")
            if self.opens_block(k):
                depth += 1
            elif tok.kind == "kw" and tok.text in ("end", "until"):
                depth -= 1
                if depth == 0:
                    return k + 1
            k += 1

    def prev_sig(self, i):
        return self.t[i - 1] if i > 0 else None

    def is_ifexpr(self, i):
        p = self.prev_sig(i)
        return p is not None and p.text in EXPR_BEFORE and p.kind in ("op", "kw") and p.text not in ("then", "else", "do")

    def type_end(self, i):
        """i at the first token of a type expression; returns the index after it."""
        expect = True
        while True:
            tok = self.t[i]
            x = tok.text
            if tok.kind == "name" and x == "typeof" and expect and self.tx(i + 1) == "(":
                i = self.skip_group(i + 1)
                expect = False
            elif tok.kind in ("name",) and expect:
                i += 1
                while self.tx(i) == "." and self.t[i + 1].kind == "name":
                    i += 2
                if self.tx(i) == "<":
                    depth = 0
                    while True:
                        if self.tx(i) == "<":
                            depth += 1
                        elif self.tx(i) == ">":
                            depth -= 1
                            if depth == 0:
                                i += 1
                                break
                        i += 1
                expect = False
            elif tok.kind == "kw" and x in ("nil", "true", "false") and expect:
                i += 1
                expect = False
            elif tok.kind == "str" and expect:
                i += 1
                expect = False
            elif x == "..." and expect:
                i += 1
                expect = False
            elif x in ("(", "{") and tok.kind == "op" and expect:
                i = self.skip_group(i)
                expect = False
            elif x == "?" and not expect:
                i += 1
            elif x in ("|", "&") and not expect:
                i += 1
                expect = True
            elif x == "->" and not expect:
                i += 1
                expect = True
            else:
                return i

    def expr_end(self, i, edit=False):
        """i at the first token of an expression; returns the index after it.
        With edit=True, nested if-expressions are converted as they're met."""
        expect = True
        while True:
            tok = self.t[i]
            x, k = tok.text, tok.kind
            if expect:
                if k == "kw" and x == "if":
                    i = self.convert_ifexpr(i) if edit else self.skip_ifexpr(i)
                    expect = False
                elif k == "kw" and x == "function":
                    i = self.skip_function_body(i)
                    expect = False
                elif (k == "kw" and x == "not") or (k == "op" and x in ("-", "#")):
                    i += 1
                elif k in ("name", "num", "str") or (k == "kw" and x in ("nil", "true", "false")) or x == "...":
                    i += 1
                    expect = False
                elif k == "op" and x in OPEN:
                    i = self.skip_group(i) if not edit else self.edit_group(i)
                    expect = False
                else:
                    return i
            else:
                if k == "op" and x in (".", ":") and self.t[i + 1].kind == "name":
                    i += 2
                elif k == "op" and x in ("(", "["):
                    i = self.skip_group(i) if not edit else self.edit_group(i)
                elif k == "op" and x == "{":
                    i = self.skip_group(i) if not edit else self.edit_group(i)
                elif k == "op" and x == "::":
                    i = self.type_end(i + 1)
                elif x in BINARY:
                    i += 1
                    expect = True
                else:
                    return i

    def edit_group(self, i):
        """Like skip_group but converts if-expressions found inside."""
        close = OPEN[self.tx(i)]
        i += 1
        while self.tx(i) != close:
            if self.t[i].kind == "eof":
                raise SyntaxError("unclosed group")
            if self.tx(i) == "if" and self.t[i].kind == "kw" and self.is_ifexpr(i):
                i = self.convert_ifexpr(i)
            elif self.t[i].kind == "op" and self.tx(i) in OPEN:
                i = self.edit_group(i)
            else:
                i += 1
        return i + 1

    def skip_ifexpr(self, i):
        i = self.expr_end(i + 1)  # condition
        while True:
            assert self.tx(i) in ("then", "else"), f"if-expression near line {self.t[i].line}"
            if self.tx(i) == "then":
                i = self.expr_end(i + 1)
                if self.tx(i) == "elseif":
                    i = self.expr_end(i + 1)
                    continue
            if self.tx(i) == "else":
                return self.expr_end(i + 1)

    def convert_ifexpr(self, i):
        self.ifexpr.add(i)
        self.insert(self.t[i].s, "(function() ")
        i = self.expr_end(i + 1, edit=True)
        while True:
            x = self.tx(i)
            if x == "then":
                self.insert(self.t[i].e, " return ")
                i = self.expr_end(i + 1, edit=True)
                if self.tx(i) == "elseif":
                    i = self.expr_end(i + 1, edit=True)
                    continue
                if self.tx(i) != "else":
                    raise SyntaxError(f"if-expression without else near line {self.t[i].line}")
            elif x == "else":
                self.insert(self.t[i].e, " return ")
                i = self.expr_end(i + 1, edit=True)
                self.insert(self.t[i - 1].e, " end end)()")
                return i
            else:
                raise SyntaxError(f"bad if-expression near line {self.t[i].line}")

    # -- passes -------------------------------------------------------------------------
    def line_start(self, i):
        return i == 0 or self.t[i - 1].line < self.t[i].line

    def pass_type_statements(self):
        i = 0
        while i < len(self.t):
            tok = self.t[i]
            start = i
            if tok.kind == "name" and tok.text == "export" and self.tx(i + 1) == "type" and self.line_start(i):
                i += 1
                tok = self.t[i]
            if tok.kind == "name" and tok.text == "type" and self.line_start(start) and self.t[i + 1].kind == "name" \
                    and self.tx(i + 2) in ("=", "<"):
                j = i + 2
                if self.tx(j) == "<":
                    while self.tx(j) != ">":
                        j += 1
                    j += 1
                assert self.tx(j) == "=", f"type statement near line {tok.line}"
                end = self.type_end(j + 1)
                self.remove(start, end)
                i = end
                continue
            i += 1

    def pass_functions(self):
        for i, tok in enumerate(self.t):
            if not (tok.kind == "kw" and tok.text == "function") or i in self.removed:
                continue
            j = i + 1
            while self.t[j].kind == "name" or self.tx(j) in (".", ":"):
                j += 1
            if self.tx(j) == "<":  # generic parameters
                k = j
                while self.tx(k) != ">":
                    k += 1
                self.remove(j, k + 1)
                j = k + 1
            if self.tx(j) != "(":
                continue
            close = self.skip_group(j) - 1
            k = j + 1
            while k < close:
                if self.tx(k) == ":" and (self.t[k - 1].kind == "name" or self.tx(k - 1) == "..."):
                    end = self.type_end(k + 1)
                    self.remove(k, end)
                    k = end
                else:
                    k += 1
            if self.tx(close + 1) == ":":
                end = self.type_end(close + 2)
                self.remove(close + 1, end)

    def pass_locals(self):
        for i, tok in enumerate(self.t):
            if not (tok.kind == "kw" and tok.text == "local") or self.tx(i + 1) == "function":
                continue
            j = i + 1
            while self.t[j].kind == "name":
                if self.tx(j + 1) == ":":
                    end = self.type_end(j + 2)
                    self.remove(j + 1, end)
                    j = end
                else:
                    j += 1
                if self.tx(j) == ",":
                    j += 1
                else:
                    break

    def pass_casts(self):
        for i, tok in enumerate(self.t):
            if tok.text == "::" and tok.kind == "op" and i not in self.removed:
                self.remove(i, self.type_end(i + 1))

    def pass_ifexprs(self):
        for i, tok in enumerate(self.t):
            if tok.kind == "kw" and tok.text == "if" and i not in self.ifexpr and i not in self.removed and self.is_ifexpr(i):
                self.convert_ifexpr(i)

    def pass_compound(self):
        for i, tok in enumerate(self.t):
            if not (tok.kind == "op" and tok.text in COMPOUND) or i in self.removed:
                continue
            j = self.lhs_start(i - 1)
            lhs = self.src[self.t[j].s:self.t[i - 1].e]
            end = self.expr_end(i + 1)
            self.seq += 1
            self.edits.append((tok.s, tok.e, f"= {lhs} {COMPOUND[tok.text]} (", self.seq))
            self.insert(self.t[end - 1].e, ")")

    def lhs_start(self, j):
        """j at the last token of an assignment target (a, a.b, a[i].c); returns its first token."""
        while True:
            if self.tx(j) == "]":
                depth = 0
                while True:
                    if self.tx(j) == "]":
                        depth += 1
                    elif self.tx(j) == "[":
                        depth -= 1
                        if depth == 0:
                            break
                    j -= 1
                j -= 1  # the expression being indexed
                continue
            if self.t[j].kind == "name":
                if self.tx(j - 1) == "." and j >= 2:
                    j -= 2
                    continue
                return j
            raise SyntaxError(f"can't read assignment target near line {self.t[j].line}")

    def pass_blocks(self):
        """continue -> goto a label before the loop's end; `for ... in X do` -> `in __iter(X) do`."""
        stack, pending, label = [], 0, 0  # stack of [kind, label]; pending = for/while waiting for `do`
        for i, tok in enumerate(self.t):
            x, k = tok.text, tok.kind
            if k == "kw" and x in ("for", "while"):
                pending += 1
                if x == "for":
                    j = i + 1
                    while self.tx(j) not in ("in", "=", "do"):
                        j += 1
                    if self.tx(j) == "in":
                        d, depth = j + 1, 0
                        while not (self.tx(d) == "do" and depth == 0):
                            if self.t[d].kind == "op" and self.tx(d) in OPEN:
                                depth += 1
                            elif self.t[d].kind == "op" and self.tx(d) in (")", "]", "}"):
                                depth -= 1
                            d += 1
                        self.insert(self.t[j].e, " __iter(")
                        self.insert(self.t[d].s, ") ")
            elif self.opens_block(i):
                if x == "do" and pending > 0:
                    pending -= 1
                    stack.append(["loop", None])
                else:
                    stack.append([x, None])
            elif k == "kw" and x in ("end", "until"):
                top = stack.pop()
                if top[1]:
                    self.insert(tok.s, f"::{top[1]}:: ")
            elif k == "name" and x == "continue" and (self.line_start(i) or self.tx(i - 1) in ("then", "do", "else")):
                loop = next(b for b in reversed(stack) if b[0] in ("loop", "repeat"))
                if not loop[1]:
                    label += 1
                    loop[1] = f"__cont{label}"
                self.seq += 1
                self.edits.append((tok.s, tok.e, f"goto {loop[1]}", self.seq))

    def convert(self):
        self.pass_type_statements()
        self.pass_functions()
        self.pass_locals()
        self.pass_casts()
        self.pass_ifexprs()
        self.pass_compound()
        self.pass_blocks()
        return self.apply()


def convert(src):
    return Converter(src).convert()


if __name__ == "__main__":
    print(convert(open(sys.argv[1], encoding="utf-8").read()))
