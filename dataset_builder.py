"""Dataset builder for Zombie Plague script files.

This module scans the ``input/`` directory looking for ``.sma`` files and
extracts metadata that can be used for machine learning datasets.
"""
from __future__ import annotations

import argparse
import json
import logging
import re
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence

import pandas as pd

ROOT = Path(__file__).resolve().parent
INPUT_DIR = ROOT / "input"
LOG_DIR = ROOT / "logs"
ERROR_LOG_PATH = LOG_DIR / "dataset_errors.log"

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

ROOT_PREFIXES: Sequence[str] = (
    "models/",
    "model/",
    "sound/",
    "sounds/",
    "sprites/",
    "materials/",
    "gfx/",
    "resources/",
    "resource/",
    "events/",
    "maps/",
    "particles/",
)


def setup_logging() -> tuple[logging.Logger, logging.Logger]:
    """Configure console and error loggers."""

    LOG_DIR.mkdir(parents=True, exist_ok=True)

    logger = logging.getLogger("dataset_builder")
    if not logger.handlers:
        logger.setLevel(logging.INFO)
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(
            logging.Formatter("[%(levelname)s] %(message)s")
        )
        logger.addHandler(console_handler)

    error_logger = logging.getLogger("dataset_builder.errors")
    if not error_logger.handlers:
        error_logger.setLevel(logging.ERROR)
        file_handler = logging.FileHandler(ERROR_LOG_PATH, mode="w", encoding="utf-8")
        file_handler.setFormatter(
            logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
        )
        error_logger.addHandler(file_handler)
        error_logger.propagate = False

    return logger, error_logger


def normalize_path(raw: str) -> str:
    """Normalize resource paths.

    Lower cases the path, replaces backslashes, removes redundant prefixes and
    condenses duplicate slashes so that the path starts at the expected root
    directory (``models/``, ``sound/``, ``sprites/``, etc.).
    """

    cleaned = raw.replace("\\", "/").strip()
    cleaned = re.sub(r"/+", "/", cleaned)
    cleaned = re.sub(r"^(?:\./)+", "", cleaned)
    while cleaned.startswith("../"):
        cleaned = cleaned[3:]
    cleaned = cleaned.lstrip("/")
    cleaned_lower = cleaned.lower()
    for prefix in ROOT_PREFIXES:
        idx = cleaned_lower.find(prefix)
        if idx >= 0:
            cleaned_lower = cleaned_lower[idx:]
            break
    return cleaned_lower


def deduplicate_ordered(values: Iterable[str]) -> List[str]:
    """Return an ordered list without duplicates."""

    seen = set()
    result: List[str] = []
    for value in values:
        if value is None:
            continue
        item = value.strip() if isinstance(value, str) else str(value)
        if not item:
            continue
        if item not in seen:
            seen.add(item)
            result.append(item)
    return result


def clean_entity_name(raw: str) -> str:
    """Normalize entity names by removing color codes and extra symbols."""

    name = re.sub(r"![a-zA-Z]", "", raw)
    name = re.sub(r"[^0-9A-Za-z\s_\-]", " ", name)
    name = re.sub(r"\s+", " ", name).strip()
    if not name:
        return raw.strip()
    return name.title()


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
    return deduplicate_ordered(register_lines)


def extract_item_calls(lines: Iterable[str]) -> List[str]:
    item_lines: List[str] = []
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("//"):
            continue
        if any(keyword in stripped for keyword in ("zp_register_extra_item", "zp_register_item", "zp_items_register")):
            if "(" in stripped:
                item_lines.append(stripped)
    return deduplicate_ordered(item_lines)


def extract_items(item_lines: Iterable[str]) -> List[str]:
    names: List[str] = []
    pattern = re.compile(r'\(\s*"([^"\n]+)"')
    for line in item_lines:
        match = pattern.search(line)
        if match:
            names.append(match.group(1).strip())
    return deduplicate_ordered(names)


def extract_abilities(text: str) -> List[str]:
    text_lower = text.lower()
    abilities = {ability for ability in ABILITY_KEYWORDS if ability in text_lower}
    return sorted(abilities)


