#!/usr/bin/env python3
"""Checks INSTALL.md's steps against the code: every script a step adds or replaces (by its GitHub
link, which always shows the latest code) may only wait for modules that are already in the place
or come in that step or an earlier one. A script waiting for a module that isn't there hangs in
Studio, so steps must stay in a valid order as the code changes.

  python3 tools/check_install.py [INSTALL.md]     exit status 1 if a step needs a later one

BASELINE is what the user's place had before the first step listed (INSTALL "Status": M0 and the
character creator). Names that aren't src/ modules (Shared, PlayerGui, Map...) are ignored.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INSTALL = os.path.join(ROOT, "INSTALL.md")
BASELINE = {
    # M0 foundations
    "Config", "Net", "Roles", "Money", "Text", "Types", "Profiles", "Store", "Admin", "AdminLog",
    "Analytics", "Doors", "Debug", "LoadingScreen",
    # step 1: character creator and save slots
    "Stations", "Names", "Looks", "Hobbies", "Identity", "Characters", "CharacterUI",
}


def module_name(rel):
    base = os.path.basename(rel)
    if base.startswith("init."):
        return None if base.endswith((".server.luau", ".client.luau")) else os.path.basename(os.path.dirname(rel))
    return base[: -len(".luau")] if base.endswith(".luau") else None


def all_modules():
    names = {}
    for d, _, files in os.walk(os.path.join(ROOT, "src")):
        for f in files:
            if f.endswith(".luau"):
                rel = os.path.relpath(os.path.join(d, f), ROOT)
                n = module_name(rel)
                if n:
                    names.setdefault(n, []).append(rel)
    return names


def waits_for(rel):
    src = open(os.path.join(ROOT, rel), encoding="utf-8").read()
    return set(re.findall(r'WaitForChild\("([A-Za-z_]+)"', src)) | set(re.findall(r"require\(script\.Parent\.([A-Za-z_]+)\)", src))


def main():
    modules = all_modules()
    text = open(sys.argv[1] if len(sys.argv) > 1 else INSTALL, encoding="utf-8").read()
    steps = re.split(r"^## Step ", text, flags=re.M)[1:]
    have = set(BASELINE)
    problems = 0
    for block in steps:
        title = block.split("\n", 1)[0]
        step = title.split(":")[0]
        links = re.findall(r"\]\(https://github\.com/[^)]*?/blob/[^/]+/(src/[^)]+)\)", block)
        added = {module_name(r) for r in links if module_name(r)}
        have |= added
        for rel in links:
            if not os.path.exists(os.path.join(ROOT, rel)):
                print(f"Step {step}: link to a missing file {rel}")
                problems += 1
                continue
            for dep in sorted(waits_for(rel)):
                if dep in modules and dep not in have:
                    later = next((s.split(":")[0] for s in steps if re.search(r"/" + re.escape(dep) + r"(\.luau|/init\.luau)\)", s)), None)
                    print(f"Step {step}: {rel} waits for {dep}, which {'comes in step ' + later if later else 'no step adds'}")
                    problems += 1
    print(f"{len(steps)} steps checked: {problems} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
