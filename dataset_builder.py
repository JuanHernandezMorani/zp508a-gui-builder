"""Dataset builder for Zombie Plague script files.

This module scans the ``input/`` directory looking for ``.sma`` files and
extracts metadata that can be used for machine learning datasets.
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Dict, Iterable, List, Optional

import pandas as pd

ROOT = Path(__file__).resolve().parent
INPUT_DIR = ROOT / "input"

STAT_KEYWORDS = {
    "stat_health": ("health",),
    "stat_speed": ("speed",),
    "stat_gravity": ("gravity",),
    "stat_armor": ("armor",),
    "stat_knockback": ("knockback",),
}

ABILITY_KEYWORDS = [
    "set_user_health",
    "set_user_maxspeed",
    "set_user_gravity",
    "set_user_armor",
    "set_user_noclip",
    "set_user_godmode",
    "set_user_rendering",
    "set_user_origin",
    "set_user_velocity",
    "set_task",
    "give_item",
    "strip_user_weapons",
    "cs_set_user_model",
    "cs_set_user_bpammo",
    "cs_set_user_money",
    "set_pev",
    "engfunc",
    "emit_sound",
    "client_cmd",
    "fm_set_user_speed",
    "fm_set_rendering",
    "entity_set_float",
    "entity_set_int",
    "zp_make_user_zombie",
    "zp_make_user_human",
]

LIST_COLUMNS = [
    "register_calls",
    "items",
    "paths_models",
    "paths_claws",
    "paths_sounds",
    "paths_sprites",
    "abilities",
    "human_pseudo_classes",
]


def normalize_path(raw: str) -> str:
    """Normalize resource paths.

    Lower cases the path, replaces backslashes and condenses duplicate slashes.
    """

    cleaned = raw.replace("\\", "/").strip()
    cleaned = re.sub(r"/+", "/", cleaned)
    return cleaned.lower()


def parse_numeric_value(raw: str) -> Optional[float]:
    """Try to parse a numeric literal from a string."""

    raw = raw.strip().strip("{}")
    match = re.search(r"-?\d+(?:\.\d+)?", raw)
    if not match:
        return None
    value = match.group(0)
    if "." in value:
        return float(value)
    try:
        return float(int(value))
    except ValueError:
        return None


def extract_stats(text: str) -> Dict[str, Optional[float]]:
    """Extract stats like health and speed from the file text."""

    stats: Dict[str, Optional[float]] = {key: None for key in STAT_KEYWORDS}
    pattern = re.compile(
        r"(?i)(?:const|new|static)\s+(?:Float:)?([A-Za-z0-9_]+)\s*=\s*([^;\n]+)"
    )
    for match in pattern.finditer(text):
        variable = match.group(1).lower()
        raw_value = match.group(2)
        number = parse_numeric_value(raw_value)
        if number is None:
            continue
        for column, keywords in STAT_KEYWORDS.items():
            if stats[column] is not None:
                continue
            if any(keyword in variable for keyword in keywords):
                stats[column] = number
                break
    return stats


def extract_strings(text: str) -> Iterable[str]:
    """Yield all string literals found in the text."""

    for match in re.finditer(r'"([^"\n]+)"', text):
        yield match.group(1)


def extract_paths(text: str) -> Dict[str, List[str]]:
    """Gather resource paths grouped by resource type."""

    models: set[str] = set()
    claws: set[str] = set()
    sounds: set[str] = set()
    sprites: set[str] = set()

    for raw in extract_strings(text):
        if "/" not in raw:
            continue
        normalized = normalize_path(raw)
        if normalized.startswith("//"):
            normalized = normalized[1:]
        if normalized.startswith("http://") or normalized.startswith("https://"):
            continue
        if normalized.startswith("models/") or normalized.endswith(".mdl"):
            models.add(normalized)
            if any(keyword in normalized for keyword in ("claw", "knife")):
                claws.add(normalized)
        if normalized.startswith("sound/") or normalized.endswith((".wav", ".mp3")):
            sounds.add(normalized)
        if normalized.startswith("sprites/") or normalized.endswith(".spr"):
            sprites.add(normalized)

    return {
        "paths_models": sorted(models),
        "paths_claws": sorted(claws),
        "paths_sounds": sorted(sounds),
        "paths_sprites": sorted(sprites),
    }


def extract_register_calls(lines: Iterable[str]) -> List[str]:
    register_lines: List[str] = []
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("//") or stripped.startswith("#"):
            continue
        if ("zp_class_" in stripped or "zp_register_" in stripped) and "(" in stripped:
            register_lines.append(stripped)
    return register_lines


def extract_item_calls(lines: Iterable[str]) -> List[str]:
    item_lines: List[str] = []
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("//"):
            continue
        if any(keyword in stripped for keyword in ("zp_register_extra_item", "zp_register_item", "zp_items_register")):
            if "(" in stripped:
                item_lines.append(stripped)
    return item_lines


def extract_items(item_lines: Iterable[str]) -> List[str]:
    names: set[str] = set()
    pattern = re.compile(r'\(\s*"([^"\n]+)"')
    for line in item_lines:
        match = pattern.search(line)
        if match:
            names.add(match.group(1).strip())
    return sorted(names)


def extract_abilities(text: str) -> List[str]:
    text_lower = text.lower()
    abilities = {ability for ability in ABILITY_KEYWORDS if ability in text_lower}
    return sorted(abilities)


def extract_human_classes(text: str) -> List[str]:
    pattern = re.compile(r"human class[^:]*:\s*!g\s*([^!\"]+)", re.IGNORECASE)
    classes = set()
    for match in pattern.finditer(text):
        classes.add(match.group(1).strip())
    return sorted(classes)


def determine_entity_type(path: Path, text_lower: str) -> str:
    filename = path.name.lower()
    if filename == "zp_hclass.sma":
        return "human_class"
    if any(keyword in text_lower for keyword in ("zp_register_extra_item", "zp_register_item", "zp_items_register")):
        return "item"
    if "zp_class_" in text_lower:
        return "class"
    if "zp_register_" in text_lower:
        return "registration"
    return "script"


def extract_entity_name(lines: Iterable[str], text: str, fallback: str) -> str:
    for match in re.finditer(r'register_plugin\s*\(\s*"([^"\n]+)"', text):
        name = match.group(1).strip()
        if name:
            return name
    name_pattern = re.compile(r"new\s+const\s+[A-Za-z0-9_]*name[\w\[\]]*\s*=\s*\{\s*\"([^\"\n]+)\"")
    match = name_pattern.search(text)
    if match:
        candidate = match.group(1).strip()
        if candidate:
            return candidate
    return fallback


def parse_sma_file(path: Path) -> Dict[str, object]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    lines = text.splitlines()
    text_lower = text.lower()

    stats = extract_stats(text)
    paths = extract_paths(text)
    register_lines = extract_register_calls(lines)
    item_lines = extract_item_calls(lines)
    items = extract_items(item_lines)
    abilities = extract_abilities(text)
    human_classes = extract_human_classes(text) if path.name.lower() == "zp_hclass.sma" else []

    entity_type = determine_entity_type(path, text_lower)
    entity_name = extract_entity_name(lines, text, path.stem)

    record: Dict[str, object] = {
        "file": str(path.relative_to(ROOT)),
        "entity_type": entity_type,
        "entity_name": entity_name,
        "register_calls": register_lines,
        "items": items,
        "abilities": abilities,
        "human_pseudo_classes": human_classes,
    }
    record.update(stats)
    record.update(paths)

    return record


def ensure_list_serialization(record: Dict[str, object]) -> Dict[str, object]:
    for column in LIST_COLUMNS:
        value = record.get(column)
        if isinstance(value, list):
            record[column] = json.dumps(sorted(dict.fromkeys(value)))
        elif isinstance(value, set):
            record[column] = json.dumps(sorted(value))
        elif value is None:
            record[column] = json.dumps([])
        else:
            # Non-list value (e.g., string) – wrap into a list for consistency.
            record[column] = json.dumps([value]) if value else json.dumps([])
    return record


def build_dataset() -> pd.DataFrame:
    if not INPUT_DIR.exists():
        raise FileNotFoundError(f"Input directory not found: {INPUT_DIR}")
    records: List[Dict[str, object]] = []
    for sma_file in sorted(INPUT_DIR.rglob("*.sma")):
        records.append(parse_sma_file(sma_file))
    if not records:
        raise RuntimeError("No .sma files were found in the input directory")

    serializable_records = [ensure_list_serialization(record) for record in records]
    dataframe = pd.DataFrame(serializable_records)
    for column in STAT_KEYWORDS:
        if column not in dataframe:
            dataframe[column] = None
    required_columns = [
        "file",
        "entity_type",
        "entity_name",
        "stat_health",
        "stat_speed",
        "stat_gravity",
        "paths_models",
        "paths_claws",
        "paths_sounds",
        "paths_sprites",
        "abilities",
    ]
    missing_columns = [column for column in required_columns if column not in dataframe.columns]
    if missing_columns:
        for column in missing_columns:
            dataframe[column] = json.dumps([]) if column in LIST_COLUMNS else None
    return dataframe


def main() -> None:
    dataframe = build_dataset()
    csv_path = ROOT / "dataset.csv"
    parquet_path = ROOT / "dataset.parquet"

    dataframe.to_csv(csv_path, index=False)
    dataframe.to_parquet(parquet_path, index=False)

    print(f"Dataset created with {len(dataframe)} entries:")
    print(f"- CSV: {csv_path}")
    print(f"- Parquet: {parquet_path}")


if __name__ == "__main__":
    main()
