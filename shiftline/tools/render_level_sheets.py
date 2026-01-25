#!/usr/bin/env python
"""
Render stage contact sheets from Shiftline level JSON files.

Usage:
  python tools/render_level_sheets.py

Outputs:
  shiftline/level_sheets/stage_01.png ... stage_10.png
"""
from __future__ import annotations

import json
import math
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont  # type: ignore


ROOT = Path(__file__).resolve().parents[1]
LEVELS_DIR = ROOT / "levels"
OUT_DIR = ROOT / "level_sheets"

GRID_W = 8
GRID_H = 8
CELL = 16
PADDING = 6
CARD_W = GRID_W * CELL + PADDING * 2
CARD_H = GRID_H * CELL + PADDING * 2 + 16
SHEET_COLS = 2
SHEET_ROWS = 5
SHEET_PAD = 16
BG = (22, 30, 38)
GRID_LINE = (36, 46, 58)
WALL = (35, 42, 52)
HOLE_RING = (30, 30, 34)


def load_levels() -> list[dict]:
    files = sorted(LEVELS_DIR.glob("level_*.json"))
    levels = []
    for path in files:
        with path.open("r", encoding="utf-8") as f:
            data = json.load(f)
        levels.append((path.name, data))
    return levels


def parse_palette(data: dict) -> list[tuple[int, int, int]]:
    out = []
    for item in data.get("palette", []):
        if isinstance(item, str) and item.startswith("#") and len(item) == 7:
            out.append(tuple(int(item[i : i + 2], 16) for i in (1, 3, 5)))
    if not out:
        out = [(60, 120, 220), (230, 80, 80), (80, 190, 120), (230, 200, 70)]
    return out


def normalize_label(label: str) -> str:
    label = (label or "").strip().lower()
    if label == "very easy":
        return "easy"
    if label == "very hard":
        return "hard"
    return label


def draw_level(card: Image.Image, data: dict, title: str) -> None:
    draw = ImageDraw.Draw(card)
    palette = parse_palette(data)
    label = normalize_label(str(data.get("difficulty_label", "")))
    walls = {tuple(w) for w in data.get("walls", [])}
    blocks = {(b["pos"][0], b["pos"][1]): b["color"] for b in data.get("blocks", [])}
    holes = {(h["pos"][0], h["pos"][1]): h["color"] for h in data.get("holes", [])}

    # background
    draw.rounded_rectangle(
        (0, 0, CARD_W - 1, CARD_H - 1),
        radius=8,
        fill=(26, 34, 44),
        outline=(40, 52, 64),
        width=2,
    )

    # grid cells
    for y in range(GRID_H):
        for x in range(GRID_W):
            x0 = PADDING + x * CELL
            y0 = PADDING + y * CELL
            x1 = x0 + CELL - 1
            y1 = y0 + CELL - 1
            draw.rectangle((x0, y0, x1, y1), outline=GRID_LINE)

            if (x, y) in walls:
                draw.rectangle((x0 + 1, y0 + 1, x1 - 1, y1 - 1), fill=WALL)
                continue

            if (x, y) in holes:
                c = palette[holes[(x, y)] % len(palette)]
                outer = tuple(max(0, int(v * 0.6)) for v in c)
                inner = tuple(min(255, int(v * 0.9)) for v in c)
                draw.rounded_rectangle(
                    (x0 + 2, y0 + 2, x1 - 2, y1 - 2),
                    radius=4,
                    fill=outer,
                )
                draw.rounded_rectangle(
                    (x0 + 4, y0 + 4, x1 - 4, y1 - 4),
                    radius=3,
                    fill=inner,
                    outline=HOLE_RING,
                )

            if (x, y) in blocks:
                c = palette[blocks[(x, y)] % len(palette)]
                draw.rounded_rectangle(
                    (x0 + 3, y0 + 3, x1 - 3, y1 - 3),
                    radius=4,
                    fill=c,
                )

    # title + difficulty
    font = ImageFont.load_default()
    draw.text((PADDING, CARD_H - 14), title, fill=(220, 220, 220), font=font)
    if label:
        draw.text((PADDING, CARD_H - 28), label, fill=(180, 200, 220), font=font)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    levels = load_levels()
    total = len(levels)
    for stage in range(1, 11):
        start = (stage - 1) * 10
        chunk = levels[start : start + 10]
        sheet_w = SHEET_COLS * CARD_W + (SHEET_COLS + 1) * SHEET_PAD
        sheet_h = SHEET_ROWS * CARD_H + (SHEET_ROWS + 1) * SHEET_PAD
        sheet = Image.new("RGB", (sheet_w, sheet_h), BG)
        for idx, (name, data) in enumerate(chunk):
            r = idx // SHEET_COLS
            c = idx % SHEET_COLS
            x = SHEET_PAD + c * (CARD_W + SHEET_PAD)
            y = SHEET_PAD + r * (CARD_H + SHEET_PAD)
            card = Image.new("RGB", (CARD_W, CARD_H), BG)
            title = f"Stage {stage}-{idx + 1}"
            draw_level(card, data, title)
            sheet.paste(card, (x, y))
        out_path = OUT_DIR / f"stage_{stage:02d}.png"
        sheet.save(out_path)
    print(f"Wrote {10} sheets to {OUT_DIR}")


if __name__ == "__main__":
    main()
