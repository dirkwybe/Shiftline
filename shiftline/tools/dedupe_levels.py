#!/usr/bin/env python
"""
Dedupe Shiftline levels by symmetry and regenerate replacements.

Usage:
  python tools/dedupe_levels.py
"""
from __future__ import annotations

import json
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

import rebuild_levels_no_bouncers as gen


ROOT = Path(__file__).resolve().parents[1]
LEVELS_DIR = ROOT / "levels"

RNG_SEED = 240125
MAX_ATTEMPTS = 1500


@dataclass
class LevelEntry:
    path: Path
    walls: Set[Tuple[int, int]]
    holes: Dict[Tuple[int, int], int]
    blocks: Dict[Tuple[int, int], int]
    label: str


def canonical_signature(
    walls: Set[Tuple[int, int]],
    holes: Dict[Tuple[int, int], int],
    blocks: Dict[Tuple[int, int], int],
) -> str:
    signatures: List[str] = []
    for variant in range(8):
        twalls = tuple(sorted(gen.transform_pos(p, variant) for p in walls))
        tholes = tuple(sorted((gen.transform_pos(p, variant), c) for p, c in holes.items()))
        tblocks = tuple(sorted((gen.transform_pos(p, variant), c) for p, c in blocks.items()))
        signatures.append(f"W{twalls}|H{tholes}|B{tblocks}")
    return min(signatures)


def canonical_signature_level(level: gen.Level) -> str:
    return canonical_signature(level.walls, level.holes, level.blocks)


def load_levels() -> List[LevelEntry]:
    entries: List[LevelEntry] = []
    for path in sorted(LEVELS_DIR.glob("level_*.json")):
        with path.open("r", encoding="utf-8") as f:
            data = json.load(f)
        walls = {tuple(w) for w in data.get("walls", [])}
        holes = {tuple(h["pos"]): int(h["color"]) for h in data.get("holes", [])}
        blocks = {tuple(b["pos"]): int(b["color"]) for b in data.get("blocks", [])}
        label = gen.normalize_label(str(data.get("difficulty_label", "hard"))) or "hard"
        entries.append(LevelEntry(path=path, walls=walls, holes=holes, blocks=blocks, label=label))
    return entries


def _assign_line_pairs(
    line_positions: List[int],
    hole_positions: List[int],
    colors: List[int],
    direction_positive: bool,
) -> Tuple[Dict[int, int], Dict[int, int]]:
    blocks_sorted = sorted(line_positions)
    if direction_positive:
        blocks_sorted = list(reversed(blocks_sorted))
        holes_sorted = sorted(hole_positions, reverse=True)
    else:
        holes_sorted = sorted(hole_positions)
    blocks_out: Dict[int, int] = {}
    holes_out: Dict[int, int] = {}
    for idx, color in enumerate(colors):
        blocks_out[blocks_sorted[idx]] = color
        holes_out[holes_sorted[idx]] = color
    return blocks_out, holes_out


def generate_easy_multi_block(rng: random.Random, blocks_count: int = 2) -> Optional[gen.Level]:
    if blocks_count < 2:
        return None
    for _ in range(60):
        orient_row = rng.choice([True, False])
        direction_positive = rng.choice([True, False])
        if orient_row:
            y = rng.randrange(gen.HEIGHT)
            if direction_positive:
                hole_positions = [gen.WIDTH - 1 - i for i in range(blocks_count)]
                candidates = list(range(0, gen.WIDTH - blocks_count))
            else:
                hole_positions = [i for i in range(blocks_count)]
                candidates = list(range(blocks_count, gen.WIDTH))
            if len(candidates) < blocks_count:
                continue
            rng.shuffle(candidates)
            block_positions = candidates[:blocks_count]
            colors = list(range(blocks_count))
            rng.shuffle(colors)
            blocks_line, holes_line = _assign_line_pairs(
                block_positions,
                hole_positions,
                colors,
                direction_positive,
            )
            blocks = {(x, y): color for x, color in blocks_line.items()}
            holes = {(x, y): color for x, color in holes_line.items()}
        else:
            x = rng.randrange(gen.WIDTH)
            if direction_positive:
                hole_positions = [gen.HEIGHT - 1 - i for i in range(blocks_count)]
                candidates = list(range(0, gen.HEIGHT - blocks_count))
            else:
                hole_positions = [i for i in range(blocks_count)]
                candidates = list(range(blocks_count, gen.HEIGHT))
            if len(candidates) < blocks_count:
                continue
            rng.shuffle(candidates)
            block_positions = candidates[:blocks_count]
            colors = list(range(blocks_count))
            rng.shuffle(colors)
            blocks_line, holes_line = _assign_line_pairs(
                block_positions,
                hole_positions,
                colors,
                direction_positive,
            )
            blocks = {(x, y): color for y, color in blocks_line.items()}
            holes = {(x, y): color for y, color in holes_line.items()}

        level = gen.analyze_level(blocks, holes, set())
        if level is None or level.label != "easy":
            continue
        return level
    return None


