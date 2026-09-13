"""Audita y registra la preparación terminada; no ejecuta MATLAB ni Git."""
from pathlib import Path
import csv
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = HERE.parent / "e3ax_preparation"
SMOKE = Path((OUT / "smoke_path.txt").read_text(encoding="utf-8-sig").strip())
read = lambda p: json.loads(p.read_text(encoding="utf-8-sig"))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
summary = read(SMOKE / "summary.json")
tests = read(OUT / "regression/test_summary.json")
assert summary["mode"] == "smoke" and summary["completedEpisodes"] == 5
assert summary["learning"]["actorChanged"] and all(summary["learning"]["criticsChanged"])
assert tests["previousPassed"] == 196 and tests["passed"] == tests["totalTests"]
assert tests["newE3AXPassed"] == 29 and tests["failed"] == tests["incomplete"] == 0
assert (SMOKE / "COMPLETED.txt").is_file() and not (SMOKE / "FAILED.txt").exists()
assert not list((ROOT / "results/e3ax_long").glob("run_*")), "Hay una corrida larga: auditar su procedencia."

with (OUT / "historical_hashes_before.csv").open(encoding="utf-8-sig") as f:
    history = list(csv.DictReader(f))
assert len(history) == 816
for item in history:
    assert "sandbox" not in item["path"].lower()
    assert sha(ROOT / item["path"]) == item["sha256"], item["path"]
protocol = ROOT.parent / "docs/paired_reference/PROTOCOLO_E3AX.md"
assert read(SMOKE / "manifest.json")["protocolSHA256"] == sha(protocol)
with (SMOKE / "trainingStats.csv").open(encoding="utf-8-sig") as f:
    rows = list(csv.DictReader(f))
assert [int(r["EpisodeIndex"]) for r in rows] == list(range(1, 6))
assert int(rows[-1]["TotalAgentSteps"]) == 110
for checkpoint in ["best_checkpoint", "last_checkpoint"]:
    figs = SMOKE / "evaluation" / checkpoint / "figures"
    assert len(list(figs.rglob("*.png"))) == len(list(figs.rglob("*.fig"))) == 4
for extension in ["fig", "png", "pdf", "svg"]:
    assert (SMOKE / f"training_progress.{extension}").stat().st_size > 0
assert (SMOKE / "training_monitor_observed.png").is_file()

source_files = list(HERE.glob("*.m")) + list(HERE.glob("*.py"))
source_files += list((ROOT / "tests/paired_reference").glob("testE3AX*.m"))
source_files += [ROOT / "runE3AXLongTraining.m", ROOT / "runE3AXSmokeTest.m", protocol,
                 ROOT.parent / "docs/paired_reference/PREPARACION_E3AX.md"]
def manifest(files, destination):
    import os
    with destination.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["path", "sha256", "bytes"])
        writer.writeheader()
        for p in sorted(files):
            writer.writerow(dict(path=os.path.relpath(p, ROOT), sha256=sha(p), bytes=p.stat().st_size))
manifest(source_files, OUT / "e3ax_source_manifest.csv")
manifest([p for p in SMOKE.rglob("*") if p.is_file()], OUT / "smoke_artifact_manifest.csv")

command = f"cd('{ROOT}'); summary = runE3AXLongTraining();"
(OUT / "MANUAL_LONG_TRAINING_COMMAND.txt").write_text(command + "\n", encoding="utf-8")
report = dict(
    E3AX_PREPARATION="PASS", TRAINING_PROGRESS_ENABLED=True,
    TRAINING_WINDOW_EXPECTED_VISIBLE=True, TRAINING_MONITOR_OBSERVED=True,
    LONG_RUN_STARTED_BY_AI=False, SMOKE_EPISODES=5, SMOKE_AGENT_STEPS=110,
    SMOKE_RESULT="PASS", SMOKE_OUTPUT=str(SMOKE),
    TRAINING_RUNNER="runE3AXLongTraining", MANUAL_LONG_TRAINING_COMMAND=command,
    TRAINING_OUTPUT_DIRECTORY=str(ROOT / "results/e3ax_long/run_<timestamp>_<UUID>"),
    CHECKPOINTS=[250, 500, 1000, 2000, 5000, 10000, 15000, 20000],
    TRAINING_STATS_SAVE=["trainingStats.mat", "trainingStats.csv", "training_incremental.csv"],
    TRAINING_GRAPH_SAVE=["training_progress.png", "training_progress.fig", "training_progress.pdf", "training_progress.svg"],
    TRAINING_MONITOR_SCREENSHOT="NOT_RELIABLY_SUPPORTED",
    EXISTING_COMPACT_EPISODE_PLOTTER_FOUND=True, PLOTTER_USED="e3axPlotEpisode",
    BEST_CHECKPOINT_FULL_EPISODE_PLOTS=True, LAST_CHECKPOINT_FULL_EPISODE_PLOTS=True,
    FIGURE_LAYOUT="ONE_FIGURE_PER_EPISODE_4_MOTORS", REGRESSION_TESTS="196/196",
    E3AX_NEW_TESTS="29/29", TOTAL_TESTS="225/225", HISTORICAL_FILES_UNCHANGED=816,
    AGENT_CHECKPOINT_AVAILABLE=True, FULL_TRAINING_RESUME_AVAILABLE=False,
    REFERENCE_CONTRACT_VALIDATED=False, EXPLORATORY_RL_TRAINING_AUTHORIZED=True,
    HARDWARE_AUTHORIZED=False, MATEO_SANDRA_SEALED=True, GIT_REPAIR_ATTEMPTED=False,
    PUSH=False,
)
(OUT / "preparation_summary.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps(report, indent=2, ensure_ascii=False))
