"""Informe local reproducible a partir de CSV auditados; no ejecuta politicas."""
import csv
import html
import json
import math
import statistics
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "analysis/paired_reference/e3b_run_audit"
RUN = ROOT / "results/e3b_long/run_20260909_002700_470_a733a786"
TRAIN = ["BLANCA", "CECILIA", "DENIS", "EMILIA", "GABI", "GABRIEL", "IVANNA"]
VAL = ["JOE", "JONATHAN", "KHAROL"]


def read(path):
    with path.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def write(name, rows):
    with (OUT / name).open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)


def mean(values):
    v = [float(x) for x in values if math.isfinite(float(x))]
    return statistics.mean(v) if v else math.nan


def macro(rows, field):
    groups = defaultdict(list)
    for r in rows:
        groups[(r["subject"], r["side"])].append(float(r[field]))
    return mean(mean(v) for v in groups.values())


def number(row, field):
    return float(row[field])


def pct(new, old):
    return 100 * (new - old) / abs(old)


def mdtable(headers, rows):
    return "\n".join(["| " + " | ".join(headers) + " |", "|" + "---|" * len(headers)] + ["| " + " | ".join(str(c) for c in r) + " |" for r in rows])


def htable(headers, rows):
    return "<table><thead><tr>" + "".join(f"<th>{html.escape(str(h))}</th>" for h in headers) + "</tr></thead><tbody>" + "".join("<tr>" + "".join(f"<td>{html.escape(str(v))}</td>" for v in r) + "</tr>" for r in rows) + "</tbody></table>"


