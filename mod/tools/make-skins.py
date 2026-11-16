#!/usr/bin/env python3
"""Convert the original String machine skins into MOD modgui filmstrips.

The desktop UI (plugins/string-machine/artwork/images) stores its widgets as
*vertical* filmstrips at 1x. mod-ui's `film` widget expects *horizontal*
filmstrips (it counts frames along the width), so every strip is re-laid out
horizontally and upscaled for the larger modgui panel.

Usage (from the repository root, needs Pillow):
    python3 mod/tools/make-skins.py

The result is committed under mod/modgui/common/images/, so building the MOD
bundles never needs Python or Pillow.
"""

import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "plugins", "string-machine", "artwork", "images")
DST = os.path.join(ROOT, "mod", "modgui", "common", "images")

SCALE = 2

# name -> (frame width, frame height) in the original 1x vertical strip
SKINS = {
    "knob": (30, 30),
    "slider": (100, 25),
    "vu": (95, 11),
    "led": (9, 9),
    "toggle-button": (35, 15),
    "value-display": (40, 12),
}


def convert(name, fw, fh):
    src = Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")
    if src.width != fw or src.height % fh != 0:
        sys.exit("%s: unexpected size %dx%d" % (name, src.width, src.height))
    frames = src.height // fh
    out = Image.new("RGBA", (fw * SCALE * frames, fh * SCALE))
    for i in range(frames):
        frame = src.crop((0, i * fh, fw, (i + 1) * fh))
        frame = frame.resize((fw * SCALE, fh * SCALE), Image.LANCZOS)
        out.paste(frame, (i * fw * SCALE, 0))
    path = os.path.join(DST, name + ".png")
    out.save(path, optimize=True)
    print("%-22s %2d frame(s) of %dx%d -> %s" % (name, frames, fw * SCALE, fh * SCALE,
                                                os.path.relpath(path, ROOT)))


def main():
    os.makedirs(DST, exist_ok=True)
    for name, (fw, fh) in SKINS.items():
        convert(name, fw, fh)


if __name__ == "__main__":
    main()
