"""Auditoria de lectura: conserva huellas de corrida y fuentes anteriores."""
import csv
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "analysis/paired_reference/e3b_run_audit"
RUN = ROOT / "results/e3b_long/run_20260909_002700_470_a733a786"
PREP = ROOT / "analysis/paired_reference/e3b_preparation"


def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(4 * 1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def verify(path, base):
    with path.open(encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    failures = []
    for row in rows:
        file = base / row["path"]
        if not file.is_file() or sha(file) != row["sha256"]:
            failures.append(row["path"])
    return {"files": len(rows), "mismatches": failures, "pass": not failures}


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    snapshot = OUT / "original_run_hashes.csv"
    if sys.argv[1] == "before":
        if snapshot.exists():
            raise RuntimeError("No sobrescribir inventario original de auditoria")
        with snapshot.open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=["path", "sha256"])
            w.writeheader()
            for p in sorted(RUN.rglob("*")):
                if p.is_file():
                    w.writerow({"path": str(p.relative_to(RUN)), "sha256": sha(p)})
    result = {
        "originalRun": verify(snapshot, RUN),
        "historical": verify(PREP / "historical_hashes_before.csv", ROOT),
        "implementation": verify(PREP / "implementation_hashes.csv", ROOT),
        "trainingExecuted": False,
    }
    (OUT / ("integrity_" + sys.argv[1] + ".json")).write_text(
        json.dumps(result, indent=2), encoding="utf-8"
    )
    print(json.dumps(result, indent=2))
    assert all(v["pass"] for v in result.values() if isinstance(v, dict))