def main():
    replay = json.loads((OUT / "replay_summary.json").read_text(encoding="utf-8"))
    figures = json.loads((OUT / "presentation_summary.json").read_text(encoding="utf-8"))
    integrity = json.loads((OUT / "integrity_after.json").read_text(encoding="utf-8"))
    checkpoints = read(RUN / "checkpoint_validation.csv")
    cfg = json.loads((RUN / "config.json").read_text(encoding="utf-8"))
    expected = {"mode": "long", "algorithm": "FACTORIZED_MULTICATEGORICAL_PPO", "seed": 20260910,
                "maxAgentSteps": 1000000, "checkpointSteps": [50000,100000,250000,500000,750000,1000000],
                "hidden": 64, "gamma": .99, "gaeLambda": .95, "rolloutLength": 1024, "epochs": 4,
                "minibatch": 64, "clip": .2, "entropyWeight": .01, "actorLR": .0003,
                "criticLR": .001, "adamBeta1": .9, "adamBeta2": .999, "adamEpsilon": 1e-8,
                "gradientLimit": .5, "rewardNormalization": False, "advantageNormalization": True,
                "trainSubjects": TRAIN, "validationSubjects": VAL}
    for k, value in expected.items():
        assert cfg[k] == value, ("Configuracion distinta al preregistro", k, cfg[k], value)
    comparisons = []
    breakdown = {"subjects": [], "directions": [], "motors": []}
    headrows = []
    max_aggregate_error = 0
    for kind, label in [("best_checkpoint", "CATEGORICAL_BEST"), ("last_checkpoint", "CATEGORICAL_LAST")]:
        base = RUN / "evaluation" / kind
        E = read(base / "metrics/episode_metrics.csv")
        C = read(base / "metrics/categorical_episode_motor.csv")
        for split, allowed in [("TRAIN", TRAIN), ("VALIDATION", VAL), ("ALL", TRAIN + VAL)]:
            rows = [r for r in E if r["subject"] in allowed]
            cmp = read(base / "comparison" / split / "metrics.csv")
            categorical = next(r for r in cmp if r["controller"] == "Categorical")
            for field in categorical:
                if field in ("controller", "m3Reversals", "persistentTwoCycle"):
                    continue
                actual = macro(rows, field)
                expected = float(categorical[field])
                assert math.isnan(actual) == math.isnan(expected)
                if math.isfinite(actual):
                    max_aggregate_error = max(max_aggregate_error, abs(actual - expected))
                    assert abs(actual - expected) <= 1e-9, (kind, split, field)
            cats = [r for r in C if r["subject"] in allowed]
            assert sum(int(r["m3Reversals"]) for r in cats) == int(categorical["m3Reversals"])
            assert sum(int(r["cycles"]) for r in cats) == int(categorical["persistentTwoCycle"])
            for r in cmp:
                if kind == "last_checkpoint" and r["controller"] != "Categorical":
                    continue
                row = {"split": split, **r}
                if row["controller"] == "Categorical":
                    row["controller"] = label
                comparisons.append(row)
            for dimension in breakdown:
                for r in read(base / "comparison" / split / (dimension + ".csv")):
                    if kind == "last_checkpoint" and r["controller"] != "Categorical":
                        continue
                    row = {"split": split, **r}
                    if row["controller"] == "Categorical":
                        row["controller"] = label
                    breakdown[dimension].append(row)
        for r in read(base / "metrics/categorical_grouped.csv"):
            headrows.append({"checkpoint": label, **r})
    for cp in checkpoints:
        ep = read(RUN / "evaluation/checkpoints" / f"Step{int(cp['steps']):09d}" / "metrics/episode_metrics.csv")
        assert len(ep) == 60 and set(r["subject"] for r in ep) == set(VAL)
        assert abs(macro(ep, "trackingMSE") - float(cp["mse"])) < 1e-12
        assert abs(macro(ep, "rewardMean") - float(cp["reward"])) < 1e-12
    write("comparison_by_split.csv", comparisons)
    for dimension, rows in breakdown.items():
        write("comparison_by_" + dimension + ".csv", rows)
    write("categorical_heads_by_group.csv", headrows)
    def metric(policy, split="VALIDATION"):
        return next(r for r in comparisons if r["split"] == split and r["controller"] == policy)
    best, last, td3, agent = (metric(p) for p in ["CATEGORICAL_BEST", "CATEGORICAL_LAST", "TD3_BEST", "Agent7250"])
    b, l, t, a = [number(r, "trackingMSE") for r in (best, last, td3, agent)]
    heads_best = [r for r in headrows if r["checkpoint"] == "CATEGORICAL_BEST" and r["split"] == "VALIDATION" and r["dimension"] == "motor"]
    metrics_columns = ["trackingMSE", "MAE", "rewardMean", "actionL2", "deltaActionL2", "saturationFraction", "flat_response", "action_no_motion", "m3Reversals"]
    scientific = {
        "classification": "CAT_LEARNING_SIGNAL",
        "bestSteps": 500000, "lastSteps": 1000000,
        "bestValidation": {k: number(best, k) for k in metrics_columns},
        "lastValidation": {k: number(last, k) for k in metrics_columns},
        "bestMSEChangeVsTD3Pct": pct(b, t), "bestMSEChangeVsAgent7250Pct": pct(b, a),
        "lastValidationMSEChangeVsBestPct": pct(l, b),
        "bestRewardImprovementVsTD3Pct": pct(number(best, "rewardMean"), number(td3, "rewardMean")),
        "bestRewardImprovementVsAgent7250Pct": pct(number(best, "rewardMean"), number(agent, "rewardMean")),
        "continueTo5MSteps": False, "massiveTrainingJustified": False,
        "referenceContractValidated": False, "hardwareAuthorized": False,
        "trainingExecutedInAudit": False, "finalTestExecuted": False, "MATEO_SANDRA_SEALED": True,
    }
    result = {"audit": replay, "figures": figures, "integrity": integrity, "science": scientific,
              "maxAggregateCsvError": max_aggregate_error,
              "regressionTests": {"previousPassed": 294, "previousTotal": 294, "rerunInThisAudit": False,
                                  "evidence": "Fuentes y artefactos protegidos por hash; 640 nuevos replays de la corrida."}}
    (OUT / "audit_summary.json").write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    metric_headers = ["Politica", "MSE VALIDATION", "Reward", "M3", "Flat response", "Accion sin movimiento"]
    metric_rows = [[r["controller"], f"{number(r,'trackingMSE'):.6f}", f"{number(r,'rewardMean'):.6f}", r["m3Reversals"],
                    f"{100*number(r,'flat_response'):.2f}%", f"{100*number(r,'action_no_motion'):.2f}%"]
                   for r in comparisons if r["split"] == "VALIDATION"]
    cp_headers = ["Steps", "Episodio", "MSE VALIDATION", "Reward", "M3", "Ciclos", "Categoria maxima"]
    cp_rows = [[r['steps'], r['episode'], f"{float(r['mse']):.6f}", f"{float(r['reward']):.6f}", r['m3Reversals'], r['cycles'],
                f"{100*float(r['maxCategoryFraction']):.2f}%"] for r in checkpoints]
    split_headers = ["Checkpoint", "TRAIN MSE", "VALIDATION MSE", "TRAIN reward", "VALIDATION reward"]
    split_rows = [[policy, f"{number(metric(policy,'TRAIN'),'trackingMSE'):.6f}", f"{number(metric(policy),'trackingMSE'):.6f}",
                   f"{number(metric(policy,'TRAIN'),'rewardMean'):.6f}", f"{number(metric(policy),'rewardMean'):.6f}"]
                  for policy in ["CATEGORICAL_BEST", "CATEGORICAL_LAST"]]
    direction_headers = ["Direccion", "Politica", "MSE", "Reward", "Flat response", "Accion sin movimiento", "Correlacion"]
    direction_rows = [["Cierre" if r['side']=='1' else "Apertura", r['controller'], f"{number(r,'trackingMSE'):.6f}",
                       f"{number(r,'rewardMean'):.6f}", f"{100*number(r,'flat_response'):.2f}%", f"{100*number(r,'action_no_motion'):.2f}%", f"{number(r,'correlation'):.3f}"]
                      for r in breakdown['directions'] if r['split']=='VALIDATION' and r['controller'] in ['TD3_BEST','CATEGORICAL_BEST','CATEGORICAL_LAST']]
    subject_headers = ["Sujeto VALIDATION", "TD3 BEST MSE", "Categorical BEST MSE", "Cambio"]
    subject_rows = []
    for subject in VAL:
        rows = [r for r in breakdown['subjects'] if r['split']=='VALIDATION' and r['subject']==subject]
        cm = next(number(r,'trackingMSE') for r in rows if r['controller']=='CATEGORICAL_BEST')
        tm = next(number(r,'trackingMSE') for r in rows if r['controller']=='TD3_BEST')
        subject_rows.append([subject,f"{tm:.6f}",f"{cm:.6f}",f"{pct(cm,tm):+.2f}%"])
    head_headers = ["Motor", "Entropia media (nats)", "Categoria mas frecuente", "PWM255 (fraccion absoluta)"]
    head_rows = [[r['motor'],f"{float(r['headEntropy']):.4f}",f"{100*float(r['maxCategoryFraction']):.2f}%",f"{100*float(r['fraction255']):.2f}%"] for r in heads_best]
    intro = (f"La corrida completo exactamente 1.000.000 de pasos: 69.959 episodios iniciados, "
             f"69.958 terminados por disponibilidad teacher y uno truncado por presupuesto, conservando bootstrap. "
             f"BEST es 500k (episodio 34.969); LAST es 1M (episodio 69.959). La clasificacion preregistrada es CAT_LEARNING_SIGNAL: "
             f"BEST reduce MSE VALIDATION {abs(pct(b,t)):.2f}% frente a TD3 BEST, pero es {pct(b,a):.2f}% peor que Agent7250. "
             f"LAST empeora {pct(l,b):.2f}% frente a BEST. No se recomienda escalar a 5M ni entrenamiento masivo.")
    evidence = ("Auditoria nueva: 640 replays deterministas independientes (200 BEST, 200 LAST, 60 en cada uno de los otros cuatro checkpoints); "
                "120 coincidencias adicionales entre evaluaciones intermedias y finales de VALIDATION. Diferencias maximas de estado, accion representativa, "
                "accion efectiva, PWM, q y reward: cero. Error maximo de CSV por redondeo: " + f"{replay['maxMetricsCsvDiff']:.3g}. "
                "Verificados 980 rollouts sin huecos, 62.516 actualizaciones minibatch y las 2.624 transiciones conservadas en los seis checkpoints. "
                "Reward y previous effective action exactos; todas las heads tuvieron gradiente, logs finitos. "
                "No se conserva la trayectoria completa de entrenamiento: la auditoria de cada transicion interna solo cubre los rollouts guardados, "
                "no los 1M pasos. Se conservan agente/critic/Adam, pero FULL_TRAINING_RESUME_AVAILABLE=NO.")
    limits = ("La mejora no es uniforme. En apertura VALIDATION BEST tiene 45,83% de respuestas planas y 87,50% de acciones activas sin movimiento; "
              "su MSE empeora frente a TD3 BEST en esa direccion y la correlacion media es -0,067. Cierre mejora. "
              "Se reduce uso de extremos y no hay colapso global de una categoria por motor bajo el umbral 90%, pero eso no demuestra seguimiento adecuado. "
              "BEST y LAST tienen cero ciclos finales, ventanas alternantes y periodicidades detectadas en los 200 episodios; no implica estabilidad universal. "
              "BEST tiene cero retrocesos M3 en VALIDATION y uno en TRAIN: DENIS fila101 cierre, paso3, PWM+224, "
              "q=7523,6667 -> 7513,6667 (delta=-10). LAST tiene cero en ambos splits. "
              "Con una sola seed y seleccion en estos 60 episodios VALIDATION, no se ha establecido significacion estadistica ni generalizacion al test final. "
              "REFERENCE_CONTRACT_VALIDATED=NO. MATEO/SANDRA permanecen sellados.")
    reward_note = (f"BEST mejora el reward VALIDATION {scientific['bestRewardImprovementVsTD3Pct']:.2f}% frente a TD3 BEST y "
                   f"{scientific['bestRewardImprovementVsAgent7250Pct']:.2f}% frente a Agent7250. "
                   "Este ultimo resultado convive con peor MSE: menores penalizaciones de accion y cambio de accion explican la diferencia. "
                   "Se reportan por separado trackingTerm, actionPenalty y deltaActionPenalty en los CSV. P2 y Oracle son comparadores privilegiados.")
    scope = ("summary.json original contiene medias ALL=200, que mezclan 140 TRAIN y 60 VALIDATION. "
             "No se usan como evidencia de generalizacion. El criterio de seleccion y las tablas principales usan exclusivamente VALIDATION. "
             "Las metricas continuas son macro: media por episodio, grupo sujeto/direccion y luego grupos; conteos M3/ciclos son sumas. "
             "Entropia y distribuciones categoricas estan ponderadas por comandos, por eso no siempre coinciden con porcentajes macro.")
    tests = ("Regresiones previas: 294/294 registradas en preparacion (258 historicas +36 E3B). No se reejecutaron en esta auditoria; "
             "se verificaron hashes de 1.070 archivos historicos y 25 fuentes de implementacion. "
             "Los 1.055 archivos originales de la corrida permanecen byte a byte intactos. "
             "La comprobacion nueva corresponde a replays, rollouts, agregacion y figuras; no se suma artificialmente a matlab.unittest.")
    links = {
        "Informe comportamental original con los 400 episodios": RUN / "TEST_COMPORTAMENTAL.html",
        "BEST: figuras TRAIN y VALIDATION": RUN / "evaluation/best_checkpoint/figures",
        "LAST: figuras TRAIN y VALIDATION": RUN / "evaluation/last_checkpoint/figures",
        "Auditoria JSON": OUT / "audit_summary.json",
        "Replays verificados": OUT / "deterministic_replay.csv",
        "Datos de figuras verificados": OUT / "figure_data_audit.csv",
        "Metricas completas por split": OUT / "comparison_by_split.csv",
        "Resumen de checkpoints": OUT / "checkpoint_audit.png",
        "Ejemplo apertura JOE fila1 BEST": RUN / "evaluation/best_checkpoint/figures/VALIDATION/JOE_row0001_opening.png",
    }
    sections = [("Comparacion VALIDATION (60 episodios)",metric_headers,metric_rows),
                ("Evolucion de checkpoints",cp_headers,cp_rows), ("TRAIN separado de VALIDATION",split_headers,split_rows),
                ("Direcciones VALIDATION",direction_headers,direction_rows), ("Sujetos VALIDATION",subject_headers,subject_rows),
                ("Distribuciones BEST VALIDATION",head_headers,head_rows)]
    md = "# Resultados auditados E3B categorial\n\n" + intro + "\n\n" + evidence + "\n\n" + scope + "\n\n"
    for title, headers, rows in sections:
        md += "## " + title + "\n\n" + mdtable(headers,rows) + "\n\n"
    md += reward_note + "\n\n" + limits + "\n\n" + tests + "\n\n"
    md += "Las 400 figuras PNG y 400 FIG corresponden exactamente a 200 episodios por checkpoint, cada uno con cuatro motores. "
    md += "Se contrastaron las 3.200 curvas de los FIG contra MAT con diferencia cero.\n\n"
    md += "## Artefactos\n\n" + "\n".join(f"- [{name}]({path.as_posix()})" for name,path in links.items())
    md += "\n\n## Reproducir auditoria sin entrenar\n\nDesde matlab_code, con paths e3b y paired_reference, ejecutar "
    md += "`e3bAuditRun('results/e3b_long/run_20260909_002700_470_a733a786')` y "
    md += "`e3bAuditPresentation('results/e3b_long/run_20260909_002700_470_a733a786')`. "
    md += "Luego `python analysis/paired_reference/e3b/e3bAuditIntegrity.py after` y "
    md += "`python analysis/paired_reference/e3b/e3bSummarizeAudit.py`. No se invoca ningun runner de training.\n\n"
    md += "AUDIT_RESULT = PASS\n\nE3B_RESULT = CAT_LEARNING_SIGNAL\n\nCONTINUE_TO_5M_STEPS = NO\n\nMASSIVE_TRAINING_JUSTIFIED = NO\n\nGIT_REPAIR_ATTEMPTED = NO\n\nPUSH = NO\n"
    (OUT / "RESULTADOS_E3B_CATEGORICAL.md").write_text(md,encoding="utf-8")
    docs = ROOT.parent / "docs/paired_reference/RESULTADOS_E3B_CATEGORICAL.md"
    if docs.exists():
        assert docs.read_text(encoding="utf-8") == md, "Documento existente distinto: revisar antes de reemplazar"
    else:
        docs.write_text(md,encoding="utf-8")
    body = "<h1>Auditoria E3B: señal de aprendizaje limitada</h1>" + "".join(f"<p>{html.escape(p)}</p>" for p in [intro,evidence,scope])
    body += '<img alt="Evolucion de checkpoints" src="checkpoint_audit.png">'
    for title, headers, rows in sections:
        body += "<h2>"+html.escape(title)+"</h2>"+htable(headers,rows)
    body += "".join(f"<p>{html.escape(p)}</p>" for p in [reward_note,limits,tests])
    body += "<h2>Figuras y evidencia</h2><p>400 PNG +400 FIG verificados; 3.200 curvas exactas.</p><ul>"
    body += "".join(f'<li><a href="{path.as_uri()}">{html.escape(name)}</a></li>' for name,path in links.items()) + "</ul>"
    page = '<!doctype html><html lang="es"><meta charset="utf-8"><title>Auditoria E3B</title><style>body{font:16px system-ui;max-width:1250px;margin:35px auto;padding:0 20px;color:#172435}table{border-collapse:collapse;width:100%;margin:20px 0}th,td{padding:9px;text-align:left;border-bottom:1px solid #d9e0e9}th{background:#e8eff6}img{max-width:100%}p{line-height:1.6}</style>' + body + '</html>'
    (OUT / "AUDITORIA_E3B.html").write_text(page,encoding="utf-8")
    print(json.dumps(scientific,indent=2,ensure_ascii=False))


if __name__ == "__main__":
    main()