def extract_human_classes(text: str) -> List[str]:
    pattern = re.compile(r"human class[^:]*:\s*!g\s*([^!\"]+)", re.IGNORECASE)
    classes: List[str] = []
    for match in pattern.finditer(text):
        classes.append(clean_entity_name(match.group(1).strip()))
    return deduplicate_ordered(classes)


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
            return clean_entity_name(name)
    name_pattern = re.compile(r"new\s+const\s+[A-Za-z0-9_]*name[\w\[\]]*\s*=\s*\{\s*\"([^\"\n]+)\"")
    match = name_pattern.search(text)
    if match:
        candidate = match.group(1).strip()
        if candidate:
            return clean_entity_name(candidate)
    return clean_entity_name(fallback)


def parse_sma_file(path: Path, error_logger: logging.Logger) -> Optional[Dict[str, object]]:
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except Exception as exc:  # pragma: no cover - defensive logging
        error_logger.exception("No se pudo leer el archivo %s: %s", path, exc)
        return None

    try:
        lines = text.splitlines()
        text_lower = text.lower()

        stats = extract_stats(text)
        paths = extract_paths(text)
        register_lines = extract_register_calls(lines)
        item_lines = extract_item_calls(lines)
        items = extract_items(item_lines)
        abilities = extract_abilities(text)
        human_classes = (
            extract_human_classes(text) if path.name.lower() == "zp_hclass.sma" else []
        )

        entity_type = determine_entity_type(path, text_lower)
        entity_name = extract_entity_name(lines, text, path.stem)

        for column in LIST_COLUMNS:
            if column not in ("paths_models", "paths_claws", "paths_sounds", "paths_sprites"):
                continue
            # Ensure list types for resource paths (already sorted)
            paths.setdefault(column, [])

        record: Dict[str, object] = {
            "file": str(path.relative_to(ROOT)),
            "entity_type": entity_type,
            "entity_name": entity_name,
            "register_calls": register_lines,
            "items": items,
            "abilities": abilities,
            "human_pseudo_classes": human_classes,
            "line_count": len(lines),
            "ability_count": len(abilities),
            "resource_count": sum(len(paths.get(key, [])) for key in (
                "paths_models",
                "paths_claws",
                "paths_sounds",
                "paths_sprites",
            )),
            "register_count": len(register_lines),
        }
        record.update(stats)
        record.update(paths)

        for column in LIST_COLUMNS:
            value = record.get(column)
            if value is None:
                record[column] = []
            elif isinstance(value, list):
                record[column] = value
            elif isinstance(value, set):
                record[column] = sorted(value)
            else:
                record[column] = [value]

        record["ability_count"] = len(record.get("abilities", []))
        record["register_count"] = len(record.get("register_calls", []))
        record["resource_count"] = sum(
            len(record.get(column, []))
            for column in ("paths_models", "paths_claws", "paths_sounds", "paths_sprites")
        )

        return record
    except Exception as exc:  # pragma: no cover - defensive logging
        error_logger.exception("Error procesando %s: %s", path, exc)
        return None

def dataframe_for_csv(dataframe: pd.DataFrame) -> pd.DataFrame:
    """Return a copy of the dataframe with list columns serialized as JSON."""

    csv_frame = dataframe.copy()
    def to_json_string(value: object) -> str:
        if isinstance(value, list):
            return json.dumps(value)
        if isinstance(value, set):
            return json.dumps(sorted(value))
        if value is None:
            return "[]"
        return json.dumps([value])

    for column in LIST_COLUMNS:
        if column in csv_frame:
            csv_frame[column] = csv_frame[column].apply(to_json_string)
    return csv_frame


def infer_column_type(series: pd.Series, column: str) -> str:
    if column in LIST_COLUMNS:
        return "list"
    if pd.api.types.is_integer_dtype(series):
        return "int"
    if pd.api.types.is_float_dtype(series):
        return "float"
    if pd.api.types.is_bool_dtype(series):
        return "bool"
    return "string"


def safe_write(path: Path, writer) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = path.with_suffix(path.suffix + ".tmp")
    writer(tmp_path)
    tmp_path.replace(path)


def safe_write_json(path: Path, data: object) -> None:
    def _write_json(tmp_path: Path) -> None:
        tmp_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    safe_write(path, _write_json)


