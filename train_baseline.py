"""Train a RandomForest baseline model for entity classification."""
from __future__ import annotations

import argparse
import ast
import json
import logging
import re
import shutil
from collections import Counter
from pathlib import Path
from typing import Iterable, List, Sequence

import joblib
import numpy as np
import pandas as pd
import seaborn as sns
from matplotlib import pyplot as plt
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
)
from sklearn.model_selection import StratifiedKFold, cross_val_score, train_test_split

RESULTS_DIR = Path("results")
LIST_COLUMNS = [
    "abilities",
    "paths_models",
    "paths_claws",
    "paths_sounds",
    "paths_sprites",
    "register_calls",
    "items",
    "human_pseudo_classes",
]
PATH_COLUMNS = [
    "paths_models",
    "paths_claws",
    "paths_sounds",
    "paths_sprites",
]
EXPECTED_STATS = [
    "stat_health",
    "stat_speed",
    "stat_gravity",
    "stat_armor",
    "stat_knockback",
]
NAME_KEYWORDS = [
    "nemesis",
    "assassin",
    "boss",
    "elite",
    "mutant",
    "guardian",
]
RANDOM_SEED = 42


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Train a RandomForest baseline classifier for entity types."
    )
    parser.add_argument(
        "--dataset-path",
        type=Path,
        help="Path to a dataset file (CSV or Parquet). Overrides default lookup.",
    )
    parser.add_argument(
        "--no-parquet",
        action="store_true",
        help="Force CSV loading even if a Parquet file is available.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        help="Limit the number of rows loaded from the dataset for debugging.",
    )
    parser.add_argument(
        "--export-debug",
        action="store_true",
        help="Export the processed dataset to results/dataset_debug.csv.",
    )
    parser.add_argument(
        "--cleanup",
        action="store_true",
        help="Delete the results directory after finishing execution.",
    )
    return parser.parse_args()


def setup_logging() -> None:
    """Configure basic logging for the script."""
    logging.basicConfig(
        level=logging.INFO,
        format="[%(asctime)s] %(levelname)s:%(name)s:%(message)s",
    )


def detect_dataset_path(args: argparse.Namespace) -> Path:
    """Determine which dataset path should be used based on CLI arguments."""
    if args.dataset_path:
        dataset_path = args.dataset_path
        if not dataset_path.exists():
            raise FileNotFoundError(f"Dataset not found at {dataset_path!s}")
        logging.info("Using dataset path provided via CLI: %s", dataset_path)
        return dataset_path

    if not args.no_parquet:
        parquet_path = Path("dataset.parquet")
        if parquet_path.exists():
            logging.info("Using default Parquet dataset at %s", parquet_path)
            return parquet_path

    csv_path = Path("dataset.csv")
    if csv_path.exists():
        logging.info("Using default CSV dataset at %s", csv_path)
        return csv_path

    raise FileNotFoundError(
        "No dataset found. Expected dataset.parquet or dataset.csv in the project root."
    )


def read_dataset(path: Path, force_csv: bool = False) -> pd.DataFrame:
    """Read a dataset from CSV or Parquet based on file extension."""
    suffix = path.suffix.lower()
    if suffix == ".parquet" and not force_csv:
        logging.info("Loading dataset from Parquet: %s", path)
        return pd.read_parquet(path)

    logging.info("Loading dataset from CSV: %s", path)
    return pd.read_csv(path)


def parse_list_cell(value: object) -> List[str]:
    """Convert a dataset cell into a list of strings."""
    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]
    if value is None:
        return []
    if isinstance(value, float) and np.isnan(value):
        return []
    if isinstance(value, str):
        cleaned = value.strip()
        if not cleaned:
            return []
        try:
            parsed = ast.literal_eval(cleaned)
        except (ValueError, SyntaxError):
            parsed = None
        if isinstance(parsed, list):
            return [str(item).strip() for item in parsed if str(item).strip()]
        if parsed is not None:
            return [str(parsed).strip()]
        # Fallback: comma separated values
        return [item.strip() for item in cleaned.split(",") if item.strip()]
    return [str(value).strip()]


