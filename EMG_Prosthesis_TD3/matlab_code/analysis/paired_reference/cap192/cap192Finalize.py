"""Informe desde artefactos medidos; no ejecuta inferencia ni entrenamiento."""
from pathlib import Path
import csv, json, html, hashlib
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/"analysis/paired_reference/cap192_results"
DOCS=ROOT.parent/"docs/paired_reference"
def read(name):
    with (OUT/name).open(encoding="utf-8-sig",newline="") as f:return list(csv.DictReader(f))
def num(r,key):return float(r[key])
def table(rows,columns):
    lines=["| "+" | ".join(title for key,title in columns)+" |","|"+"|".join("---" for _ in columns)+"|"]
    for r in rows:
        cells=[]
        for key,title in columns:
            v=r[key]
            if isinstance(v,float):v=f"{v:.8f}"
            cells.append(str(v))
        lines.append("| "+" | ".join(cells)+" |")
    return "\n".join(lines)
def main():
    tests=json.loads((OUT/"tests/summary.json").read_text(encoding="utf-8-sig"))
    integrity=json.loads((OUT/"historical_integrity.json").read_text(encoding="utf-8-sig"))
    assert tests["previousPassed"]==233 and tests["passed"]==tests["totalTests"] and tests["failed"]==tests["incomplete"]==0
    assert integrity["unchanged"]
    measured=json.loads((OUT/"gate_measurement.json").read_text(encoding="utf-8-sig"))
    g=measured["gate"];g["testsPass"]=True;g["hashesIntact"]=True
    gates=["msePass","rewardPass","m3Pass","orbitPass","boundPass","zeroMotionPass","offReproduced","testsPass","hashesIntact"]
    g["supported"]=all(g[k] for k in gates)
    assert not g["supported"],"Este informe de cierre FAIL no prepara E3B."
    measured.update(status="COMPLETE",tests=tests,integrity=integrity,CAP192_SUPPORTED=False,
        TD3_CONTINUOUS_SCALING_NOT_JUSTIFIED=True,nextAgent="FACTORIZED_CATEGORICAL",
        E3B_PREPARED=False,E3B_STARTED=False,trainingExecuted=False,referenceContractValidated=False,
        MATEO_SANDRA_SEALED=True,GIT_REPAIR_ATTEMPTED=False,PUSH=False)
    (OUT/"summary.json").write_text(json.dumps(measured,indent=2,ensure_ascii=False),encoding="utf-8")
    S=read("comparison.csv")
    for r in S:
        for k in r:
            if k not in ["controller","split"]:r[k]=float(r[k])
    best=next(r for r in S if r["controller"]=="BEST_CAP192" and r["split"]=="VALIDATION")
    original=next(r for r in S if r["controller"]=="BEST_OFF" and r["split"]=="VALIDATION")
    core=table([r for r in S if r["split"]!="ALL"],[("split","Split"),("controller","Política"),("trackingMSE","MSE"),("rewardMean","Reward"),("m3Reversals","Retrocesos M3"),("boundHitFraction192","Fracción en 192")])
    details=table([r for r in S if r["split"]=="VALIDATION"],[("controller","Política"),("MAE","MAE"),("actionL2","actionL2"),("deltaActionL2","deltaActionL2"),("flat_response","flat_response"),("action_no_motion","action_no_motion")])
    counts=read("grouped_counts.csv")
    grouped=[r for r in counts if r["controller"]=="BEST_CAP192" and r["split"]=="VALIDATION" and r["horizon"]=="COMMON"]
    support=table(grouped,[("dimension","Agrupación"),("value","Valor"),("commands","Comandos"),("boundHits192","En 192"),("boundHitFraction192","Fracción")])
    gate_table=table([{"gate":k,"result":"PASS" if g[k] else "FAIL"} for k in gates],[("gate","Criterio"),("result","Resultado")])
    diff=100*(best["action_no_motion"]-original["action_no_motion"])
    md=f"""# Resultados del diagnóstico CAP192

CAP192_SUPPORTED = NO. El recorte conserva casi el mismo tracking y elimina los retrocesos M3 observados, pero concentra el **70.678654 %** de los comandos de BEST VALIDATION en el nuevo límite. El gate fijado antes de medir era <=50 %. No se prepara E3B ni se entrena.

## Diseño e integridad

Se aplicó solamente clip(raw,±192/255), sin multiplicar las acciones interiores ni cambiar el cuantizador. BEST Episode10000 y LAST Episode20000, 200 episodios cada uno, OFF y CAP: **800 ejecuciones completas EMG-only**, 400 reproducciones OFF exactas frente a la corrida guardada. Todos los estados, raw, effective, PWM y q OFF coinciden exactamente; reward tiene diferencia cero. Mismos 140 TRAIN /60 VALIDATION; teacher y horizonte común originales. Ningún peso se actualizó.

El actor recibe el estado realmente alcanzado. Cada estado siguiente contiene PWM_aplicado/255 en previousAction; por ello el contrafactual no es un recorte cosmético de las trazas antiguas. Se guardaron desiredRaw y commandRaw por separado, además de runtime completo y métricas teacher posteriores.

El preregistro y {integrity["files"]} archivos quedaron protegidos antes de las comparaciones; todos conservaron sus hashes, incluidos runtime, planta, remapeo, reward, pruebas y checkpoints históricos. HEAD: 165be049eb41fc41254435181c9857fe0f22ed1c. Sin reparación Git ni publicación.

## Resultado por split

MSE y reward mantienen la agregación macro sujeto/dirección histórica. Las fracciones en el límite se ponderan por número de comandos e incluyen PWM0.

{core}

BEST VALIDATION: MSE empeora **{g["mseChangePct"]:.6f} %**, reward mejora **{-g["rewardWorseningPct"]:.6f} %**, retrocesos M3 **134→0**. LAST VALIDATION: MSE 0.0671469254201835 y retrocesos **81→0**. No hay ciclos finales, ventanas alternantes detectadas ni periodicidad final en ninguno de los cuatro grupos, tanto en el horizonte teacher común como en el runtime EMG-only completo. Esto no demuestra estabilidad universal.

{details}

El reward mejora por reducción de penalizaciones, no por mejor tracking: en BEST VALIDATION el término tracking pasa de {-original["trackingMSE"]:.12f} a {-best["trackingMSE"]:.12f}; action penalty de {original["actionPenalty"]:.12f} a {best["actionPenalty"]:.12f}; delta-action penalty de {original["deltaActionPenalty"]:.12f} a {best["deltaActionPenalty"]:.12f}. Los pesos siguen siendo .01 y .05.

La fracción macro action_no_motion aumenta **{diff:.6f} puntos porcentuales**. No se usa esta subida como un gate añadido retrospectivamente, pero refuerza la limitación operacional medida. flat_response aumenta de 15.0000 % a15.4167 % en BEST VALIDATION. La saturationFraction histórica >=.95 es cero por construcción al recortar; no constituye evidencia de estabilidad ni de eliminación de saturación.

## Concentración en el límite

BEST VALIDATION: **2437/3448 comandos** en abs(PWM)=192; **68.039443 %** de desiredRaw fueron recortados. Son cantidades distintas porque el remapeo histórico puede enviar PWM192 sin que el raw supere192/255.

{support}

M3 alcanza el límite en **87.819026 %** de sus comandos. El efecto no se limita a un único sujeto ni dirección. BEST TRAIN tiene83.080443 % en192; LAST VALIDATION58.323666 %. El cap evita las inversiones observadas en estas trazas, pero sigue concentrando la salida del actor en el mayor comando permitido. PWM192 conserva su pequeña región histórica de inversión M3: cero eventos aquí no equivale a seguridad universal de ese PWM.

## Gate congelado

{gate_table}

El único gate científico que falla es boundPass (70.678654 % frente a50 %); los demás criterios y controles de integridad pasan. No se cambió el umbral después de observar datos. No se ensayaron otros caps ni heurísticas.

TD3_CONTINUOUS_SCALING_NOT_JUSTIFIED = YES para el siguiente escalado propuesto. No es una refutación universal de TD3 ni una demostración de que un actor nuevo entrenado con cap deba fallar. Este contrafactual usa actores existentes; según el gate solicitado, no justifica abrir ese entrenamiento.

La siguiente familia recomendada es **FACTORIZED_CATEGORICAL**, cuatro cabezas, cada una sobre15acciones históricas. La recomendación responde al conjunto discreto que recibe esta planta y a la concentración observada; no se implementa ni se entrena.

## Artefactos y figuras

- [Comparación completa](../../matlab_code/analysis/paired_reference/cap192_results/comparison.csv).
- [Figura resumen](../../matlab_code/analysis/paired_reference/cap192_results/comparison.png), también FIG/PDF.
- Métricas por episodio/motor y resúmenes por sujeto/motor/dirección, para ALL/TRAIN/VALIDATION.
- Distribución PWM firmada por episodio/motor, conteos agrupados, ventanas de ciclos, reproducción OFF y cuatro conjuntos de trazas MAT/CSV.
- Ocho figuras PNG+FIG, una con cuatro motores por cada caso BLANCAfila1cierre /IVANNAfila104apertura y cada checkpoint/modo. Se reutiliza e3axPlotEpisode; no se anotan números sobre las muestras. Estas ilustraciones no sustituyen las métricas de los200episodios.
- [Informe navegable local](../../matlab_code/analysis/paired_reference/cap192_results/RESULTADOS.html).

## Viewer pasivo

exportE3AXViewerTrace está probado: cuatro exportaciones BLANCAfila1cierre (BEST/LAST, OFF/CAP) reproducen exactamente las trazas guardadas. Cada viewer_trace.mat contiene q en encoder counts (N+1×4), PWM firmado (N×4), step0..N, commandStep1..N, Ts=.2, tiempo, subject,row,direction,policy,checkpoint/hash y manifiesto de planta. PWM(k) actúa sobre q(k) y produceq(k+1), con índices MATLAB.

La exportación carga saved_actor y únicamente EMG del sujeto autorizado; no carga guante. Procedencia: saved_actor→GloveFreePolicyRuntime→patternCurveCanonical. No se importa ni se abre sandbox.

Futura integración, sólo si se autoriza reabrirla: HandKinematicViewer debe leer q(t) directamente como visualización pasiva. No llamar DynamicPlantAdapter/S4 ni volver a simular dinámica. P2/Oracle requerirán conservar la procedencia privilegiada de sus trazas existentes; no atribuirles procedencia saved_actor. Integración diferida.

## Reproducción y pruebas

Comando del diagnóstico (en MATLAB, desde matlab_code): addpath('analysis/paired_reference/cap192'); runCAP192Diagnostic(). Se niega a sobrescribir measurements.mat si ya existe. Para repetir en otra copia científica, conservar el manifiesto y preregistro originales; no recapturar hashes para ocultar cambios.

Para verificar sin repetir inferencia: cap192RunTests(). El exportador público y su ejemplo están en README_VIEWER.md junto a los resultados. No hay ningún comando nuevo de training.

**Tests históricos: {tests["previousPassed"]}/{tests["previousTests"]}; nuevos: {tests["newPassed"]}/{tests["newTests"]}; total: {tests["passed"]}/{tests["totalTests"]}.** Las pruebas unitarias no son episodios de evaluación y no generan una figura por test.

REFERENCE_CONTRACT_VALIDATED = NO. HARDWARE_AUTHORIZED = NO. MATEO/SANDRA sellados. E3B_PREPARED = NO; E3B_STARTED = NO. CONTINUE_TO_500K_RECOMMENDED = NOT_YET. TWO_MILLION_EPISODES_JUSTIFIED = NO_POR_AHORA. GIT_REPAIR_ATTEMPTED = NO. PUSH = NO.
"""
    (DOCS/"RESULTADOS_CAP192.md").write_text(md,encoding="utf-8")
    (OUT/"RESULTADOS.md").write_text(md,encoding="utf-8")
    parts=["<!doctype html><html lang='es'><meta charset='utf-8'><title>Diagnóstico CAP192</title><style>body{font:16px system-ui;max-width:1200px;margin:30px auto;padding:0 20px;color:#172339}table{border-collapse:collapse;width:100%}td,th{padding:8px;border:1px solid #ddd}img{max-width:100%}a{color:#135d9e}pre{white-space:pre-wrap}</style><h1>CAP192: no apoyado por el gate</h1>",
           "<p>BEST VALIDATION: MSE +0.6114 %, reward mejora6.2421 %, retrocesos134→0. Bloqueador:70.6787 % de comandos enPWM192, gate≤50 %. Sin entrenamiento.</p>",
           "<p><a href='summary.json'>Gate e integridad</a> · <a href='comparison.csv'>Métricas completas</a> · <a href='tests/all_test_results.csv'>Tests</a> · <a href='README_VIEWER.md'>Exportador viewer</a></p>",
           "<img src='comparison.png' alt='Comparación TRAIN y VALIDATION de MSE reward retrocesos concentración y movimiento'>"]
    parts.append(f"<p>Tests: {tests['passed']}/{tests['totalTests']}. Hashes: {integrity['files']} intactos. 800 replays, ningún training.</p>")
    parts.append("<h2>Figuras compactas de los dos casos históricos</h2>")
    for p in sorted((OUT/"figures").rglob("*.png")):
        rel=p.relative_to(OUT).as_posix();fig=p.with_suffix(".fig").relative_to(OUT).as_posix()
        parts.append(f"<p>{html.escape(p.parent.name+' / '+p.stem)} · <a href='{rel}'>PNG</a> · <a href='{fig}'>FIG</a></p><img loading='lazy' src='{rel}'>")
    parts.append("<h2>Informe completo</h2><pre>"+html.escape(md)+"</pre></html>")
    (OUT/"RESULTADOS.html").write_text("\n".join(parts),encoding="utf-8")
    # Huellas de la implementación nueva para reproducir los artefactos.
    files=list((ROOT/"analysis/paired_reference/cap192").glob("*.*"))+[ROOT/"exportE3AXViewerTrace.m",ROOT/"tests/paired_reference/testCAP192Diagnostic.m"]
    with (OUT/"implementation_hashes.csv").open("w",newline="",encoding="utf-8") as f:
        w=csv.writer(f);w.writerow(["path","sha256"])
        for p in sorted(files):w.writerow([str(p.relative_to(ROOT)),hashlib.sha256(p.read_bytes()).hexdigest()])
    print(json.dumps({"CAP192_SUPPORTED":g["supported"],"tests":tests,"hashes":integrity},indent=2))
if __name__=="__main__":main()
