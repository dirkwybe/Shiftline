#!/usr/bin/env python
"""
Build assets/music/music_list.json from files in assets/music.
"""
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MUSIC_DIR = ROOT / "assets" / "music"
OUT_PATH = MUSIC_DIR / "music_list.json"


def main() -> None:
    MUSIC_DIR.mkdir(parents=True, exist_ok=True)
    items = []
    for path in sorted(MUSIC_DIR.iterdir()):
        if path.is_file() and path.suffix.lower() in {".mp3", ".ogg", ".wav"}:
            items.append(path.name)
    with OUT_PATH.open("w", encoding="utf-8") as f:
        json.dump(items, f, indent=2)
    print(f"Wrote {OUT_PATH} ({len(items)} tracks).")


if __name__ == "__main__":
    main()