def normalise_paths(paths: Iterable[str]) -> List[str]:
    """Normalise resource paths to use forward slashes and lowercase."""
    normalised: List[str] = []
    for item in paths:
        if not item:
            continue
        path_str = str(item).replace("\\", "/").lower().strip()
        if path_str:
            normalised.append(path_str)
    return normalised


def sanitise_token(value: str) -> str:
    """Create a slug suitable for feature names from arbitrary strings."""
    token = re.sub(r"[^0-9a-zA-Z]+", "_", value.lower()).strip("_")
    return token or "unknown"


def ensure_list_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Ensure that expected list-like columns exist and are properly formatted."""
    df = df.copy()
    for column in LIST_COLUMNS:
        if column not in df.columns:
            logging.warning("Column '%s' missing; filling with empty lists.", column)
            df[column] = pd.Series([[] for _ in range(len(df))], index=df.index)
        df[column] = df[column].apply(parse_list_cell)

    for column in PATH_COLUMNS:
        if column in df.columns:
            df[column] = df[column].apply(normalise_paths)

    # Normalise abilities and register calls to lowercase tokens
    if "abilities" in df.columns:
        df["abilities"] = df["abilities"].apply(
            lambda values: [sanitise_token(item) for item in values]
        )
    if "register_calls" in df.columns:
        df["register_calls"] = df["register_calls"].apply(
            lambda values: [sanitise_token(item) for item in values]
        )
    return df


def fill_missing_values(df: pd.DataFrame) -> pd.DataFrame:
    """Fill missing numeric and textual values with sensible defaults."""
    df = df.copy()

    for column in EXPECTED_STATS:
        if column not in df.columns:
            logging.warning("Stat column '%s' missing; filling with zeros.", column)
            df[column] = 0.0

    numeric_candidates = [
        "line_count",
        "resource_count",
        "register_count",
        "ability_count",
    ] + EXPECTED_STATS

    for column in numeric_candidates:
        if column in df.columns:
            df[column] = pd.to_numeric(df[column], errors="coerce")

    numeric_columns = df.select_dtypes(include=["number"]).columns
    df[numeric_columns] = df[numeric_columns].fillna(0)

    object_columns = [
        column
        for column in df.select_dtypes(include=["object"]).columns
        if column not in LIST_COLUMNS
    ]
    for column in object_columns:
        df[column] = df[column].fillna("unknown")

    return df


def build_feature_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Create model-ready feature columns from the processed dataset."""
    df = df.copy()

    df["ability_count"] = df["abilities"].apply(len)
    df["register_count"] = df["register_calls"].apply(len)
    df["model_count"] = df["paths_models"].apply(len)
    df["claw_count"] = df["paths_claws"].apply(len)
    df["sound_count"] = df["paths_sounds"].apply(len)
    df["sprite_count"] = df["paths_sprites"].apply(len)

    if "items" in df.columns:
        df["item_count"] = df["items"].apply(len)
    if "human_pseudo_classes" in df.columns:
        df["pseudo_class_count"] = df["human_pseudo_classes"].apply(len)

    ability_counter: Counter[str] = Counter()
    for abilities in df["abilities"]:
        ability_counter.update(abilities)
    top_abilities = [name for name, _ in ability_counter.most_common(10)]
    for ability in top_abilities:
        column_name = f"ability_{ability}"
        df[column_name] = df["abilities"].apply(lambda values: int(ability in values))

    register_counter: Counter[str] = Counter()
    for calls in df["register_calls"]:
        register_counter.update(calls)
    top_registers = [name for name, _ in register_counter.most_common(10)]
    for register in top_registers:
        column_name = f"reg_{register}"
        df[column_name] = df["register_calls"].apply(
            lambda values: int(register in values)
        )

    if "entity_name" not in df.columns:
        logging.warning("Column 'entity_name' missing; filling with 'unknown'.")
        df["entity_name"] = "unknown"
    else:
        df["entity_name"] = df["entity_name"].fillna("unknown")

    for keyword in NAME_KEYWORDS:
        column_name = f"name_contains_{keyword}"
        df[column_name] = (
            df["entity_name"].str.contains(keyword, case=False, na=False).astype(int)
        )

    feature_columns = pd.DataFrame(index=df.index)

    numeric_features = [
        "line_count",
        "resource_count",
        "register_count",
        "ability_count",
        "model_count",
        "claw_count",
        "sound_count",
        "sprite_count",
        "item_count",
        "pseudo_class_count",
    ] + EXPECTED_STATS

    for column in numeric_features:
        if column in df.columns:
            feature_columns[column] = pd.to_numeric(df[column], errors="coerce").fillna(0)

    additional_columns = [
        column
        for column in df.columns
        if column.startswith("ability_") or column.startswith("reg_")
    ]
    for column in additional_columns:
        feature_columns[column] = df[column].astype(int)

    keyword_columns = [
        column for column in df.columns if column.startswith("name_contains_")
    ]
    for column in keyword_columns:
        feature_columns[column] = df[column].astype(int)

    feature_columns = feature_columns.fillna(0)
    return feature_columns


