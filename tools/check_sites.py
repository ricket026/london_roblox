#!/usr/bin/env python3
"""Checks the map positions in src/shared/Config.luau against the place file and the map layout.

For every site (NPC counters in Config.COUNTERS, newsboy corners, and the activity sites
DUCKS_SITE, STRENGTH_SITE, MUDLARK_SIGN, CHESS_TABLES, decree boards, event places) it reports the park / square it is in and any problems:
  ERROR  on a building lot (Workspace.Map.Plots), on a road's carriageway, or inside a landmark
  note   a pavement, or a part within a few studs (kerbs, walls: often intended)
Exit status 1 if any site has an ERROR. Needs: pip install lz4 zstandard

  python3 tools/check_sites.py            # all sites
  python3 tools/check_sites.py -600,-2132 # also check these x,z points
"""
import collections
import json
import math
import os
import re
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, "src", "shared", "Config.luau")
LAYOUT = os.path.join(ROOT, "map_layout_v2.json")
PLACE = os.path.join(ROOT, "london.rbxl")
# folders under Workspace.Map that are markers, not solid ground (same list as LondonServer.World)
SKIP_MAP = ("JobSites", "Labels", "CabRanks", "BusStops", "Routes", "Bounds", "Spawns", "Landmarks_Greybox", "Roads")
FOOTPRINT = 3  # studs around a site that must be clear of lots, roads and landmarks


# --- place file (binary .rbxl): parts' paths, sizes and CFrames ------------------------------
def _il(b, n):
    return [(b[i] << 24) | (b[n + i] << 16) | (b[2 * n + i] << 8) | b[3 * n + i] for i in range(n)]


def _zz(v):
    return (v >> 1) ^ -(v & 1)


def _rf(v):
    bits = ((v >> 1) | ((v & 1) << 31)) & 0xFFFFFFFF
    return struct.unpack(">f", bits.to_bytes(4, "big"))[0]


def _cum(a):
    s, r = 0, []
    for x in a:
        s += _zz(x)
        r.append(s)
    return r


def read_parts(path):
    import lz4.block
    import zstandard

    data = open(path, "rb").read()
    p = 32
    classes, inst, props, parent = {}, {}, collections.defaultdict(dict), {}
    while p < len(data):
        name = data[p : p + 4]
        cl, ul = struct.unpack_from("<II", data, p + 4)
        p += 16
        if cl == 0:
            body = data[p : p + ul]
            p += ul
        else:
            raw = data[p : p + cl]
            p += cl
            if raw[:4] == b"\x28\xb5\x2f\xfd":
                body = zstandard.ZstdDecompressor().decompress(raw, max_output_size=ul)
            else:
                body = lz4.block.decompress(raw, uncompressed_size=ul)
        if name == b"INST":
            cid, ln = struct.unpack_from("<II", body, 0)
            cn = body[8 : 8 + ln].decode()
            q = 8 + ln + 1
            cnt = struct.unpack_from("<I", body, q)[0]
            q += 4
            refs = _cum(_il(body[q:], cnt))
            classes[cid] = (cn, refs)
            for r in refs:
                inst[r] = cn
        elif name == b"PROP":
            cid, ln = struct.unpack_from("<II", body, 0)
            pn = body[8 : 8 + ln].decode()
            t = body[8 + ln]
            q = 9 + ln
            refs = classes[cid][1]
            n = len(refs)
            if t == 1 and pn == "Name":
                for r in refs:
                    l = struct.unpack_from("<I", body, q)[0]
                    q += 4
                    props[r]["Name"] = body[q : q + l].decode("utf-8", "replace")
                    q += l
            elif t == 0x0E and pn == "size":
                xs = [_rf(v) for v in _il(body[q:], n)]
                q += 4 * n
                ys = [_rf(v) for v in _il(body[q:], n)]
                q += 4 * n
                zs = [_rf(v) for v in _il(body[q:], n)]
                for r, x, y, z in zip(refs, xs, ys, zs):
                    props[r]["Size"] = (x, y, z)
            elif t == 0x10 and pn == "CFrame":
                rots = []
                for _ in refs:
                    i = body[q]
                    q += 1
                    if i == 0:
                        rots.append(struct.unpack_from("<9f", body, q))
                        q += 36
                    else:
                        rots.append(i)
                xs = [_rf(v) for v in _il(body[q:], n)]
                q += 4 * n
                ys = [_rf(v) for v in _il(body[q:], n)]
                q += 4 * n
                zs = [_rf(v) for v in _il(body[q:], n)]
                for r, x, y, z, ro in zip(refs, xs, ys, zs, rots):
                    props[r]["Pos"] = (x, y, z)
                    props[r]["Rot"] = ro
        elif name == b"PRNT":
            cnt = struct.unpack_from("<I", body, 1)[0]
            q = 5
            ch = _cum(_il(body[q:], cnt))
            q += 4 * cnt
            pa = _cum(_il(body[q:], cnt))
            parent.update(zip(ch, pa))
        elif name == b"END\0":
            break

    def path(r):
        s = []
        while r in inst:
            s.append(props[r].get("Name", inst[r]))
            r = parent.get(r, -1)
        return ".".join(reversed(s))

    out = []
    for r, c in inst.items():
        pr = props[r]
        if "Pos" in pr and "Size" in pr and c != "Terrain":
            pth = path(r)
            if pth.startswith("Workspace."):
                out.append((pth, aabb(pr["Pos"], pr["Size"], pr["Rot"])))
    return out


