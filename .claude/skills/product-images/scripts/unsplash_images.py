#!/usr/bin/env python3
"""Find and record Unsplash product photos for the FitzYo demo catalog.

    unsplash_images.py missing                     product ids in seeds.exs with no photo yet
    unsplash_images.py search QUERIES.json WORK/   fetch candidates, thumbnails and a contact sheet
    unsplash_images.py apply  PICKS.json   WORK/   write picks into priv/repo/product_images.exs
                                                   and regenerate the README photo credits

QUERIES.json maps product id -> short search phrase ("women wrap dress").
PICKS.json   maps product id -> candidate index as labelled on the contact sheet.

Requests go through curl on purpose: Unsplash's unofficial search endpoint
sits behind a bot check that rejects Python's TLS fingerprint but lets curl
through. Unsplash+ (paid) photos are filtered out; only images.unsplash.com
photos under the free Unsplash License are kept.
"""

import json
import re
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import urlencode

ROOT = Path(__file__).resolve().parents[4]
SEEDS = ROOT / "priv" / "repo" / "seeds.exs"
IMAGES = ROOT / "priv" / "repo" / "product_images.exs"
README = ROOT / "README.md"
SEARCH = "https://unsplash.com/napi/search/photos"
SIZE = "w=900&h=900&fit=crop&q=80&auto=format"
PER_SHEET = 14
CANDIDATES = 5
THUMBS = 4


# ----------------------------------------------------------------- helpers

def curl(url, params, binary=False):
    out = subprocess.run(
        ["curl", "-sS", "-m", "45", url + "?" + urlencode(params)],
        capture_output=True, check=True,
    ).stdout
    return out if binary else json.loads(out)


def product_names():
    text = SEEDS.read_text()
    return dict(re.findall(r'\{"(prod_\w+)",\s*%\{\s*name: "([^"]+)"', text))


def unescape(s):
    return s.replace('\\"', '"').replace("\\\\", "\\")


def escape(s):
    return (s or "").replace("\\", "\\\\").replace('"', '\\"')


ENTRY = re.compile(
    r'"(prod_\w+)"\s*=>\s*%\{\s*'
    r'url:\s*"((?:[^"\\]|\\.)*)",\s*'
    r'alt:\s*"((?:[^"\\]|\\.)*)",\s*'
    r'photographer:\s*"((?:[^"\\]|\\.)*)",\s*'
    r'username:\s*"((?:[^"\\]|\\.)*)",\s*'
    r'link:\s*"((?:[^"\\]|\\.)*)"\s*\}',
    re.S,
)


def read_images():
    if not IMAGES.exists():
        return {}
    return {
        m.group(1): dict(zip(("url", "alt", "photographer", "username", "link"),
                             map(unescape, m.groups()[1:])))
        for m in ENTRY.finditer(IMAGES.read_text())
    }


def write_images(entries, names):
    lines = [
        "# Product photos for the demo catalog, chosen from Unsplash search results.",
        "#",
        "# Every photo is under the Unsplash License (free to use, no attribution",
        "# required; credit is given here and in the README anyway). Images are",
        "# hotlinked from images.unsplash.com, so the catalog needs network access",
        "# to show them; `product_art` falls back to the color tile otherwise.",
        "#",
        "# Managed by .claude/skills/product-images (the `product-images` skill).",
        "",
        "%{",
    ]
    for pid in sorted(entries):
        e = entries[pid]
        lines += [
            f"  # {names.get(pid, pid)}",
            f'  "{pid}" => %{{',
            f'    url: "{escape(e["url"])}",',
            f'    alt: "{escape(e["alt"])}",',
            f'    photographer: "{escape(e["photographer"])}",',
            f'    username: "{escape(e["username"])}",',
            f'    link: "{escape(e["link"])}"',
            "  },",
        ]
    lines[-1] = lines[-1].rstrip(",")
    lines.append("}")
    IMAGES.write_text("\n".join(lines) + "\n")


def write_credits(entries, names):
    by = {}
    for pid, e in entries.items():
        by.setdefault((e["photographer"], e["username"]), []).append(names.get(pid, pid))
    lines = [
        "## Photo credits",
        "",
        "Product photos are from [Unsplash](https://unsplash.com) under the "
        "[Unsplash License](https://unsplash.com/license), hotlinked from "
        "`images.unsplash.com`. The full list, with links to each photo, is in "
        "`priv/repo/product_images.exs`. Thanks to:",
        "",
    ]
    for (name, user), prods in sorted(by.items(), key=lambda kv: kv[0][0].lower()):
        lines.append(f"- [{name}](https://unsplash.com/@{user}) — {', '.join(sorted(prods))}")
    text = README.read_text()
    marker = "\n## Photo credits"
    text = text[: text.index(marker)] if marker in text else text
    README.write_text(text.rstrip("\n") + "\n\n" + "\n".join(lines) + "\n")


