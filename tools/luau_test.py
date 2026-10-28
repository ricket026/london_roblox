#!/usr/bin/env python3
"""Runs tests/*.luau against the real modules in src/ without Roblox.

Usage: python3 tools/luau_test.py [tests/test_x.luau ...]     exit code 1 on any failure

How: each src file is converted to plain Lua (tools/luau2lua.py, line numbers kept), placed in a
script tree built from default.project.json (so script.Parent / WaitForChild resolve like in
Studio), and run in Lua with tools/luau_prelude.lua standing in for the engine. Tests use
test(name, fn), eq(a, b), ok(x), near(a, b), raises(fn) and the __ helpers in the prelude
(__addPlayer, __removePlayer, __advance(seconds), __received(player, remote, action), __find(path)).

This checks logic, not the engine: Studio Play-tests are still needed for physics, UI looks,
replication and anything the prelude fakes.
"""
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from luau2lua import convert  # noqa: E402
from lupa import LuaRuntime  # noqa: E402

CLASS_BY_SUFFIX = [(".server.luau", "Script"), (".client.luau", "LocalScript"), (".luau", "ModuleScript")]
_cache = {}


def source(path):
    if path not in _cache:
        with open(os.path.join(ROOT, path), encoding="utf-8") as f:
            _cache[path] = convert(f.read())
    return _cache[path]


def script_class(filename):
    for suffix, cls in CLASS_BY_SUFFIX:
        if filename.endswith(suffix):
            return filename[: -len(suffix)], cls
    return None, None


def build_tree(lua):
    project = json.load(open(os.path.join(ROOT, "default.project.json")))
    make = lua.globals().__makeScript
    new = lua.globals().__newInstance
    game = lua.globals().game

    def from_path(parent, name, rel):
        full = os.path.join(ROOT, rel)
        if os.path.isfile(full):
            base, cls = script_class(os.path.basename(full))
            make(parent, name or base, cls, rel)
            return
        entries = sorted(os.listdir(full))
        init = next((e for e in entries if e.startswith("init.") and e.endswith(".luau")), None)
        if init:
            node = make(parent, name, script_class(init)[1], os.path.join(rel, init))
        else:
            node = new("Folder", name)
            node.Parent = parent
        for e in entries:
            if e == init:
                continue
            if e.endswith(".luau"):
                from_path(node, None, os.path.join(rel, e))
            elif os.path.isdir(os.path.join(full, e)):
                from_path(node, e, os.path.join(rel, e))

    def walk(parent, tree):
        for key, val in tree.items():
            if key.startswith("$"):
                continue
            if "$path" in val:
                from_path(parent, key, val["$path"])
                continue
            if parent is game:
                child = game.GetService(game, key)
            else:
                child = parent.FindFirstChild(parent, key)
                if child is None:
                    child = new(val.get("$className", "Folder"), key)
                    child.Parent = parent
            walk(child, val)

    walk(game, project["tree"])


def run_file(path):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().__source = source
    with open(os.path.join(HERE, "luau_prelude.lua"), encoding="utf-8") as f:
        lua.execute(f.read())
    build_tree(lua)
    with open(path, encoding="utf-8") as f:
        code = convert(f.read())
    chunk = lua.globals().load(code, "@" + os.path.relpath(path, ROOT))
    if not isinstance(chunk, tuple) and chunk is None:
        raise SystemExit(f"{path}: failed to compile")
    if isinstance(chunk, tuple):
        fn, err = chunk
        if fn is None:
            print(f"  COMPILE ERROR {err}")
            return 0, 1
        chunk = fn
    try:
        chunk()
    except Exception as e:  # an error outside test() blocks
        print(f"  ERROR loading {path}: {e}")
        return 0, 1
    res = lua.globals().__results
    for i in range(1, len(res.failures) + 1):
        f = res.failures[i]
        print(f"  FAIL {f.name}\n    " + str(f.err).replace("\n", "\n    "))
    return res.passed, res.failed


def main():
    files = sys.argv[1:] or sorted(glob.glob(os.path.join(ROOT, "tests", "test_*.luau")))
    total_p = total_f = 0
    for f in files:
        p, n = run_file(f)
        total_p += p
        total_f += n
        print(f"{os.path.relpath(f, ROOT)}: {p} passed, {n} failed")
    print(f"\n{total_p} passed, {total_f} failed")
    sys.exit(1 if total_f else 0)


if __name__ == "__main__":
    main()
