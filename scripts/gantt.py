#!/usr/bin/env python3
"""Build the Gantt page and its done marks. Javier & Claude.

    scripts/gantt.py <out-dir>

Reads docs/schedule.json (the plan) and TODO.md (the ticks). Writes:
  <out-dir>/gantt.html     docs/gantt/gantt.html with the schedule filled in (publish it to the Gantt's link)
  <out-dir>/status.json    {"done": {task id: true|false}, "updated": ...}: send as the page's gantt/status document

A task's tick comes from the TODO.md line that contains its "todo" piece. A piece that matches no line, or more than
one, stops the build: the Gantt must never quietly disagree with the TODO list. Python standard library only.
"""
from __future__ import annotations

import datetime as dt
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHECK = re.compile(r"^\s*- \[([ xX])\] (.*)$")


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__.strip().splitlines()[2].strip(), file=sys.stderr)
        return 2
    out = Path(sys.argv[1])
    plan = json.loads((ROOT / "docs/schedule.json").read_text())
    lines = (ROOT / "TODO.md").read_text().splitlines()
    todo = [(m.group(1) != " ", line) for line in lines if (m := CHECK.match(line))]

    done, problems = {}, []
    for stage in plan["stages"]:
        for task in stage["tasks"]:
            piece = task.get("todo")
            if not piece:
                done[task["id"]] = False
                continue
            hits = [d for d, line in todo if piece in line]
            if len(hits) != 1:
                problems.append(f'{task["id"]}: "{piece}" matches {len(hits)} TODO lines')
                continue
            done[task["id"]] = hits[0]
    if problems:
        print("gantt.py: the schedule and TODO.md disagree:\n  " + "\n  ".join(problems), file=sys.stderr)
        return 1

    template = (ROOT / "docs/gantt/gantt.html").read_text()
    data = {k: v for k, v in plan.items() if not k.startswith("_")}
    page = template.replace("/*SCHEDULE*/null", json.dumps(data, ensure_ascii=False))
    if page == template:
        print("gantt.py: the page has no /*SCHEDULE*/null slot", file=sys.stderr)
        return 1
    out.mkdir(parents=True, exist_ok=True)
    (out / "gantt.html").write_text(page)
    status = {"done": done, "updated": dt.datetime.now().astimezone().isoformat(timespec="minutes"), "source": "TODO.md"}
    (out / "status.json").write_text(json.dumps(status, indent=1))
    n = sum(len(s["tasks"]) for s in plan["stages"])
    print(f"gantt.py: {n} tasks, {sum(done.values())} done → {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
