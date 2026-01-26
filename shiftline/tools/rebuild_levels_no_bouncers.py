#!/usr/bin/env python
"""
Rebuild Shiftline levels without bouncers, using difficulty rubric and stage rules.

Usage:
  python tools/rebuild_levels_no_bouncers.py
"""
from __future__ import annotations

import json
import random
from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Set, Tuple


ROOT = Path(__file__).resolve().parents[1]
LEVELS_DIR = ROOT / "levels"

WIDTH = 8
HEIGHT = 8
PALETTE = ["#3C78DC", "#E65050", "#50BE78", "#E6C846"]
RNG_SEED = 240125
STAGE_COUNT = 10
LEVELS_PER_STAGE = 20
FAST_EXPAND = True

MAX_STATES = 15000

DIFFICULTY_VALUES = {
    "easy": 1,
    "fun": 2,
    "challenging": 3,
    "hard": 4,
}


def normalize_label(label: str) -> str:
    label = (label or "").strip().lower()
    if label == "very easy":
        return "easy"
    if label == "very hard":
        return "hard"
    return label


@dataclass(frozen=True)
class Level:
    walls: Set[Tuple[int, int]]
    holes: Dict[Tuple[int, int], int]
    blocks: Dict[Tuple[int, int], int]
    par_moves: int
    par_per_block: float
    label: str
    ordering: str
    multi_swipe: bool

    def to_json(self) -> dict:
        return {
            "width": WIDTH,
            "height": HEIGHT,
            "palette": PALETTE,
            "walls": [[x, y] for (x, y) in sorted(self.walls)],
            "blocks": [{"pos": [x, y], "color": c} for (x, y), c in sorted(self.blocks.items())],
            "holes": [{"pos": [x, y], "color": c} for (x, y), c in sorted(self.holes.items())],
            "bouncers": [],
            "difficulty": DIFFICULTY_VALUES[self.label],
            "difficulty_label": self.label,
        }


def in_bounds(x: int, y: int) -> bool:
    return 0 <= x < WIDTH and 0 <= y < HEIGHT


def grid_key(grid: Tuple[int, ...]) -> str:
    return ",".join(str(v) for v in grid)


def grid_from_blocks(blocks: Dict[Tuple[int, int], int]) -> Tuple[int, ...]:
    grid = [-1] * (WIDTH * HEIGHT)
    for (x, y), color in blocks.items():
        grid[y * WIDTH + x] = color
    return tuple(grid)


def locked_from_grid(grid: Tuple[int, ...], holes: Dict[Tuple[int, int], int]) -> Set[Tuple[int, int]]:
    locked = set()
    for (x, y), color in holes.items():
        if grid[y * WIDTH + x] == color:
            locked.add((x, y))
    return locked


def slide_grid(
    grid: Tuple[int, ...],
    walls: Set[Tuple[int, int]],
    holes: Dict[Tuple[int, int], int],
    is_row: bool,
    index: int,
    direction: int,
) -> Tuple[Tuple[int, ...], bool]:
    grid_list = list(grid)
    locked = locked_from_grid(grid, holes)
    moved = False

    if is_row:
        if index < 0 or index >= HEIGHT:
            return grid, False
        occupied = set(walls) | locked | {(x, index) for x in range(WIDTH) if grid_list[index * WIDTH + x] != -1}
        xs = range(WIDTH - 1, -1, -1) if direction > 0 else range(WIDTH)
        for x in xs:
            pos = (x, index)
            color = grid_list[index * WIDTH + x]
            if color == -1 or pos in locked:
                continue
            occupied.discard(pos)
            nx, ny = x, index
            while True:
                tx = nx + direction
                if not in_bounds(tx, ny) or (tx, ny) in occupied:
                    break
                nx = tx
            if (nx, ny) != pos:
                grid_list[index * WIDTH + x] = -1
                grid_list[ny * WIDTH + nx] = color
                moved = True
            occupied.add((nx, ny))
            if (nx, ny) in holes and holes[(nx, ny)] == color and (nx, ny) not in locked:
                locked.add((nx, ny))
                moved = True
    else:
        if index < 0 or index >= WIDTH:
            return grid, False
        occupied = set(walls) | locked | {(index, y) for y in range(HEIGHT) if grid_list[y * WIDTH + index] != -1}
        ys = range(HEIGHT - 1, -1, -1) if direction > 0 else range(HEIGHT)
        for y in ys:
            pos = (index, y)
            color = grid_list[y * WIDTH + index]
            if color == -1 or pos in locked:
                continue
            occupied.discard(pos)
            nx, ny = index, y
            while True:
                ty = ny + direction
                if not in_bounds(nx, ty) or (nx, ty) in occupied:
                    break
                ny = ty
            if (nx, ny) != pos:
                grid_list[y * WIDTH + index] = -1
                grid_list[ny * WIDTH + nx] = color
                moved = True
            occupied.add((nx, ny))
            if (nx, ny) in holes and holes[(nx, ny)] == color and (nx, ny) not in locked:
                locked.add((nx, ny))
                moved = True
    return tuple(grid_list), moved