def _mutate_with_walls(entry: LevelEntry, rng: random.Random, extra_walls: int) -> Optional[gen.Level]:
    if extra_walls <= 0:
        return None
    all_positions = [(x, y) for y in range(gen.HEIGHT) for x in range(gen.WIDTH)]
    for _ in range(80):
        walls = set(entry.walls)
        empties = [pos for pos in all_positions if pos not in walls and pos not in entry.blocks and pos not in entry.holes]
        if len(empties) < extra_walls:
            return None
        rng.shuffle(empties)
        for idx in range(extra_walls):
            walls.add(empties[idx])
        level = gen.analyze_level(dict(entry.blocks), dict(entry.holes), walls)
        if level is None or level.label != entry.label:
            continue
        return level
    return None


def _generate_spicy_candidate(rng: random.Random, target_label: str) -> Optional[gen.Level]:
    if target_label not in ("challenging", "hard"):
        return None
    blocks_count = rng.randint(2, 4)
    if target_label == "challenging":
        walls_count = rng.randint(2, 6)
        scramble_len = rng.randint(3, 6)
    else:
        walls_count = rng.randint(3, 8)
        scramble_len = rng.randint(5, 9)

    walls = set(gen.random_positions(rng, walls_count, set()))
    holes = gen.build_holes(rng, blocks_count, walls, target_label)
    if holes is None:
        return None

    blocks = dict(holes)
    grid = gen.grid_from_blocks(blocks)
    for _ in range(scramble_len):
        moved = False
        for _try in range(8):
            is_row = rng.choice([True, False])
            index = rng.randrange(gen.HEIGHT if is_row else gen.WIDTH)
            direction = rng.choice([-1, 1])
            grid_next, moved = gen.slide_grid(grid, walls, {}, is_row, index, direction)
            if moved:
                grid = grid_next
                break
        if not moved:
            break

    blocks = gen.blocks_from_grid(grid)
    if any(holes.get(pos) == color for pos, color in blocks.items()):
        return None
    return gen.analyze_level(blocks, holes, walls)


def generate_unique_level(
    target_label: str,
    rng: random.Random,
    seen: Set[str],
    seed_entry: Optional[LevelEntry] = None,
) -> gen.Level:
    for attempt in range(MAX_ATTEMPTS):
        level: Optional[gen.Level] = None
        if seed_entry is not None and target_label in ("challenging", "hard"):
            extra_walls = 1 if target_label == "challenging" else 2
            level = _mutate_with_walls(seed_entry, rng, extra_walls)
        if target_label == "easy":
            if rng.random() < 0.65:
                level = generate_easy_multi_block(rng, blocks_count=2)
            if level is None:
                level = gen.generate_candidate(rng, target_label)
        elif target_label in ("challenging", "hard"):
            roll = rng.random()
            if roll < 0.3:
                blocks_count = rng.randint(2, 3 if target_label == "challenging" else 4)
                level = gen.generate_corridor_candidate(rng, target_label, blocks_count)
            elif roll < 0.8:
                level = _generate_spicy_candidate(rng, target_label)
            if level is None:
                level = gen.generate_candidate(rng, target_label)
        else:
            level = gen.generate_candidate(rng, target_label)

        if level is None or level.label != target_label:
            continue
        signature = canonical_signature_level(level)
        if signature in seen:
            continue
        seen.add(signature)
        return level
    raise RuntimeError(f"Failed to generate unique {target_label} level after {MAX_ATTEMPTS} attempts.")


def main() -> None:
    rng = random.Random(RNG_SEED)
    entries = load_levels()
    if not entries:
        raise RuntimeError("No levels found.")

    seen: Set[str] = set()
    duplicates: List[LevelEntry] = []
    for entry in entries:
        signature = canonical_signature(entry.walls, entry.holes, entry.blocks)
        if signature in seen:
            duplicates.append(entry)
            continue
        seen.add(signature)

    if not duplicates:
        print("No symmetry duplicates found.")
        return

    replaced = 0
    for entry in duplicates:
        replacement = generate_unique_level(entry.label, rng, seen, seed_entry=entry)
        with entry.path.open("w", encoding="utf-8") as f:
            json.dump(replacement.to_json(), f, indent=2)
        replaced += 1

    print(f"Replaced {replaced} duplicate levels by symmetry.")


if __name__ == "__main__":
    main()
