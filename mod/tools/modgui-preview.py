#!/usr/bin/env python3
"""Render a String machine modgui the way mod-ui does, and take its pictures.

The icon template is filled with the default port values read from the
plugin .ttl (knob/slider frames, switch states, value displays), the modgui
script is run with a mod-ui-like 'start' event, and a headless Chromium takes
the picture. It then writes the modgui screenshot and thumbnail.

Usage (from the repository root, after `make mod`):
    python3 mod/tools/modgui-preview.py bin/mod/string-machine.lv2 [--jquery PATH]

Writes, inside the *source* modgui folder (mod/modgui/<name>/modgui/):
    screenshot-<name>.png   full-size panel
    thumbnail-<name>.png    192 px wide
and leaves the intermediate page in build/modgui-preview/<name>.html.

Needs Pillow and a Chromium (chromium, chromium-browser or google-chrome).
jQuery is looked up in a few usual places (a mod-ui checkout, node_modules,
/usr/share/javascript); pass --jquery if none is found.
"""

import argparse
import glob
import math
import os
import re
import shutil
import subprocess
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
THUMB_WIDTH = 192


def find_jquery(explicit):
    candidates = [explicit] if explicit else []
    candidates += glob.glob(os.path.expanduser("~/mod-ui/html/js/lib/jquery-1*.min.js"))
    candidates += glob.glob(os.path.expanduser("~/dev/mod-audio/mod-ui/html/js/lib/jquery-1*.min.js"))
    candidates += ["/usr/share/javascript/jquery/jquery.min.js"]
    candidates += glob.glob(os.path.join(ROOT, "node_modules/jquery/dist/jquery.min.js"))
    for c in candidates:
        if c and os.path.isfile(c):
            return c
    sys.exit("jQuery not found, pass --jquery /path/to/jquery.min.js")


def find_chromium():
    for name in ("chromium", "chromium-browser", "google-chrome", "google-chrome-stable"):
        path = shutil.which(name)
        if path:
            return path
    sys.exit("no Chromium found")


def parse_ports(ttl):
    """Return {symbol: info} for the control ports of a DPF-generated .ttl."""
    ports = {}
    for block in re.split(r"\]\s*,\s*\[|lv2:port\s*\[", ttl):
        m = re.search(r'lv2:symbol "([^"]+)"', block)
        if not m or "ControlPort" not in block:
            continue
        info = {"output": "OutputPort" in block}
        for key in ("default", "minimum", "maximum"):
            v = re.search(r"lv2:%s ([-0-9.e]+)" % key, block)
            info[key] = float(v.group(1)) if v else None
        info["log"] = "logarithmic" in block
        info["integer"] = "lv2:integer" in block
        info["toggled"] = "lv2:toggled" in block
        info["enum"] = "lv2:enumeration" in block
        u = re.search(r"unit:unit unit:(\w+)", block)
        info["unit"] = {"hz": "Hz", "db": "dB", "s": "s", "pc": "%"}.get(u.group(1), "") if u else ""
        u = re.search(r'unit:symbol "([^"]*)"', block)
        if u:
            info["unit"] = u.group(1)
        ports[m.group(1)] = info
    return ports


def normalized(info, value):
    lo, hi = info["minimum"], info["maximum"]
    if info["log"] and lo > 0:
        return math.log(value / lo) / math.log(hi / lo)
    return (value - lo) / (hi - lo)