def analyze_level(
    blocks: Dict[Tuple[int, int], int],
    holes: Dict[Tuple[int, int], int],
    walls: Set[Tuple[int, int]],
) -> Optional[Level]:
    start = grid_from_blocks(blocks)
    queue = deque([start])
    visited = {grid_key(start)}
    parent: Dict[str, Tuple[str, Tuple[bool, int, int]]] = {}
    grids: Dict[str, Tuple[int, ...]] = {grid_key(start): start}

    solution_key: Optional[str] = None

    while queue:
        grid = queue.popleft()
        key = grid_key(grid)
        if all(pos in locked_from_grid(grid, holes) for pos in holes.keys()):
            solution_key = key
            break
        for is_row in (True, False):
            limit = HEIGHT if is_row else WIDTH
            for index in range(limit):
                for direction in (-1, 1):
                    nxt, moved = slide_grid(grid, walls, holes, is_row, index, direction)
                    if not moved:
                        continue
                    nxt_key = grid_key(nxt)
                    if nxt_key in visited:
                        continue
                    visited.add(nxt_key)
                    if len(visited) >= MAX_STATES:
                        return None
                    parent[nxt_key] = (key, (is_row, index, direction))
                    grids[nxt_key] = nxt
                    queue.append(nxt)

    if solution_key is None:
        return None

    # Reconstruct solution path (list of moves)
    path: List[Tuple[bool, int, int]] = []
    cur = solution_key
    while cur in parent:
        prev_key, move = parent[cur]
        path.append(move)
        cur = prev_key
    path.reverse()
    par_moves = len(path)
    if par_moves <= 0:
        return None

    blocks_count = len(blocks)
    par_per_block = par_moves / float(blocks_count)

    # Track moves per block color until locked
    colors = list(set(blocks.values()))
    move_counts = {c: 0 for c in colors}
    lock_steps: Dict[int, int] = {}

    grid = start
    for step, move in enumerate(path, start=1):
        before_positions = positions_by_color(grid)
        grid, _ = slide_grid(grid, walls, holes, move[0], move[1], move[2])
        after_positions = positions_by_color(grid)
        locked = locked_from_grid(grid, holes)
        for color in colors:
            if color in lock_steps:
                continue
            if before_positions.get(color) != after_positions.get(color):
                move_counts[color] += 1
            pos = after_positions.get(color)
            if pos in locked and holes.get(pos) == color:
                lock_steps[color] = step

    if len(lock_steps) != len(colors):
        return None

    multi_swipe = any(count > 1 for count in move_counts.values())
    ordering = ordering_from_lock_steps(lock_steps)

    label = classify(blocks_count, par_per_block, ordering, multi_swipe)
    if label is None:
        return None

    return Level(
        walls=walls,
        holes=holes,
        blocks=blocks,
        par_moves=par_moves,
        par_per_block=par_per_block,
        label=label,
        ordering=ordering,
        multi_swipe=multi_swipe,
    )


def level_signature(level: Level) -> str:
    walls = tuple(sorted(level.walls))
    holes = tuple(sorted(level.holes.items()))
    blocks = tuple(sorted(level.blocks.items()))
    return f"W{walls}|H{holes}|B{blocks}"


def transform_pos(pos: Tuple[int, int], variant: int) -> Tuple[int, int]:
    x, y = pos
    if variant == 0:  # identity
        return x, y
    if variant == 1:  # rot90
        return y, WIDTH - 1 - x
    if variant == 2:  # rot180
        return WIDTH - 1 - x, HEIGHT - 1 - y
    if variant == 3:  # rot270
        return HEIGHT - 1 - y, x
    if variant == 4:  # flip horizontal
        return WIDTH - 1 - x, y
    if variant == 5:  # flip vertical
        return x, HEIGHT - 1 - y
    if variant == 6:  # main diagonal
        return y, x
    # anti-diagonal
    return WIDTH - 1 - y, HEIGHT - 1 - x