NORMALS = [(1, 0, 0), (0, 1, 0), (0, 0, 1), (-1, 0, 0), (0, -1, 0), (0, 0, -1)]


def aabb(pos, size, rot):
    """World box of a part. rot is a 3x3 matrix (row-major) or an .rbxl rotation id."""
    if isinstance(rot, int):  # id - 1: x axis = N[(id-1)//6], y axis = N[(id-1)%6], z = x cross y
        X, Y = NORMALS[(rot - 1) // 6], NORMALS[(rot - 1) % 6]
        Z = (X[1] * Y[2] - X[2] * Y[1], X[2] * Y[0] - X[0] * Y[2], X[0] * Y[1] - X[1] * Y[0])
        R = [X[0], Y[0], Z[0], X[1], Y[1], Z[1], X[2], Y[2], Z[2]]
    else:
        R = rot
    h = (size[0] / 2, size[1] / 2, size[2] / 2)
    e = [sum(abs(R[3 * i + j]) * h[j] for j in range(3)) for i in range(3)]
    return (pos[0] - e[0], pos[0] + e[0], pos[1] - e[1], pos[1] + e[1], pos[2] - e[2], pos[2] + e[2])


# --- sites from Config ---------------------------------------------------------------------
def read_sites():
    src = open(CONFIG, encoding="utf-8").read()
    sites = []
    for m in re.finditer(r'id = "(\w+)", kind = "\w+", name = "[^"]+", x = (-?[\d.]+), z = (-?[\d.]+)', src):
        sites.append(("counter " + m.group(1), float(m.group(2)), float(m.group(3))))
    for key in ("DUCKS_SITE", "STRENGTH_SITE", "MUDLARK_SIGN", "SPAWN_POINT"):
        m = re.search(r"Config\." + key + r" = \{ x = (-?[\d.]+), z = (-?[\d.]+) \}", src)
        if m:
            sites.append((key, float(m.group(1)), float(m.group(2))))
    for t in re.finditer(r'id = "(\w+)", title = "[^"]+", place = "[^"]+", x = (-?[\d.]+), z = (-?[\d.]+)', src):
        sites.append(("appointment " + t.group(1), float(t.group(2)), float(t.group(3))))
    m = re.search(r"Config\.NEWSBOY_CORNERS = \{(.*?)\n\}", src, re.S)
    if m:
        for t in re.finditer(r'name = "([^"]+)", x = (-?[\d.]+), z = (-?[\d.]+)', m.group(1)):
            sites.append(("corner " + t.group(1), float(t.group(2)), float(t.group(3))))
    for t in re.finditer(r'place = "([^"]+)", x = (-?[\d.]+), z = (-?[\d.]+), radius', src):
        sites.append(("event at " + t.group(1), float(t.group(2)), float(t.group(3))))
    m = re.search(r"Config\.DECREE_BOARDS = \{(.*?)\n\}", src, re.S)
    if m:
        for t in re.finditer(r'name = "([^"]+)", x = (-?[\d.]+), z = (-?[\d.]+)', m.group(1)):
            sites.append(("decree board " + t.group(1), float(t.group(2)), float(t.group(3))))
    m = re.search(r"Config\.CHESS_TABLES = \{(.*)\}\n", src)
    if m:
        for k, t in enumerate(re.finditer(r"x = (-?[\d.]+), z = (-?[\d.]+)", m.group(1))):
            sites.append((f"CHESS_TABLES[{k + 1}]", float(t.group(1)), float(t.group(2))))
    return sites


# --- checks --------------------------------------------------------------------------------
def segdist(px, pz, a, b):
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    L = dx * dx + dz * dz
    t = 0 if L == 0 else max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / L))
    return math.hypot(px - (ax + t * dx), pz - (az + t * dz))