def export_debug_dataset(features: pd.DataFrame, labels: pd.Series) -> None:
    """Export the processed dataset for debugging purposes."""
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    debug_path = RESULTS_DIR / "dataset_debug.csv"
    debug_df = features.copy()
    debug_df["entity_type"] = labels
    debug_df.to_csv(debug_path, index=False)
    logging.info("Exported debug dataset to %s", debug_path)


def train_and_evaluate(
    features: pd.DataFrame, labels: pd.Series
) -> tuple[RandomForestClassifier, dict]:
    """Train the RandomForest model and evaluate it on a hold-out set."""
    target_counts = labels.value_counts()
    insufficient_mask = target_counts < 2
    if insufficient_mask.any():
        problematic = ", ".join(
            f"{label} ({count})" for label, count in target_counts[insufficient_mask].items()
        )
        logging.warning(
            "Classes with fewer than 2 samples will be dropped: %s", problematic
        )
        valid_labels = target_counts[~insufficient_mask].index
        mask = labels.isin(valid_labels)
        features = features.loc[mask]
        labels = labels.loc[mask]
        target_counts = labels.value_counts()

    if labels.nunique() < 2:
        raise ValueError("Need at least two classes with sufficient samples for training.")

    X_train, X_test, y_train, y_test = train_test_split(
        features,
        labels,
        test_size=0.2,
        random_state=RANDOM_SEED,
        stratify=labels,
    )

    min_class_train = y_train.value_counts().min()
    cv_splits = 5
    if min_class_train < cv_splits:
        adjusted = max(2, int(min_class_train))
        if adjusted < cv_splits:
            logging.warning(
                "Not enough samples per class for 5-fold CV; using %d folds instead.",
                adjusted,
            )
        cv_splits = adjusted

    cv_scores: List[float] = []
    if cv_splits >= 2:
        cv = StratifiedKFold(n_splits=cv_splits, shuffle=True, random_state=RANDOM_SEED)
        cv_scores = cross_val_score(
            RandomForestClassifier(
                n_estimators=200,
                max_depth=None,
                random_state=RANDOM_SEED,
                class_weight="balanced",
                n_jobs=-1,
            ),
            X_train,
            y_train,
            scoring="accuracy",
            cv=cv,
            n_jobs=-1,
        ).tolist()
        logging.info(
            "Cross-validation accuracy scores (n=%d): %s", cv_splits, cv_scores
        )
    else:
        logging.warning("Skipping cross-validation due to insufficient samples.")

    model = RandomForestClassifier(
        n_estimators=200,
        max_depth=None,
        random_state=RANDOM_SEED,
        class_weight="balanced",
        n_jobs=-1,
    )
    model.fit(X_train, y_train)
    y_pred = model.predict(X_test)

    accuracy = accuracy_score(y_test, y_pred)
    f1_macro = f1_score(y_test, y_pred, average="macro")
    f1_micro = f1_score(y_test, y_pred, average="micro")
    conf_matrix = confusion_matrix(y_test, y_pred)
    report = classification_report(y_test, y_pred, output_dict=True, zero_division=0)

    metrics: dict[str, object] = {
        "accuracy": float(accuracy),
        "f1_macro": float(f1_macro),
        "f1_micro": float(f1_micro),
        "confusion_matrix": conf_matrix.tolist(),
        "classification_report": report,
        "train_size": int(len(X_train)),
        "test_size": int(len(X_test)),
        "cv_scores": cv_scores,
        "cv_mean": float(np.mean(cv_scores)) if cv_scores else None,
        "cv_std": float(np.std(cv_scores)) if cv_scores else None,
        "feature_columns": list(features.columns),
    }

    return model, metrics