def transform_level(level: Level, variant: int) -> Optional[Level]:
    walls = {transform_pos(p, variant) for p in level.walls}
    holes = {transform_pos(p, variant): c for p, c in level.holes.items()}
    blocks = {transform_pos(p, variant): c for p, c in level.blocks.items()}
    if any(holes.get(pos) == color for pos, color in blocks.items()):
        return None
    return Level(
        walls=walls,
        holes=holes,
        blocks=blocks,
        par_moves=level.par_moves,
        par_per_block=level.par_per_block,
        label=level.label,
        ordering=level.ordering,
        multi_swipe=level.multi_swipe,
    )


def expand_with_transforms(
    levels: List[Level],
    target_count: int,
    seen: Set[str],
    rng: random.Random,
) -> List[Level]:
    if len(levels) >= target_count:
        return levels
    variants = list(range(1, 8))
    rng.shuffle(variants)
    idx = 0
    while len(levels) < target_count and idx < len(levels):
        base = levels[idx]
        for variant in variants:
            transformed = transform_level(base, variant)
            if transformed is None:
                continue
            signature = level_signature(transformed)
            if signature in seen:
                continue
            seen.add(signature)
            levels.append(transformed)
            if len(levels) >= target_count:
                break
        idx += 1
    return levels


def positions_by_color(grid: Tuple[int, ...]) -> Dict[int, Tuple[int, int]]:
    out: Dict[int, Tuple[int, int]] = {}
    for y in range(HEIGHT):
        for x in range(WIDTH):
            color = grid[y * WIDTH + x]
            if color != -1:
                out[color] = (x, y)
    return out


def ordering_from_lock_steps(lock_steps: Dict[int, int]) -> str:
    steps = list(lock_steps.values())
    if len(set(steps)) == 1:
        return "none"
    if len(set(steps)) == len(steps):
        return "strict"
    return "specific"


def classify(
    blocks_count: int,
    par_per_block: float,
    ordering: str,
    multi_swipe: bool,
) -> Optional[str]:
    if blocks_count < 1:
        return None
    if blocks_count <= 4 and not multi_swipe and par_per_block <= 2.0:
        return "easy"
    if blocks_count <= 3 and multi_swipe and ordering == "none" and par_per_block <= 2.5:
        return "fun"
    if blocks_count <= 4 and multi_swipe and ordering in ("specific", "strict") and par_per_block <= 2.5:
        return "challenging"
    if blocks_count <= 4 and multi_swipe and ordering == "strict" and par_per_block > 2.5:
        return "hard"
    return None


def random_positions(rng: random.Random, count: int, forbidden: Set[Tuple[int, int]]) -> List[Tuple[int, int]]:
    positions = [(x, y) for y in range(HEIGHT) for x in range(WIDTH) if (x, y) not in forbidden]
    rng.shuffle(positions)
    return positions[:count]


def build_holes(
    rng: random.Random,
    blocks_count: int,
    walls: Set[Tuple[int, int]],
    target: str,
) -> Optional[Dict[Tuple[int, int], int]]:
    if target == "easy":
        edge_positions = [
            (x, y)
            for y in range(HEIGHT)
            for x in range(WIDTH)
            if (x in (0, WIDTH - 1) or y in (0, HEIGHT - 1)) and (x, y) not in walls
        ]
        if not edge_positions:
            return None
        hole_positions = [rng.choice(edge_positions)]
    else:
        hole_positions = random_positions(rng, blocks_count, walls)
        if len(hole_positions) < blocks_count:
            return None
    colors = list(range(blocks_count))
    rng.shuffle(colors)
    return {pos: colors[i] for i, pos in enumerate(hole_positions)}


def blocks_from_grid(grid: Tuple[int, ...]) -> Dict[Tuple[int, int], int]:
    out: Dict[Tuple[int, int], int] = {}
    for y in range(HEIGHT):
        for x in range(WIDTH):
            color = grid[y * WIDTH + x]
            if color != -1:
                out[(x, y)] = color
    return out


def scramble_length_for(target: str) -> int:
    if target == "easy":
        return 1
    if target == "fun":
        return 3
    if target == "challenging":
        return 3
    return 6


