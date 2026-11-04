#!/usr/bin/env python3
"""Build the Dailies page: every piece made for the game, waiting for Javier's pick (CLAUDE.md, Assets; Karatecation
L-9). Javier & Claude, 2026-11-03.

Makes the free drafts fresh (scripts/art/style_frames.py, scripts/audio/make_music.py, scripts/audio/make_sfx.py) into
approvals/site/ (git-ignored), then writes approvals/site/index.html (approvals/template.html + the list of pieces) and
approvals/site/files.json, the published-path -> source map for the Artifact publish's `files`.

Usage: scripts/build_dailies.py          Logs to logs/build-dailies-<stamp>.log, ends with an OK line.
"""
import json
import pathlib
import subprocess
import sys
import time

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SITE = ROOT / "approvals" / "site"
sys.path.insert(0, str(ROOT / "scripts" / "audio"))
from make_sfx import WHERE as SFX_WHERE  # noqa: E402


LOG = None


def say(msg):
    print(msg, flush=True)
    LOG.write(msg + "\n"); LOG.flush()


def run(*cmd):
    say("$ " + " ".join(str(c) for c in cmd))
    r = subprocess.run([sys.executable, "-I", *map(str, cmd)], capture_output=True, text=True)
    for line in (r.stdout + r.stderr).splitlines():
        say("  " + line)
    if r.returncode:
        say(f"FAILED {cmd[0].name} (exit {r.returncode})")
        sys.exit(1)


def main():
    global LOG
    stamp = time.strftime("%Y%m%d-%H%M%S")
    (ROOT / "logs").mkdir(exist_ok=True)
    log = ROOT / "logs" / f"build-dailies-{stamp}.log"
    LOG = open(log, "w")
    latest = ROOT / "logs" / "build-dailies-latest.log"
    latest.unlink(missing_ok=True)
    latest.symlink_to(log.name)
    img, audio, sfx = SITE / "img", SITE / "audio", SITE / "audio" / "sfx"
    for d in (img, sfx):
        d.mkdir(parents=True, exist_ok=True)
    run(ROOT / "scripts/art/style_frames.py", img)
    run(ROOT / "scripts/audio/make_music.py", audio / "music-level1.ogg")
    run(ROOT / "scripts/audio/make_sfx.py", sfx)
    for k in "abc":  # thumbnails for the grid; the full frame opens large
        Image.open(img / f"frame-{k}.png").convert("RGB").resize((960, 540), Image.LANCZOS).save(img / f"frame-{k}-thumb.jpg", quality=88)
    manifest = {
        "built": time.strftime("%d %b %H:%M"),
        "sections": [
            {"id": "look", "title": "The look", "kind": "scenery",
             "note": "Three ways to draw the game, the same moment each time: the hero in his stance facing a thug on "
                     "level 1's street after rain. I drew these myself for $0 to choose a direction; they're not the game "
                     "art. Click one to see it large, then pick it. The picked direction goes to ChatGPT for the real "
                     "pictures: 6 to start, $0 extra on your ChatGPT Plus, and only after your yes.",
             "items": [{"id": "style-frame", "title": "Pick a direction",
                        "where": "A has bold outlines and flat colour, B has no outlines and soft glow, C has a rough "
                                 "comic line with dots. Every one keeps the neon rim light on the fighters.",
                        "takes": [{"label": f"{k.upper()} · {name}", "thumb": f"img/frame-{k}-thumb.jpg", "full": f"img/frame-{k}.png"}
                                  for k, name in (("a", "Neon ink"), ("b", "Soft glow"), ("c", "Grit comic"))]}]},
            {"id": "arc", "title": "Neon to grit", "kind": "clip",
             "note": "The same street lit for each level, from level 1's bright neon to level 10's rust and red light. "
                     "The places' names are working names; you name them for real.",
             "items": [{"id": "colour-arc", "title": "The colour of each level",
                        "where": "The signs and the sky change; the fighters' clothes stay the same, so it reads as the "
                                 "city going dark, not the hero.",
                        "media": [{"type": "img", "src": "img/arc.png"}]}]},
            {"id": "music", "title": "Music", "kind": "music",
             "note": "Made the same free way as the 45-second test you have: our own notes, every instrument built by "
                     "our own script, no singing. It loops, so a long fight never goes quiet.",
             "items": [{"id": "music-level1", "title": "Level 1 · Neon Row",
                        "where": "A minute, looping. The street (pads and arpeggio), the fight (full beat and the lead), "
                                 "the hook (brighter, the lead up high), a breather, and a build back to the top.",
                        "meta": "124 beats a minute · E minor, lifting to G major in the hook", "src": "audio/music-level1.ogg"}]},
            {"id": "sfx", "title": "Sound effects", "kind": "sfx",
             "note": "Three takes of each, so a repeated hit doesn't sound robotic. Voices (grunts and screams) come "
                     "with the pain system.",
             "items": [{"id": "sfx-" + name, "title": name.replace("_", " ").capitalize(), "where": where,
                        "variants": [{"name": f"take {k}", "src": f"audio/sfx/{name}-{k}.ogg"} for k in (1, 2, 3)]}
                       for name, where in SFX_WHERE.items()]},
        ],
    }
    tpl = (ROOT / "approvals" / "template.html").read_text()
    (SITE / "index.html").write_text(tpl.replace("__MANIFEST__", json.dumps(manifest).replace("</", "<\\/")))
    files = {str(p.relative_to(SITE)): str(p.relative_to(ROOT)) for p in sorted(SITE.rglob("*"))
             if p.is_file() and p.suffix in (".png", ".jpg", ".ogg")}
    (SITE / "files.json").write_text(json.dumps(files, indent=1))
    size = sum((ROOT / v).stat().st_size for v in files.values())
    say(f"OK dailies: {len(files)} files ({size / 1e6:.1f} MB) in {SITE.relative_to(ROOT)}, built {manifest['built']} ({stamp})")


if __name__ == "__main__":
    main()
