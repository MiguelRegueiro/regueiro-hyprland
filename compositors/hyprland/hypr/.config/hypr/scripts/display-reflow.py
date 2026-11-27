#!/usr/bin/env python3
"""Keep touching monitor edges touching after one monitor changes size."""

import json
import sys
from collections import deque


def reflow(monitors, changed, width, height):
    rects = {}
    for monitor in monitors:
        if monitor.get("disabled") or monitor.get("mirrorOf", "none") != "none":
            continue
        scale = float(monitor.get("scale", 1))
        if scale <= 0:
            scale = 1
        swaps_axes = int(monitor.get("transform", 0)) % 2 == 1
        raw_width = monitor["height"] if swaps_axes else monitor["width"]
        raw_height = monitor["width"] if swaps_axes else monitor["height"]
        rects[monitor["name"]] = {
            "x": float(monitor["x"]),
            "y": float(monitor["y"]),
            "w": float(raw_width) / scale,
            "h": float(raw_height) / scale,
        }
    if changed not in rects:
        raise ValueError("Display is not active")
    if len(rects) == 1:
        return {changed: "0x0"}

    sizes = {name: (r["w"], r["h"]) for name, r in rects.items()}
    sizes[changed] = (width, height)

    # Prefer keeping every unaffected output stationary. This is especially
    # important for a laptop panel beside a primary monitor: rotating the
    # laptop should move only that panel to keep their edges connected.
    original = rects[changed]
    anchored_candidates = []
    for name, neighbor in rects.items():
        if name == changed:
            continue
        horizontal_overlap = min(original["x"] + original["w"], neighbor["x"] + neighbor["w"]) - max(original["x"], neighbor["x"])
        vertical_overlap = min(original["y"] + original["h"], neighbor["y"] + neighbor["h"]) - max(original["y"], neighbor["y"])
        candidates = []
        if abs(original["x"] + original["w"] - neighbor["x"]) <= 2 and vertical_overlap > 1:
            candidates.append((neighbor["x"] - width, neighbor["y"] + original["y"] - neighbor["y"]))
        if abs(neighbor["x"] + neighbor["w"] - original["x"]) <= 2 and vertical_overlap > 1:
            candidates.append((neighbor["x"] + neighbor["w"], neighbor["y"] + original["y"] - neighbor["y"]))
        if abs(original["y"] + original["h"] - neighbor["y"]) <= 2 and horizontal_overlap > 1:
            candidates.append((neighbor["x"] + original["x"] - neighbor["x"], neighbor["y"] - height))
        if abs(neighbor["y"] + neighbor["h"] - original["y"]) <= 2 and horizontal_overlap > 1:
            candidates.append((neighbor["x"] + original["x"] - neighbor["x"], neighbor["y"] + neighbor["h"]))

        for x, y in candidates:
            if x < 0 or y < 0:
                continue
            trial = {monitor: (rect["x"], rect["y"]) for monitor, rect in rects.items()}
            trial[changed] = (x, y)
            if is_valid_layout(trial, sizes):
                distance = (x - original["x"]) ** 2 + (y - original["y"]) ** 2
                anchored_candidates.append((distance, x, y))

    if anchored_candidates:
        _, x, y = min(anchored_candidates)
        return {changed: f"{round(x)}x{round(y)}"}

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


def is_valid_layout(positions, sizes):
    names = list(positions)
    for index, name in enumerate(names):
        x, y = positions[name]
        w, h = sizes[name]
        for other in names[index + 1 :]:
            ox, oy = positions[other]
            ow, oh = sizes[other]
            if min(x + w, ox + ow) - max(x, ox) > 1 and min(y + h, oy + oh) - max(y, oy) > 1:
                return False

    seen = {names[0]}
    queue = deque(seen)
    while queue:
        name = queue.popleft()
        x, y = positions[name]
        w, h = sizes[name]
        for other in names:
            if other in seen:
                continue
            ox, oy = positions[other]
            ow, oh = sizes[other]
            horizontal = (abs(x + w - ox) <= 1 or abs(ox + ow - x) <= 1) and y < oy + oh - 1 and oy < y + h - 1
            vertical = (abs(y + h - oy) <= 1 or abs(oy + oh - y) <= 1) and x < ox + ow - 1 and ox < x + w - 1
            if horizontal or vertical:
                seen.add(other)
                queue.append(other)
    return len(seen) == len(names)


if __name__ == "__main__":
    request = json.load(sys.stdin)
    try:
        print(json.dumps(reflow(request["monitors"], request["changed"], request["width"], request["height"])))
    except (KeyError, TypeError, ValueError, ZeroDivisionError) as error:
        print(f"Cannot adjust display layout: {error}", file=sys.stderr)
        sys.exit(2)