def generate_candidate(rng: random.Random, target: str) -> Optional[Level]:
    if target == "easy":
        blocks_count = 1
        walls_count = 0
    elif target == "fun":
        blocks_count = 1
        walls_count = 0
    elif target == "challenging":
        blocks_count = rng.randint(2, 3)
        walls_count = rng.randint(1, 3)
    else:
        blocks_count = rng.randint(2, 4)
        walls_count = rng.randint(2, 5)

    walls = set(random_positions(rng, walls_count, set()))
    holes = build_holes(rng, blocks_count, walls, target)
    if holes is None:
        return None

    if target == "easy":
        hole = next(iter(holes.keys()))
        same_row = rng.choice([True, False])
        if same_row:
            bx = rng.choice([x for x in range(WIDTH) if x != hole[0]])
            blocks = {(bx, hole[1]): 0}
        else:
            by = rng.choice([y for y in range(HEIGHT) if y != hole[1]])
            blocks = {(hole[0], by): 0}
        return analyze_level(blocks, holes, walls)

    if target == "fun":
        hole = next(iter(holes.keys()))
        candidates = [
            (x, y)
            for y in range(HEIGHT)
            for x in range(WIDTH)
            if (x, y) not in walls and (x, y) != hole and x != hole[0] and y != hole[1]
        ]
        if not candidates:
            return None
        blocks = {rng.choice(candidates): 0}
        return analyze_level(blocks, holes, walls)

    blocks = dict(holes)
    scramble_len = scramble_length_for(target)
    grid = grid_from_blocks(blocks)
    for _ in range(scramble_len):
        moved = False
        for _try in range(6):
            is_row = rng.choice([True, False])
            index = rng.randrange(HEIGHT if is_row else WIDTH)
            direction = rng.choice([-1, 1])
            grid_next, moved = slide_grid(grid, walls, {}, is_row, index, direction)
            if moved:
                grid = grid_next
                break
        if not moved:
            break

    blocks = blocks_from_grid(grid)
    if any(holes.get(pos) == color for pos, color in blocks.items()):
        return None
    return analyze_level(blocks, holes, walls)


def generate_corridor_candidate(rng: random.Random, target: str, blocks_count: int) -> Optional[Level]:
    orient_row = rng.choice([True, False])
    if orient_row:
        line = rng.randint(1, HEIGHT - 2)
        walls = {(x, y) for y in range(HEIGHT) for x in range(WIDTH) if y != line}
        line_positions = [(x, line) for x in range(WIDTH)]
    else:
        line = rng.randint(1, WIDTH - 2)
        walls = {(x, y) for y in range(HEIGHT) for x in range(WIDTH) if x != line}
        line_positions = [(line, y) for y in range(HEIGHT)]

    rng.shuffle(line_positions)
    holes_positions = line_positions[:blocks_count]
    block_positions = [p for p in line_positions[blocks_count:] if p not in holes_positions]
    if len(block_positions) < blocks_count:
        return None
    block_positions = block_positions[:blocks_count]

    colors = list(range(blocks_count))
    rng.shuffle(colors)
    holes = {pos: colors[i] for i, pos in enumerate(holes_positions)}
    blocks = {pos: colors[i] for i, pos in enumerate(block_positions)}

    if any(holes.get(pos) == color for pos, color in blocks.items()):
        return None

    lvl = analyze_level(blocks, holes, walls)
    if lvl is None:
        return None
    if lvl.label != target:
        return None
    return lvl


def collect_levels(
    target_label: str,
    count: int,
    rng: random.Random,
    seen: Set[str],
    attempts_multiplier: int = 300,
) -> List[Level]:
    levels: List[Level] = []
    attempts = 0
    while len(levels) < count and attempts < count * attempts_multiplier:
        attempts += 1
        level = generate_candidate(rng, target_label)
        if level is None:
            continue
        if level.label != target_label:
            continue
        signature = level_signature(level)
        if signature in seen:
            continue
        seen.add(signature)
        levels.append(level)
    if len(levels) < count:
        raise RuntimeError(f"Failed to generate {count} {target_label} levels after {attempts} attempts.")
    return levels


def load_existing_levels() -> Tuple[List[Level], Set[str]]:
    levels: List[Level] = []
    signatures: Set[str] = set()
    for path in sorted(LEVELS_DIR.glob("level_*.json")):
        with path.open("r", encoding="utf-8") as f:
            data = json.load(f)
        walls = {tuple(w) for w in data.get("walls", [])}
        holes = {tuple(h["pos"]): int(h["color"]) for h in data.get("holes", [])}
        blocks = {tuple(b["pos"]): int(b["color"]) for b in data.get("blocks", [])}
        # Skip if any block starts solved
        if any(holes.get(pos) == color for pos, color in blocks.items()):
            continue
        lvl = analyze_level(blocks, holes, walls)
        if lvl is None:
            continue
        signature = level_signature(lvl)
        if signature in signatures:
            continue
        signatures.add(signature)
        levels.append(lvl)
    return levels, signatures


