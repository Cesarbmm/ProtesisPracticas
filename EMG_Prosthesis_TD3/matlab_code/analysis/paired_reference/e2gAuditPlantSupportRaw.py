"""Reproduce el complemento raw de soporte E2G; nunca escribe historicos.

Sin argumentos completa plant_support_audit.csv producido por MATLAB y resume
los extremos de los 76 CSV originales. --verify-only comprueba hashes sin
recalcular extremos, regenerar la tabla ni ampliar el manifiesto historico.
"""

import argparse
import csv
import hashlib
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
MATLAB_ROOT = HERE.parents[1]
PROJECT_ROOT = MATLAB_ROOT.parent
OUT = HERE / "e2g_results"
RAW = MATLAB_ROOT / "development/archive/simulator_creation_assets/raw data Cx2"
SUPPORT = OUT / "plant_support_audit.csv"


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def included(path):
    speed = path.parent.name
    trial = int(re.search(r"Prueba(\d+)", path.name).group(1))
    opening = "Regreso" in path.name
    return not (
        speed == "3F" and trial in [2, 4]
        or speed == "5F" and trial == 2
        or speed == "BF" and (trial == 1 or trial == 3 and not opening)
    )


def read_csv(path, delimiter=","):
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle, delimiter=delimiter))


def write_csv(path, rows):
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def enrich_support():
    # Mismas operaciones de lectura y extremos usadas en la auditoria inicial.
    rows = read_csv(SUPPORT)
    for row in rows:
        speed = row["speed_field"].split("_")[1]
        opening = row["direction"] == "opening"
        motor = int(row["motor"])
        values, files, hashes = [], [], []
        for path in sorted((RAW / speed).glob("*.csv")):
            if ("Regreso" in path.name) != opening or not included(path):
                continue
            raw_rows = read_csv(path, delimiter=";")
            values.extend(float(item[["x", "y", "z", "w"][motor - 1]]) for item in raw_rows)
            files.append(path.relative_to(PROJECT_ROOT).as_posix())
            hashes.append(sha256(path))
        row.update(
            raw_selected_files=len(files), raw_selected_samples=len(values),
            raw_selected_min=min(values), raw_selected_max=max(values),
            raw_source_paths="|".join(files), raw_source_sha256="|".join(hashes),
        )
    assert len(rows) == 56
    write_csv(SUPPORT, rows)

    # Estadisticas de todos los originales, incluidas las nueve exclusiones;
    # no se confunden con data recortada dentro de pattern_curve.mat.
    all_extrema = {motor: [] for motor in range(1, 5)}
    selected_extrema = {motor: [] for motor in range(1, 5)}
    all_files = sorted(RAW.rglob("*.csv"))
    for path in all_files:
        raw_rows = read_csv(path, delimiter=";")
        for motor, column in enumerate(["x", "y", "z", "w"], 1):
            values = [float(item[column]) for item in raw_rows if item.get(column)]
            all_extrema[motor].extend([min(values), max(values)])
            if included(path):
                selected_extrema[motor].extend([min(values), max(values)])
    summary = dict(
        rawFiles=len(all_files), selectedRawFiles=sum(included(path) for path in all_files),
        rawGroupExtremaEqualData=sum(
            float(row["raw_selected_min"]) == float(row["data_q_min"])
            and float(row["raw_selected_max"]) == float(row["data_q_max"])
            for row in rows
        ),
        perMotor=[dict(
            motor=motor, allMin=min(all_extrema[motor]), allMax=max(all_extrema[motor]),
            selectedMin=min(selected_extrema[motor]), selectedMax=max(selected_extrema[motor]),
        ) for motor in range(1, 5)],
    )
    (OUT / "raw_support_summary.json").write_text(
        json.dumps(summary, indent=2) + "\n", encoding="utf-8"
    )
    return summary


def verify_raw_history():
    history = read_csv(OUT / "historical_hashes_before.csv")
    expected_history = {
        (MATLAB_ROOT / row["path"].replace("\\", "/")).resolve(): row["sha256"]
        for row in history
    }
    expected_support = {}
    for row in read_csv(SUPPORT):
        paths = row["raw_source_paths"].split("|")
        hashes = row["raw_source_sha256"].split("|")
        assert len(paths) == len(hashes)
        for relative_path, digest in zip(paths, hashes):
            path = (PROJECT_ROOT / relative_path).resolve()
            assert path.is_relative_to(RAW.resolve())
            assert path not in expected_support or expected_support[path] == digest
            expected_support[path] = digest

    rows = []
    for path in sorted(RAW.rglob("*.csv")):
        path = path.resolve()
        current = sha256(path)
        historical = expected_history.get(path, "")
        support = expected_support.get(path, "")
        rows.append(dict(
            path=path.relative_to(PROJECT_ROOT).as_posix(), selected=included(path),
            current_sha256=current, historical_sha256=historical,
            historical_status=("MATCH" if current == historical else "MISMATCH")
            if historical else "NO_HISTORICAL_BASELINE",
            support_artifact_sha256=support,
            support_artifact_status=("MATCH" if current == support else "MISMATCH")
            if support else "NOT_SELECTED_IN_SUPPORT_ARTIFACT",
        ))
    summary = dict(
        historicalManifestFiles=len(history), rawFilesInspected=len(rows),
        selectedRawFiles=sum(row["selected"] for row in rows),
        historicallyCovered=sum(bool(row["historical_sha256"]) for row in rows),
        historicalMatches=sum(row["historical_status"] == "MATCH" for row in rows),
        historicalMismatches=sum(row["historical_status"] == "MISMATCH" for row in rows),
        withoutHistoricalBaseline=sum(not row["historical_sha256"] for row in rows),
        selectedHistoricallyCovered=sum(row["selected"] and bool(row["historical_sha256"]) for row in rows),
        supportArtifactMatches=sum(row["support_artifact_status"] == "MATCH" for row in rows),
        supportArtifactMismatches=sum(row["support_artifact_status"] == "MISMATCH" for row in rows),
        baselineRecaptured=False,
    )
    write_csv(OUT / "raw_support_integrity.csv", rows)
    (OUT / "raw_support_integrity.json").write_text(
        json.dumps(summary, indent=2) + "\n", encoding="utf-8"
    )
    assert summary["historicalMismatches"] == 0, "Cambios en raw con baseline historico"
    assert summary["supportArtifactMismatches"] == 0, "Cambios en raw frente a tabla de soporte"
    assert summary["supportArtifactMatches"] == len(expected_support)
    return summary


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    if not args.verify_only:
        print(json.dumps(enrich_support(), indent=2))
    print(json.dumps(verify_raw_history(), indent=2))