def build_dataset(
    limit: Optional[int],
    logger: logging.Logger,
    error_logger: logging.Logger,
) -> tuple[pd.DataFrame, Dict[str, int]]:
    if not INPUT_DIR.exists():
        raise FileNotFoundError(f"Input directory not found: {INPUT_DIR}")

    records: List[Dict[str, object]] = []
    processed = 0
    failures = 0
    for sma_file in sorted(INPUT_DIR.rglob("*.sma")):
        if limit is not None and processed >= limit:
            break
        processed += 1
        record = parse_sma_file(sma_file, error_logger)
        if record is None:
            failures += 1
            logger.warning("Se omitió %s por errores de parseo", sma_file)
            continue
        records.append(record)

    if not records:
        raise RuntimeError("No .sma files were found in the input directory")

    dataframe = pd.DataFrame(records)
    for column in STAT_KEYWORDS:
        if column not in dataframe:
            dataframe[column] = None
        dataframe[column] = pd.to_numeric(dataframe[column], errors="coerce")
    for column in LIST_COLUMNS:
        if column not in dataframe:
            dataframe[column] = [[] for _ in range(len(dataframe))]

    summary = {
        "processed": processed,
        "valid": len(records),
        "failed": failures,
    }

    return dataframe, summary


def export_dataset(
    dataframe: pd.DataFrame,
    logger: logging.Logger,
    *,
    write_parquet: bool,
    parquet_reason: Optional[str] = None,
) -> None:
    csv_path = ROOT / "dataset.csv"
    parquet_path = ROOT / "dataset.parquet"
    preview_path = ROOT / "dataset_preview.json"
    schema_path = ROOT / "dataset_schema.json"

    csv_frame = dataframe_for_csv(dataframe)
    safe_write(csv_path, lambda tmp: csv_frame.to_csv(tmp, index=False))

    if write_parquet:
        safe_write(parquet_path, lambda tmp: dataframe.to_parquet(tmp, index=False))
        logger.info("Archivo Parquet generado en %s", parquet_path)
    else:
        if parquet_reason == "skipped":
            logger.info("Generación de Parquet omitida por configuración del usuario")
        else:
            logger.warning("Dependencias Parquet ausentes; solo se exportará CSV")

    preview_records = dataframe.head(20).to_dict(orient="records")
    safe_write_json(preview_path, preview_records)

    schema = {
        "columns": [
            {
                "name": column,
                "type": infer_column_type(dataframe[column], column),
            }
            for column in dataframe.columns
        ]
    }
    safe_write_json(schema_path, schema)

    logger.info("Archivos exportados:")
    logger.info("- CSV: %s", csv_path)
    if write_parquet:
        logger.info("- Parquet: %s", parquet_path)
    logger.info("- Vista previa: %s", preview_path)
    logger.info("- Esquema: %s", schema_path)


def summarize_dataframe(dataframe: pd.DataFrame, logger: logging.Logger) -> None:
    logger.info("Resumen de columnas clave:")
    key_columns = [
        "register_calls",
        "items",
        "abilities",
        "paths_models",
        "paths_sounds",
        "paths_sprites",
        "human_pseudo_classes",
    ]
    for column in key_columns:
        if column not in dataframe:
            continue
        series = dataframe[column]
        if column in LIST_COLUMNS:
            non_empty = series.apply(lambda value: bool(value)).sum()
        else:
            non_empty = series.notna().sum()
        logger.info("- %s: %s valores no vacíos", column, int(non_empty))


def can_export_parquet() -> bool:
    try:  # pragma: no cover - import check
        import pyarrow  # type: ignore  # noqa: F401

        return True
    except ImportError:
        try:  # pragma: no cover - import check
            import fastparquet  # type: ignore  # noqa: F401

            return True
        except ImportError:
            return False


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Construye el dataset de scripts .sma")
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Procesa solo los primeros N archivos .sma",
    )
    parser.add_argument(
        "--no-parquet",
        action="store_true",
        help="Omite la generación de la salida en formato Parquet",
    )
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> None:
    args = parse_args(argv)
    logger, error_logger = setup_logging()

    try:
        dataframe, summary = build_dataset(args.limit, logger, error_logger)
    except Exception as exc:  # pragma: no cover - defensive logging
        logger.error("No fue posible construir el dataset: %s", exc)
        sys.exit(1)

    parquet_reason = None
    if args.no_parquet:
        parquet_available = False
        parquet_reason = "skipped"
    else:
        parquet_available = can_export_parquet()

    export_dataset(
        dataframe,
        logger,
        write_parquet=parquet_available,
        parquet_reason=parquet_reason,
    )

    logger.info(
        "Archivos procesados: %s | Registros válidos: %s | Errores: %s",
        summary["processed"],
        summary["valid"],
        summary["failed"],
    )
    summarize_dataframe(dataframe, logger)


if __name__ == "__main__":
    main()