def load_existing_levels_raw() -> Tuple[List[Level], Set[str]]:
    levels: List[Level] = []
    signatures: Set[str] = set()
    for path in sorted(LEVELS_DIR.glob("level_*.json")):
        with path.open("r", encoding="utf-8") as f:
            data = json.load(f)
        walls = {tuple(w) for w in data.get("walls", [])}
        holes = {tuple(h["pos"]): int(h["color"]) for h in data.get("holes", [])}
        blocks = {tuple(b["pos"]): int(b["color"]) for b in data.get("blocks", [])}
        if any(holes.get(pos) == color for pos, color in blocks.items()):
            continue
        label = normalize_label(str(data.get("difficulty_label", "hard")))
        lvl = Level(
            walls=walls,
            holes=holes,
            blocks=blocks,
            par_moves=0,
            par_per_block=0.0,
            label=label or "hard",
            ordering="none",
            multi_swipe=True,
        )
        signature = level_signature(lvl)
        if signature in signatures:
            continue
        signatures.add(signature)
        levels.append(lvl)
    return levels, signatures


def build_transforms(
    base_levels: List[Level],
    count: int,
    seen: Set[str],
    rng: random.Random,
) -> List[Level]:
    if count <= 0:
        return []
    expanded: List[Level] = []
    variants = list(range(1, 8))
    while len(expanded) < count:
        progress = False
        for base in base_levels:
            rng.shuffle(variants)
            for variant in variants:
                transformed = transform_level(base, variant)
                if transformed is None:
                    continue
                signature = level_signature(transformed)
                if signature in seen:
                    continue
                seen.add(signature)
                expanded.append(transformed)
                progress = True
                if len(expanded) >= count:
                    break
            if len(expanded) >= count:
                break
        if not progress:
            break
    if len(expanded) < count:
        raise RuntimeError(f"Only generated {len(expanded)} of {count} transformed levels.")
    return expanded


