#!/usr/bin/env python3
"""Keep touching monitor edges touching after one monitor changes size."""

import json
import sys
from collections import deque


def reflow(monitors, changed, width, height):
    rects = {
        m["name"]: {
            "x": float(m["x"]),
            "y": float(m["y"]),
            "w": float(m["width"]) / float(m["scale"]),
            "h": float(m["height"]) / float(m["scale"]),
        }
        for m in monitors
        if not m.get("disabled") and m.get("mirrorOf", "none") == "none"
    }
    if changed not in rects:
        raise ValueError("Display is not active")
    if len(rects) == 1:
        return {changed: "0x0"}

    sizes = {name: (r["w"], r["h"]) for name, r in rects.items()}
    sizes[changed] = (width, height)
    positions = {changed: (rects[changed]["x"], rects[changed]["y"])}
    queue = deque([changed])
    while queue:
        source = queue.popleft()
        a = rects[source]
        ax, ay = positions[source]
        for name, b in rects.items():
            if name in positions:
                continue
            horizontal_overlap = min(a["x"] + a["w"], b["x"] + b["w"]) - max(a["x"], b["x"])
            vertical_overlap = min(a["y"] + a["h"], b["y"] + b["h"]) - max(a["y"], b["y"])
            if abs(a["x"] + a["w"] - b["x"]) <= 2 and vertical_overlap > 1:
                pos = (ax + sizes[source][0], ay + b["y"] - a["y"])
            elif abs(b["x"] + b["w"] - a["x"]) <= 2 and vertical_overlap > 1:
                pos = (ax - sizes[name][0], ay + b["y"] - a["y"])
            elif abs(a["y"] + a["h"] - b["y"]) <= 2 and horizontal_overlap > 1:
                pos = (ax + b["x"] - a["x"], ay + sizes[source][1])
            elif abs(b["y"] + b["h"] - a["y"]) <= 2 and horizontal_overlap > 1:
                pos = (ax + b["x"] - a["x"], ay - sizes[name][1])
            else:
                continue
            positions[name] = pos
            queue.append(name)

    if len(positions) != len(rects):
        raise ValueError("Displays must touch before changing their geometry")
    for name, (x, y) in positions.items():
        w, h = sizes[name]
        for other, (ox, oy) in positions.items():
            if name >= other:
                continue
            ow, oh = sizes[other]
            if min(x + w, ox + ow) - max(x, ox) > 1 and min(y + h, oy + oh) - max(y, oy) > 1:
                raise ValueError("The new display size would overlap another display")

    min_x = min(x for x, _ in positions.values())
    min_y = min(y for _, y in positions.values())
    return {name: f"{round(x - min_x)}x{round(y - min_y)}" for name, (x, y) in positions.items()}


if __name__ == "__main__":
    request = json.load(sys.stdin)
    try:
        print(json.dumps(reflow(request["monitors"], request["changed"], request["width"], request["height"])))
    except (KeyError, TypeError, ValueError, ZeroDivisionError) as error:
        print(f"Cannot adjust display layout: {error}", file=sys.stderr)
        sys.exit(2)
