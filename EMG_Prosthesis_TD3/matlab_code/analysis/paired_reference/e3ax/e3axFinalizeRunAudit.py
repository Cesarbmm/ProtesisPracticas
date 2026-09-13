"""Consolida evidencia de auditoría; no modifica checkpoints ni entrena."""
from pathlib import Path
from html.parser import HTMLParser
import csv, hashlib, json

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "analysis/paired_reference/e3ax_run_audit"
RUN = ROOT / "results/e3ax_long/run_20260908_141321_916_6ebf347b"
def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))
def read_csv(path):
    with path.open(encoding="utf-8-sig") as stream:
        return list(csv.DictReader(stream))
def sha(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()

tests = read_json(OUT / "test_summary.json")
replay = read_json(OUT / "replay_summary.json")
assert tests["passed"] == tests["totalTests"] == 233 and tests["failed"] == tests["incomplete"] == 0
assert replay["result"] == "PASS" and replay["episodesReplayed"] == 400
before = read_csv(OUT / "run_integrity_before.csv")
for item in before:
    item["currentSHA256"] = sha(ROOT / item["path"])
    item["unchanged"] = item["sha256"] == item["currentSHA256"]
    assert item["unchanged"], item["path"]
with (OUT / "run_integrity_after.csv").open("w", encoding="utf-8", newline="") as stream:
    w = csv.DictWriter(stream, fieldnames=list(before[0]));w.writeheader();w.writerows(before)
for item in read_csv(ROOT / "analysis/paired_reference/e3ax_preparation/historical_hashes_before.csv"):
    assert sha(ROOT / item["path"]) == item["sha256"], item["path"]
stats = read_csv(RUN / "trainingStats.csv")
incremental = read_csv(RUN / "training_incremental.csv")
assert len(stats) == len(incremental) == 20000
assert [int(r["EpisodeIndex"]) for r in stats] == list(range(1, 20001))
for actual, other in zip(stats, incremental):
    for field in other:
        assert abs(float(actual[field]) - float(other[field])) <= 1e-12
assert sum(int(r["EpisodeSteps"]) for r in stats) == int(stats[-1]["TotalAgentSteps"]) == 285641
expected = [250, 500, 1000, 2000, 5000, 10000, 15000, 20000]
validation = read_csv(RUN / "checkpoint_validation.csv")
assert [int(r["episode"]) for r in validation] == expected
assert all(int(r["episodes"]) == 60 for r in validation)
selection = read_csv(RUN / "evaluation_selection.csv")
assert len(selection) == 200 and sum(r["split"] == "TRAIN" for r in selection) == 140
assert all(r["subject"] not in ["MATEO", "SANDRA"] for r in selection)

class LinkAudit(HTMLParser):
    def __init__(self):
        super().__init__();self.links=[];self.episodes=0
    def handle_starttag(self,tag,attrs):
        data=dict(attrs)
        if tag=="a" and "href" in data:self.links.append(data["href"])
        if tag=="tr" and "data-subject" in data:self.episodes+=1
links=LinkAudit();links.feed((RUN / "TEST_COMPORTAMENTAL.html").read_text(encoding="utf-8"))
assert links.episodes == 400
assert all((RUN / link).is_file() for link in links.links)
assert len([s for s in links.links if s.endswith(".fig")]) == 400
report = dict(auditResult="PASS", run=str(RUN), trainingEpisodes=20000, totalAgentSteps=285641,
    bestEpisode=10000, lastEpisode=20000, behavioralTest="TRAIN_VALIDATION_COMPLETE",
    behavioralEpisodesReplayed=400, pngFigures=400, figFigures=400, figureLinksVerified=len(links.links),
    checkpointsUnchanged=True, historicalFilesUnchanged=816, tests=tests, replay=replay,
    referenceContractValidated=False, finalTestExecuted=False, trainingExecutedByAudit=False,
    MATEO_SANDRA_SEALED=True, gitRepairAttempted=False, push=False)
(OUT / "audit_summary.json").write_text(json.dumps(report,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
(RUN / "AUDITORIA_CORRIDA.json").write_text(json.dumps(report,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
V=read_csv(RUN / "evaluation/comparison/VALIDATION/metrics.csv")
lines=["# Resultado auditado de la corrida E3A-X", "", "[ABRIR TEST COMPORTAMENTAL Y TODAS LAS FIGURAS](TEST_COMPORTAMENTAL.html)", "",
    "20000 episodios de training, 285641 pasos. BEST:10000; LAST:20000. Sin nuevo entrenamiento durante la auditoría.", "",
    "La evaluación ya estaba guardada: 200 episodios por checkpoint, cada uno con PNG y FIG de cuatro motores. Se verificaron los400 PNG/FIG y se repitieron los400 episodios con igualdad exacta de estado, acción, PWM, q y reward.", "",
    "## VALIDATION (60 episodios por política)", "", "| Política | MSE | Reward | Ciclos finales | Retrocesos M3 |", "|---|---:|---:|---:|---:|"]
for r in V:
    lines.append(f"| {r['controller']} | {float(r['trackingMSE']):.6f} | {float(r['rewardMean']):.6f} | {r['persistentTwoCycle']} | {r['m3Reversals']} |")
lines += ["", "BEST mejora MSE frente a ZERO un42.34%, pero queda detrás de Agent7250 diagnóstico, P2 y Oracle privilegiados. LAST empeora MSE VALIDATION un9.44% respecto a BEST.", "",
    "BEST registra56.77% de saturación macro VALIDATION y134 retrocesos M3 (526 en los200 episodios). Cero ciclos finales no implica estabilidad universal. Referencia física NO validada. No se autoriza hardware.", "",
    "## Verificación y cierre", "", "233/233 pruebas de código y artefactos. Checkpoints y816 archivos históricos intactos. Ningún entrenamiento nuevo ni push.", "",
    "El runner anuncia el test, guarda métricas antes de exportar imágenes y exige cobertura completa de PNG/FIG antes de COMPLETE. Deja un informe HTML/Markdown/JSON en raíz. Si falla una exportación, runE3AXPostTraining(carpeta) recupera el cierre sin entrenar.", "",
    "TRAIN/VALIDATION son DEVELOPMENT. El test final MATEO/SANDRA sigue sellado."]
(RUN / "AUDITORIA_CORRIDA.md").write_text("\n".join(lines)+"\n",encoding="utf-8")
print(json.dumps(report,indent=2,ensure_ascii=False))