def inbox(o, x, z, pad=0):
    xs, zs = sorted(o["x"]), sorted(o["z"])
    return xs[0] - pad <= x <= xs[1] + pad and zs[0] - pad <= z <= zs[1] + pad


def check(x, z, layout, parts):
    errors, notes, tags = [], [], []
    cls = layout["classes"]
    for rd in layout["roads"]:
        w, pave = cls[rd["c"]]["w"] / 2, cls[rd["c"]]["p"]
        dist = min(segdist(x, z, a, b) for a, b in zip(rd["p"], rd["p"][1:]))
        if dist < w + FOOTPRINT:
            errors.append(f"on the carriageway of {rd['n']} ({dist:.1f} from its centre; half-width {w:g})")
        elif dist <= w + pave:
            notes.append(f"pavement of {rd['n']}")
    for o in layout["landmarks"]:
        if "x" in o and inbox(o, x, z, FOOTPRINT):
            errors.append("inside landmark " + o["n"])
    for name, (x0, x1, _, _, z0, z1) in parts:
        if x1 >= x - FOOTPRINT and x0 <= x + FOOTPRINT and z1 >= z - FOOTPRINT and z0 <= z + FOOTPRINT:
            short = name.replace("Workspace.Map.", "")
            segs = name.split(".")
            if len(segs) > 2 and segs[1] == "Map" and segs[2] in SKIP_MAP:
                continue
            if ".Plots." in name:
                errors.append("on building lot " + segs[-1])
            else:
                notes.append("near " + short)
    for k in ("parks", "gardens", "plazas", "promenades"):
        for o in layout[k]:
            if "x" in o and inbox(o, x, z):
                tags.append(o["n"] or k[:-1])
    return errors, notes, tags


def main():
    layout = json.load(open(LAYOUT, encoding="utf-8"))
    parts = read_parts(PLACE)
    sites = read_sites()
    for a in sys.argv[1:]:
        x, z = map(float, a.split(","))
        sites.append((a, x, z))
    bad = 0
    for name, x, z in sites:
        errors, notes, tags = check(x, z, layout, parts)
        where = ", ".join(tags) or "street"
        print(f"{'ERROR' if errors else 'ok   '} {name:34} ({x:g}, {z:g})  {where}")
        for e in errors:
            print("        ERROR " + e)
        for n in sorted(set(notes))[:4]:
            print("        note  " + n)
        bad += 1 if errors else 0
    print(f"\n{len(sites)} sites checked: {bad} with errors")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
