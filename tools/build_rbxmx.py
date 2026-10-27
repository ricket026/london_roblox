#!/usr/bin/env python3
"""Builds Studio drag-in model files (.rbxmx) from src/, for setting up without Rojo.

Usage: python3 tools/build_rbxmx.py        (writes import/*.rbxmx)

Each output file holds everything for one Studio location. In Studio: delete the old copies
(see import/README.md), right-click the location in the Explorer, Insert from File..., pick the file.
Same naming rules as Rojo: .server.luau = Script, .client.luau = LocalScript, .luau = ModuleScript,
and a folder with init.*.luau becomes that script with the folder's other files inside it.
"""
import os
import sys
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
OUT = os.path.join(ROOT, "import")

# output file -> list of (source path relative to src/, name in Studio or None to use the file's)
FILES = {
    "ReplicatedStorage.rbxmx": [("shared", "Shared"), ("replicated/DESIGN_NOTES.luau", None)],
    "ServerScriptService.rbxmx": [("server/LondonServer", None)],
    "ServerStorage.rbxmx": [("serverstorage/MapGreybox.luau", None), ("serverstorage/MapLayoutData.luau", None)],
    "StarterPlayerScripts.rbxmx": [("client/LondonClient", None)],
    "ReplicatedFirst.rbxmx": [("first/LoadingScreen.client.luau", None)],
}

CLASS_BY_SUFFIX = [(".server.luau", "Script"), (".client.luau", "LocalScript"), (".luau", "ModuleScript")]
ref = 0


def script_info(filename):
    for suffix, cls in CLASS_BY_SUFFIX:
        if filename.endswith(suffix):
            return filename[: -len(suffix)], cls
    return None, None


def item(cls, name, source, children):
    global ref
    ref += 1
    props = f'<string name="Name">{escape(name)}</string>'
    if source is not None:
        if "]]>" in source:
            sys.exit(f"{name}: source contains ']]>' and can't go in CDATA")
        props += f'<ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>'
    inner = "".join(children)
    return f'<Item class="{cls}" referent="RBX{ref:08X}"><Properties>{props}</Properties>{inner}</Item>'


def read(path):
    with open(path, encoding="utf-8", newline="") as f:
        return f.read()


def build(path, name=None):
    full = os.path.join(SRC, path)
    if os.path.isfile(full):
        base, cls = script_info(os.path.basename(full))
        return item(cls, name or base, read(full), [])
    # a folder: a script if it has init.*.luau, else a Folder
    entries = sorted(os.listdir(full))
    init = next((e for e in entries if e.startswith("init.") and e.endswith(".luau")), None)
    children = [build(os.path.join(path, e)) for e in entries if e != init and (e.endswith(".luau") or os.path.isdir(os.path.join(full, e)))]
    folder_name = name or os.path.basename(full)
    if init:
        _, cls = script_info(init)
        return item(cls, folder_name, read(os.path.join(full, init)), children)
    return item("Folder", folder_name, None, children)


def main():
    os.makedirs(OUT, exist_ok=True)
    for out, parts in FILES.items():
        body = "".join(build(p, n) for p, n in parts)
        xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
               'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
               'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
               f"{body}</roblox>")
        with open(os.path.join(OUT, out), "w", encoding="utf-8", newline="") as f:
            f.write(xml)
        print("wrote", os.path.join("import", out))


if __name__ == "__main__":
    main()