def photo_key(url):
    return url.split("?")[0]


# ---------------------------------------------------------------- commands

def cmd_missing():
    names, have = product_names(), read_images()
    missing = [pid for pid in names if pid not in have]
    for pid in missing:
        print(f"{pid}  {names[pid]}")
    print(f"{len(missing)} of {len(names)} products have no photo", file=sys.stderr)


def cmd_search(queries_path, work):
    queries = json.loads(Path(queries_path).read_text())
    names = product_names()
    work = Path(work)
    (work / "thumbs").mkdir(parents=True, exist_ok=True)
    cand_path = work / "candidates.json"
    cands = json.loads(cand_path.read_text()) if cand_path.exists() else {}

    for pid, query in queries.items():
        data = curl(SEARCH, {"query": query, "per_page": 12, "orientation": "squarish"})
        found = []
        for p in data.get("results", []):
            raw = p["urls"]["raw"]
            if "plus.unsplash.com" in raw or p.get("premium") or p.get("plus"):
                continue
            found.append({
                "id": p["id"],
                "alt": p.get("alt_description") or "",
                "raw": raw.split("?")[0],
                "photographer": p["user"]["name"],
                "username": p["user"]["username"],
                "link": p["links"]["html"],
            })
            if len(found) == CANDIDATES:
                break
        cands[pid] = {"query": query, "candidates": found}
        print(f"{pid}  {query!r}: {len(found)} free candidates", file=sys.stderr)
        for i, c in enumerate(found[:THUMBS]):
            path = work / "thumbs" / f"{pid}_{i}.jpg"
            if not path.exists():
                path.write_bytes(curl(c["raw"], {"w": 200, "h": 200, "fit": "crop", "q": 70, "fm": "jpg"}, binary=True))
        time.sleep(0.4)

    cand_path.write_text(json.dumps(cands, indent=1))
    build_sheets(work, [pid for pid in queries if pid in cands], cands, names)


def build_sheets(work, pids, cands, names):
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("Pillow not installed; skipping contact sheets (thumbs are in WORK/thumbs)", file=sys.stderr)
        return
    T, PAD, LAB = 200, 8, 26
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 15)
    except OSError:
        font = ImageFont.load_default()
    for n, chunk in enumerate(pids[i:i + PER_SHEET] for i in range(0, len(pids), PER_SHEET)):
        im = Image.new("RGB", (LAB * 8 + THUMBS * (T + PAD), len(chunk) * (T + PAD + LAB)), "white")
        d = ImageDraw.Draw(im)
        for r, pid in enumerate(chunk):
            y = r * (T + PAD + LAB)
            d.text((4, y + 4), f"{pid}  {names.get(pid, '')}", fill="black", font=font)
            for i in range(THUMBS):
                x = LAB * 8 + i * (T + PAD)
                path = work / "thumbs" / f"{pid}_{i}.jpg"
                tile = Image.open(path).convert("RGB").resize((T, T)) if path.exists() else Image.new("RGB", (T, T), "#ddd")
                im.paste(tile, (x, y + LAB))
                d.text((x + 4, y + LAB + 2), str(i), fill="red", font=font)
        out = work / f"sheet-{n}.png"
        im.save(out)
        print(f"wrote {out}", file=sys.stderr)


def cmd_apply(picks_path, work, allow_duplicates=False):
    picks = json.loads(Path(picks_path).read_text())
    cands = json.loads((Path(work) / "candidates.json").read_text())
    names, entries = product_names(), read_images()

    for pid, index in picks.items():
        c = cands[pid]["candidates"][index]
        entries[pid] = {
            "url": f"{c['raw']}?{SIZE}",
            "alt": c["alt"],
            "photographer": c["photographer"],
            "username": c["username"],
            "link": c["link"],
        }

    seen = {}
    for pid, e in sorted(entries.items()):
        seen.setdefault(photo_key(e["url"]), []).append(pid)
    dups = {k: v for k, v in seen.items() if len(v) > 1}
    if dups and not allow_duplicates:
        for pids in dups.values():
            print(f"same photo on {', '.join(pids)}; pick another (or pass --allow-duplicates)", file=sys.stderr)
        sys.exit(1)

    write_images(entries, names)
    write_credits(entries, names)
    print(f"{len(picks)} photos applied; {len(entries)} products now have photos.", file=sys.stderr)
    print("Next: mix format priv/repo/product_images.exs && mix run priv/repo/seeds.exs", file=sys.stderr)


if __name__ == "__main__":
    args = sys.argv[1:]
    if args[:1] == ["missing"]:
        cmd_missing()
    elif args[:1] == ["search"] and len(args) == 3:
        cmd_search(args[1], args[2])
    elif args[:1] == ["apply"] and len(args) >= 3:
        cmd_apply(args[1], args[2], allow_duplicates="--allow-duplicates" in args)
    else:
        sys.exit(__doc__)
