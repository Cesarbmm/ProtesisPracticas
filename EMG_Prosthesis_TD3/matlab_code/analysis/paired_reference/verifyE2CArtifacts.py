"""Revisión independiente de CSV E2C, Python estándar, sin cargar sujetos."""
import csv
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path


def verify():
    here = Path(__file__).resolve().parent
    out = here / "e2c_results"
    read = lambda name: list(csv.DictReader((out / name).open(encoding="utf-8-sig", newline="")))
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    manifest = json.loads((out / "artifact_manifest.json").read_text(encoding="utf-8"))
    for item in manifest["artifacts"]:
        assert sha(out / item["file"]) == item["sha256"], item["file"]
    for row in read("historical_hashes_before.csv"):
        assert sha(here.parents[1] / row["path"]) == row["sha256"], row["path"]
    for row in read("m3_raw_provenance.csv"):
        assert sha(Path(row["file"])) == row["sha256"]
        assert float(row["maxError"]) == 0
    eps = 1e-8  # Los CSV de MATLAB conservan 15 dígitos; MAT guarda precisión completa.
    windows = read("cycle_windows.csv")
    assert len(windows) == 8
    for row in read("cycle_reconstruction.csv"):
        n = lambda key: float(row[key])
        assert abs(n("raw") - max(-1, min(1, 2*(n("referenceBefore")-n("hBefore"))))) < 1e-12
        assert abs(n("effective")-n("pwm")/255) < 1e-12
        assert abs(n("qAfter")-n("qBefore")-n("deltaQ")) < eps
        assert abs(n("rewardMotor")-(n("trackingTermMotor")-n("actionPenaltyMotor")-n("deltaActionPenaltyMotor"))) < 1e-12
        assert abs(n("rewardEpisode")-(n("trackingTermEpisode")-n("actionPenaltyEpisode")-n("deltaActionPenaltyEpisode"))) < 1e-12
    fixed = defaultdict(list)
    for row in read("cycle_fixed_reference_replay.csv"):
        fixed[(row["caseId"], row["referenceIndex"], row["initialStateIndex"])].append(row)
    assert len(fixed) == 20
    for group in fixed.values():
        assert len(group) == 100
        tail = group[-20:]
        assert all(abs(float(a["qBefore"])-float(b["qAfter"])) < eps for a, b in zip(tail, tail[1:]))
        assert all(float(a["pwm"])*float(b["pwm"]) < 0 for a, b in zip(tail, tail[1:]))
    assert max(abs(float(r["pwmJump"])) for r in read("cycle_quantization_boundaries.csv")) == 64
    region = read("m3_intervals.csv")
    assert [int(r["pwm"]) for r in region] == [192, 224, 255]
    dense = read("m3_dense_map.csv")
    max_delta_error = max(abs(float(r["qAfter"])-float(r["qBefore"])-float(r["deltaQ"])) for r in dense)
    assert max_delta_error < eps
    assert all(float(r["error"]) == 0 for r in read("m3_api_validation.csv"))
    visits = read("m3_visitation_traces.csv")
    reverse = Counter(r["controller"] for r in visits if float(r["qAfter"]) < float(r["qBefore"]) and float(r["pwm"]) > 0)
    assert reverse == {"P_8": 125, "AGENT7250": 395}
    p2 = [r for r in visits if r["controller"] == "P_2" and r["inAnyRegion"] == "1"]
    assert len(p2) == 300
    assert Counter(r["pwm"] for r in p2 if float(r["pwm"]) > 0) == {"64": 174}
    individual = defaultdict(list)
    for row in read("m3_individual_repeats.csv"):
        individual[(row["pwm"], row["cellIndex"])].append(row)
        assert float(row["sameIndexDelta"]) == float(row["rawSameIndexDelta"])
    for row in read("m3_repeatability.csv"):
        group = individual[(row["pwm"], row["cellIndex"])]
        assert sum(float(g["sameIndexDelta"]) < 0 for g in group) == int(row["sameIndexNegative"])
        assert sum(g["sameQSupported"] == "1" for g in group) == int(row["sameQSupported"])
        assert sum(float(g["sameQDelta"]) < 0 for g in group) == int(row["sameQNegative"])
        assert abs(sum(float(g["sameIndexDelta"]) for g in group)/len(group)-float(row["sameIndexMean"])) < eps
    tests = read("test_results.csv")
    assert all(r["Passed"] == "1" and r["Failed"] == "0" and r["Incomplete"] == "0" for r in tests)
    result = {"verified": True, "artifactHashes": len(manifest["artifacts"]), "denseMapRows": len(dense),
              "maxCSVDeltaReconstructionError": max_delta_error, "fixedReplays": len(fixed),
              "m3Reversals": dict(reverse), "p2RegionVisits": len(p2), "tests": len(tests)}
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return result


if __name__ == "__main__":
    verify()
