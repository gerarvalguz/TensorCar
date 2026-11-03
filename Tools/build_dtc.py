"""Builds Sources/DTC.json, the offline fault-code dictionary, from OBDex's generic.json.

OBDex data is CC0 (public domain): https://github.com/foerbsnavi/OBDex
Usage: curl -LO https://foerbsnavi.github.io/OBDex/generic.json
       python3 Tools/build_dtc.py generic.json Sources/DTC.json
"""
import json
import sys

src, dst = sys.argv[1], sys.argv[2]
out = {}
for e in json.load(open(src, encoding="utf-8")):
    en = lambda v: (v or {}).get("en", "").strip()
    out[e["code"].upper()] = {
        "t": en(e.get("title")),
        "d": en(e.get("description")),
        "c": [en(c.get("label")) for c in e.get("common_causes", []) if en(c.get("label"))],
        "s": [en(s) for s in e.get("symptoms", []) if en(s)],
    }
json.dump(out, open(dst, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"), sort_keys=True)
print(f"{len(out)} codes -> {dst}")