def fmt(info, value):
    if info["integer"] or info["enum"] or info["toggled"]:
        text = "%d" % round(value)
    else:
        text = "%.2f" % value
    return (text + " " + info["unit"]).strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("bundle")
    ap.add_argument("--jquery")
    args = ap.parse_args()

    bundle = os.path.abspath(args.bundle)
    name = os.path.basename(bundle)[:-len(".lv2")]
    modgui_ttl = open(os.path.join(bundle, "modgui.ttl")).read()

    def res(key):
        m = re.search(r"modgui:%s <([^>]+)>" % key, modgui_ttl)
        return os.path.join(bundle, m.group(1)) if m else None

    html = open(res("iconTemplate")).read()
    css = open(res("stylesheet")).read()
    js_path = res("javascript")
    js = open(js_path).read() if js_path else None
    resdir = res("resourcesDirectory")

    plugin_ttl = open(os.path.join(bundle, name + ".ttl")).read()
    ports = parse_ports(plugin_ttl)

    # --- mustache bits handled by mod-ui
    html = re.sub(r"\{\{#[^}]*\}\}.*?\{\{/[^}]*\}\}", "", html, flags=re.S)
    html = html.replace("{{{cns}}}", "")
    css = css.replace("{{{cns}}}", "").replace("{{{ns}}}", "")
    css = css.replace("url(/resources/", "url(file://%s/" % resdir)

    # --- default values, applied the way the mod-ui widgets do it
    def control(m):
        tag = m.group(0)
        sym = re.search(r'mod-port-symbol="([^"]+)"', tag).group(1)
        info = ports[sym]
        value = info["default"]
        if 'mod-widget="switch"' in tag:
            state = "off" if value == info["minimum"] else "on"
            return tag.replace('class="', 'class="%s ' % state, 1)
        steps = 30  # 31-frame filmstrips
        frame = round(max(0.0, min(1.0, normalized(info, value))) * steps)
        width = 200 if "sm-slider" in tag else 60
        return tag.replace(">", ' style="background-position:%dpx 0">' % (-frame * width), 1)

    html = re.sub(r'<div[^>]*mod-role="input-control-port"[^>]*>', control, html)

    def value_display(m):
        sym = m.group(1)
        return m.group(0) + fmt(ports[sym], ports[sym]["default"])

    html = re.sub(r'<div[^>]*mod-role="input-control-value"[^>]*mod-port-symbol="([^"]+)"[^>]*>',
                  value_display, html)
    html = html.replace('sm-bypass-light"', 'sm-bypass-light on"')  # plugin enabled

    def start_value(info):
        if info["default"] is not None:
            return info["default"]
        # outputs have no default: show meters at rest and readouts at zero
        if info["unit"] == "dB":
            return info["minimum"]
        return max(info["minimum"], min(0.0, info["maximum"]))

    start_ports = ",".join('{symbol:"%s",value:%r}' % (s, start_value(i)) for s, i in ports.items())
    runner = ""
    if js:
        runner = "<script>var smGui = (%s);\nsmGui({type:'start', ports:[%s], icon:$('.mod-pedal'), data:{}}, {});</script>" % (
            js.strip(), start_ports)

    page = """<!DOCTYPE html><html><head><meta charset="utf-8">
<style>html,body{margin:0;padding:0;background:transparent;} #stage{display:inline-block;padding:24px;}
.mod-pedal-input,.mod-pedal-output,.mod-drag-handle{display:none;}</style>
<style>%s</style>
<script src="file://%s"></script>
</head><body><div id="stage">%s</div>%s</body></html>""" % (css, find_jquery(args.jquery), html, runner)

    outdir = os.path.join(ROOT, "build", "modgui-preview")
    os.makedirs(outdir, exist_ok=True)
    page_path = os.path.join(outdir, name + ".html")
    open(page_path, "w").write(page)

    shot = os.path.join(outdir, name + "-raw.png")
    subprocess.run([find_chromium(), "--headless", "--disable-gpu", "--hide-scrollbars",
                    "--allow-file-access-from-files", "--default-background-color=00000000",
                    "--force-device-scale-factor=1", "--virtual-time-budget=2000",
                    "--window-size=1600,1200", "--screenshot=" + shot, "file://" + page_path],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    img = Image.open(shot).convert("RGBA")
    img = img.crop(img.getchannel("A").getbbox())
    srcdir = os.path.join(ROOT, "mod", "modgui", name, "modgui")
    img.save(os.path.join(srcdir, "screenshot-%s.png" % name), optimize=True)
    th = img.resize((THUMB_WIDTH, round(img.height * THUMB_WIDTH / img.width)), Image.LANCZOS)
    th.save(os.path.join(srcdir, "thumbnail-%s.png" % name), optimize=True)
    print("%s: screenshot %dx%d, thumbnail %dx%d" % (name, img.width, img.height, th.width, th.height))


if __name__ == "__main__":
    main()