def main() -> None:
    rng = random.Random(RNG_SEED)

    if FAST_EXPAND:
        existing, seen = load_existing_levels_raw()
        easy_levels = [lvl for lvl in existing if lvl.label == "easy"]
        fun_levels = [lvl for lvl in existing if lvl.label == "fun"]
        challenging_levels = [lvl for lvl in existing if lvl.label == "challenging"]
        hard_levels = [lvl for lvl in existing if lvl.label == "hard"]

        easy_target = 8
        fun_target = 8
        challenging_target = 94
        hard_target = 90

        easy_levels = expand_with_transforms(easy_levels, easy_target, seen, rng)
        fun_levels = expand_with_transforms(fun_levels, fun_target, seen, rng)
        challenging_levels = expand_with_transforms(challenging_levels, challenging_target, seen, rng)
        hard_levels = expand_with_transforms(hard_levels, hard_target, seen, rng)

        def score(level: Level) -> float:
            return float(len(level.walls) * 2 + len(level.blocks) + len(level.holes))

        easy_levels = sorted(easy_levels, key=score)
        fun_levels = sorted(fun_levels, key=score)
        challenging_levels = sorted(challenging_levels, key=score)
        hard_levels = sorted(hard_levels, key=score)

        stage1 = easy_levels[:8] + fun_levels[:8] + challenging_levels[:4]
        remaining_challenging = challenging_levels[4:]
        remaining_hard = hard_levels

        hard_plus = sorted(remaining_hard, key=score, reverse=True)[:18]
        hard_pool = [lvl for lvl in remaining_hard if lvl not in hard_plus]

        stages: List[List[Level]] = [stage1]
        for stage_idx in range(2, STAGE_COUNT + 1):
            ch = remaining_challenging[:10]
            remaining_challenging = remaining_challenging[10:]
            hd = hard_pool[:8]
            hard_pool = hard_pool[8:]
            hp_start = (stage_idx - 2) * 2
            hp = hard_plus[hp_start : hp_start + 2]
            stage_levels = ch + hd + hp
            if len(stage_levels) != LEVELS_PER_STAGE:
                raise RuntimeError(f"Stage {stage_idx} has {len(stage_levels)} levels.")
            stages.append(stage_levels)

        LEVELS_DIR.mkdir(parents=True, exist_ok=True)
        for path in LEVELS_DIR.glob("level_*.json"):
            path.unlink()
        idx = 1
        for stage_levels in stages:
            for level in stage_levels:
                out_path = LEVELS_DIR / f"level_{idx:03d}.json"
                with out_path.open("w", encoding="utf-8") as f:
                    json.dump(level.to_json(), f, indent=2)
                idx += 1
        print(f"Expanded to {STAGE_COUNT * LEVELS_PER_STAGE} levels with transforms.")
        return

    existing, seen = load_existing_levels()
    easy_levels = [lvl for lvl in existing if lvl.label == "easy"]
    fun_levels = [lvl for lvl in existing if lvl.label == "fun"]
    challenging_levels = [lvl for lvl in existing if lvl.label == "challenging"]
    hard_levels = [lvl for lvl in existing if lvl.label == "hard"]

    easy_target = 8
    fun_target = 8
    challenging_target = 94
    hard_target = 90

    easy_levels += collect_levels("easy", max(0, easy_target - len(easy_levels)), rng, seen)
    fun_levels += collect_levels("fun", max(0, fun_target - len(fun_levels)), rng, seen)

    challenging_base = min(challenging_target, 50)
    hard_base = min(hard_target, 50)
    challenging_levels += collect_levels(
        "challenging",
        max(0, challenging_base - len(challenging_levels)),
        rng,
        seen,
        attempts_multiplier=600,
    )
    hard_levels += collect_levels(
        "hard",
        max(0, hard_base - len(hard_levels)),
        rng,
        seen,
        attempts_multiplier=600,
    )

    easy_levels = expand_with_transforms(easy_levels, easy_target, seen, rng)
    fun_levels = expand_with_transforms(fun_levels, fun_target, seen, rng)
    challenging_levels = expand_with_transforms(challenging_levels, challenging_target, seen, rng)
    hard_levels = expand_with_transforms(hard_levels, hard_target, seen, rng)

    if len(easy_levels) < easy_target:
        raise RuntimeError(f"Only {len(easy_levels)} easy levels available.")
    if len(fun_levels) < fun_target:
        raise RuntimeError(f"Only {len(fun_levels)} fun levels available.")
    if len(challenging_levels) < challenging_target:
        raise RuntimeError(f"Only {len(challenging_levels)} challenging levels available.")
    if len(hard_levels) < hard_target:
        raise RuntimeError(f"Only {len(hard_levels)} hard levels available.")

    # Stage 1
    stage1 = (
        sorted(easy_levels, key=lambda l: l.par_per_block)[:8]
        + sorted(fun_levels, key=lambda l: l.par_per_block)[:8]
        + sorted(challenging_levels, key=lambda l: l.par_per_block)[:4]
    )

    # Stages 2-10
    remaining_challenging = sorted(challenging_levels[4:], key=lambda l: l.par_per_block)
    remaining_hard = sorted(hard_levels, key=lambda l: l.par_per_block)
    hard_plus = sorted(remaining_hard, key=lambda l: l.par_per_block, reverse=True)[:18]
    hard_pool = [lvl for lvl in remaining_hard if lvl not in hard_plus]

    stages: List[List[Level]] = [stage1]
    for stage_idx in range(2, STAGE_COUNT + 1):
        ch = remaining_challenging[:10]
        remaining_challenging = remaining_challenging[10:]
        hd = hard_pool[:8]
        hard_pool = hard_pool[8:]
        hp_start = (stage_idx - 2) * 2
        hp = hard_plus[hp_start : hp_start + 2]
        stage_levels = ch + hd + hp
        stages.append(stage_levels)

    # Write levels
    LEVELS_DIR.mkdir(parents=True, exist_ok=True)
    for path in LEVELS_DIR.glob("level_*.json"):
        path.unlink()
    idx = 1
    for stage_idx, stage_levels in enumerate(stages, start=1):
        if len(stage_levels) != LEVELS_PER_STAGE:
            raise RuntimeError(f"Stage {stage_idx} has {len(stage_levels)} levels.")
        for level in stage_levels:
            out_path = LEVELS_DIR / f"level_{idx:03d}.json"
            with out_path.open("w", encoding="utf-8") as f:
                json.dump(level.to_json(), f, indent=2)
            idx += 1

    print(f"Rebuilt {STAGE_COUNT * LEVELS_PER_STAGE} levels with no bouncers.")


if __name__ == "__main__":
    main()