def save_metrics(metrics: dict) -> None:
    """Save evaluation metrics to the results directory."""
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    metrics_path = RESULTS_DIR / "metrics.json"
    with metrics_path.open("w", encoding="utf-8") as handle:
        json.dump(metrics, handle, indent=2)
    logging.info("Saved metrics to %s", metrics_path)


def save_model(model: RandomForestClassifier) -> None:
    """Persist the trained model using joblib."""
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    model_path = RESULTS_DIR / "randomforest_model.pkl"
    joblib.dump(model, model_path)
    logging.info("Saved trained model to %s", model_path)


def plot_feature_importance(model: RandomForestClassifier, features: Sequence[str]) -> None:
    """Generate and store a feature importance plot for the trained model."""
    if not hasattr(model, "feature_importances_"):
        logging.warning("Model does not provide feature importances; skipping plot.")
        return

    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    importances = model.feature_importances_
    indices = np.argsort(importances)[::-1][:20]
    top_features = np.array(features)[indices]
    top_importances = importances[indices]

    plt.figure(figsize=(10, 6))
    sns.set_theme(style="whitegrid")
    sns.barplot(x=top_importances, y=top_features, orient="h", color="#1f77b4")
    plt.xlabel("Importance")
    plt.ylabel("Feature")
    plt.title("Top 20 Feature Importances (RandomForest)")
    plt.tight_layout()

    plot_path = RESULTS_DIR / "feature_importance.png"
    plt.savefig(plot_path, dpi=150)
    plt.close()
    logging.info("Saved feature importance plot to %s", plot_path)


def cleanup_results() -> None:
    """Remove the results directory if it exists."""
    if RESULTS_DIR.exists():
        shutil.rmtree(RESULTS_DIR)
        logging.info("Removed results directory at %s", RESULTS_DIR)


def main() -> None:
    """Main training workflow."""
    setup_logging()
    args = parse_args()

    try:
        dataset_path = detect_dataset_path(args)
    except FileNotFoundError as exc:
        logging.error("%s", exc)
        return

    try:
        dataframe = read_dataset(dataset_path, force_csv=args.no_parquet)
    except Exception as exc:  # pylint: disable=broad-except
        logging.error("Failed to load dataset: %s", exc)
        return

    if args.limit is not None and args.limit > 0:
        logging.info("Limiting dataset to first %d rows", args.limit)
        dataframe = dataframe.head(args.limit)

    if dataframe.empty:
        logging.error("Dataset is empty after loading; aborting training.")
        return

    dataframe = ensure_list_columns(dataframe)
    dataframe = fill_missing_values(dataframe)

    try:
        features = build_feature_columns(dataframe)
    except Exception as exc:  # pylint: disable=broad-except
        logging.error("Failed to build feature matrix: %s", exc)
        return

    if "entity_type" not in dataframe.columns:
        logging.error("Dataset is missing the target column 'entity_type'.")
        return

    labels = dataframe["entity_type"].fillna("unknown")

    if args.export_debug:
        export_debug_dataset(features, labels)

    try:
        model, metrics = train_and_evaluate(features, labels)
    except ValueError as exc:
        logging.error("Training failed: %s", exc)
        return
    except Exception as exc:  # pylint: disable=broad-except
        logging.error("Unexpected error during training: %s", exc)
        return

    save_metrics(metrics)
    save_model(model)
    plot_feature_importance(model, features.columns)

    if args.cleanup:
        cleanup_results()


if __name__ == "__main__":
    main()
