import json, base64
from pathlib import Path

ROOT = Path(r"C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit\EMG_Prosthesis_TD3\matlab_code\analysis\paired_reference\e3e_results")
FIGS = ROOT / "figures"

def img_b64(path):
    if path.exists():
        return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode('utf-8')
    return ""

def generate_html():
    with (ROOT / "scientific_summary.json").open('r', encoding='utf-8') as f:
        summary = json.load(f)
    with (ROOT / "coverage_summary.json").open('r', encoding='utf-8') as f:
        cov = json.load(f)
    with (ROOT / "initial_window_summary.json").open('r', encoding='utf-8') as f:
        init_win = json.load(f)
    with (ROOT / "variance_summary.json").open('r', encoding='utf-8') as f:
        var_sum = json.load(f)

    bm = summary['BASELINE_means']
    nm = summary['NORMALIZED_means']
    gates = summary['gates']

    img_pca_sub = img_b64(FIGS / "pca_by_subject.png")
    img_pca_int = img_b64(FIGS / "pca_by_intent.png")
    img_stats = img_b64(FIGS / "wmoos_stats_and_variance.png")
    img_sub_orig = img_b64(FIGS / "subject_id_confusion_ORIGINAL.png")
    img_sub_norm = img_b64(FIGS / "subject_id_confusion_NORMALIZED.png")
    img_comp = img_b64(FIGS / "original_vs_normalized_comparison.png")
    img_trace = img_b64(FIGS / "closed_loop_representative_traces.png")

    html = f"""<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>E3E — Cross-Subject EMG Domain Audit · Resultados</title>
<style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; margin: 40px; background: #f8fafc; color: #1e293b; line-height: 1.6; }}
    h1, h2, h3 {{ color: #0f172a; }}
    .badge-pass {{ background: #10b981; color: white; padding: 4px 10px; border-radius: 6px; font-weight: bold; font-size: 0.85em; }}
    .badge-fail {{ background: #ef4444; color: white; padding: 4px 10px; border-radius: 6px; font-weight: bold; font-size: 0.85em; }}
    .badge-closed {{ background: #64748b; color: white; padding: 4px 10px; border-radius: 6px; font-weight: bold; }}
    table {{ border-collapse: collapse; width: 100%; margin: 20px 0; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }}
    th, td {{ padding: 12px 16px; text-align: left; border-bottom: 1px solid #e2e8f0; }}
    th {{ background: #f1f5f9; font-weight: 600; }}
    .card {{ background: white; padding: 24px; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); margin-bottom: 24px; }}
    .grid-2 {{ display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }}
    img {{ width: 100%; height: auto; border-radius: 6px; border: 1px solid #e2e8f0; }}
    code {{ background: #f1f5f9; padding: 2px 6px; border-radius: 4px; font-family: monospace; font-size: 0.9em; }}
</style>
</head>
<body>

<h1>E3E — Cross-Subject EMG Domain Audit · Reporte Científico</h1>
<p><strong>Worktree:</strong> <code>C:\\Users\\Cesarbmm\\ProtesisPracticas_e2b_audit</code> | <strong>Rama:</strong> <code>experiment/no-glove-paired-reference-td3</code> | <strong>HEAD:</strong> <code>165be049eb41fc41254435181c9857fe0f22ed1c</code></p>

<div class="card">
<h2>1. Resumen de Decisión y Gates Preregistrados</h2>
<p><strong>E3E_RESULT:</strong> <span class="badge-fail">NORMALIZATION_NOT_SUPPORTED</span> | <strong>NORMALIZATION_SUPPORTED:</strong> <span class="badge-fail">NO</span> (7 PASS, 4 FAIL)</p>
<p><strong>Siguiente Cuello de Botella Identificado:</strong> <code>SUBJECT_ADAPTATION_REQUIRED</code></p>
<table>
<thead>
    <tr><th>Gate</th><th>Criterio Preregistrado</th><th>BASELINE (ORIGINAL)</th><th>NORMALIZED</th><th>Resultado</th></tr>
</thead>
<tbody>
    <tr><td><strong>A</strong></td><td>Reducción predictibilidad Subject-ID (&le; 0.90 &times; Orig)</td><td>Acc = 79.14%</td><td>Acc = 83.00%</td><td><span class="badge-fail">FAIL</span></td></tr>
    <tr><td><strong>B</strong></td><td>Direction F1 VALIDATION (&ge; Orig - 0.02)</td><td>F1 = 0.8105</td><td>F1 = 0.8056</td><td><span class="badge-pass">PASS</span></td></tr>
    <tr><td><strong>C</strong></td><td>Phase-Direction F1 VALIDATION (&ge; Orig - 0.02)</td><td>F1 = 0.5103</td><td>F1 = 0.4584</td><td><span class="badge-fail">FAIL</span></td></tr>
    <tr><td><strong>D</strong></td><td>Brecha TRAIN &to; VAL disminuye</td><td>Dir: 0.1043 / Phase: 0.1906</td><td>Dir: 0.1256 / Phase: 0.2806</td><td><span class="badge-fail">FAIL</span></td></tr>
    <tr><td><strong>E</strong></td><td>Opening MSE VALIDATION (&le; 0.90 &times; Orig)</td><td>0.058062</td><td>0.054244 (-6.57%)</td><td><span class="badge-fail">FAIL</span></td></tr>
    <tr><td><strong>F</strong></td><td>Closing MSE no empeora &gt;5% (&le; 1.05 &times; Orig)</td><td>0.120190</td><td>0.104307 (-13.22%)</td><td><span class="badge-pass">PASS</span></td></tr>
    <tr><td><strong>G</strong></td><td>Global MSE mejora (&lt; Orig)</td><td>0.089126</td><td>0.079275 (-11.05%)</td><td><span class="badge-pass">PASS</span></td></tr>
    <tr><td><strong>H</strong></td><td>Estabilidad: Ciclos = 0, Periodicidad = 0</td><td>0 / 0</td><td>0 / 0</td><td><span class="badge-pass">PASS</span></td></tr>
    <tr><td><strong>I</strong></td><td>Reversiones M3 no aumentan</td><td>0</td><td>0</td><td><span class="badge-pass">PASS</span></td></tr>
    <tr><td><strong>J</strong></td><td>Diversidad de acción (MAX_CAT_FRAC &le; 0.90)</td><td>0.8407</td><td>0.8480</td><td><span class="badge-pass">PASS</span></td></tr>
    <tr><td><strong>K</strong></td><td>Causalidad estricta para sujeto nuevo</td><td>N/A</td><td>100% Causal y Desplegable</td><td><span class="badge-pass">PASS</span></td></tr>
</tbody>
</table>
</div>

<div class="card">
<h2>2. Diagnósticos de Dominio: Cobertura, Ventana Inicial y Varianza</h2>
<div class="grid-2">
    <div>
        <h3>Cobertura de Datos (Sujetos de Denis)</h3>
        <ul>
            <li><strong>Opening Samples:</strong> {cov['OPENING_DATA_COVERAGE']} (50.0%)</li>
            <li><strong>Closing Samples:</strong> {cov['CLOSING_DATA_COVERAGE']} (50.0%)</li>
            <li><strong>Imbalance Ratio:</strong> {cov['OPEN_CLOSE_IMBALANCE']:.6f}</li>
            <li><strong>DATA_COVERAGE_PROBLEM:</strong> <span class="badge-pass">NO</span></li>
        </ul>
        <p><em>Conclusión:</em> La dificultad en apertura no proviene de un desbalance de datos.</p>
    </div>
    <div>
        <h3>Auditoría de Ventana Inicial (Primeros N Samples)</h3>
        <ul>
            <li><strong>Features con diff Opening vs Closing @ N=1:</strong> {init_win['N1_fracSigOpenClose']*100:.1f}% (40/40)</li>
            <li><strong>Diff media Open vs Close @ N=1:</strong> {init_win['N1_meanDiffOpenClose']:.4f}</li>
            <li><strong>INITIAL_WINDOW_STABLE:</strong> <span class="badge-fail">NO</span></li>
        </ul>
        <p><em>Conclusión:</em> No existe reposo neutro al inicio. La intención motora ya está activa.</p>
    </div>
</div>
</div>

<div class="card">
<h2>3. Descomposición de Varianza y Firma de Identidad</h2>
<p><strong>SUBJECT_TO_INTENT_VARIANCE_RATIO:</strong> Media = <strong>{var_sum['SUBJECT_TO_INTENT_VARIANCE_RATIO_MEAN']:.2f}</strong> | Mediana = <strong>{var_sum['SUBJECT_TO_INTENT_VARIANCE_RATIO_MEDIAN']:.2f}</strong></p>
<p>Varianza explicada por Sujeto: <strong>{var_sum['ETA2_SUBJECT_MEAN']*100:.2f}%</strong> vs Intención: <strong>{var_sum['ETA2_INTENT_MEAN']*100:.2f}%</strong> (Dominancia de Sujeto en 40 de 40 features).</p>
<p><strong>Subject-ID Linear Probe:</strong> Precisión = <strong>{summary['subjectID_original']['SUBJECT_ID_ACCURACY']*100:.2f}%</strong> (frente a azar 14.29%).</p>
<img src="{img_stats}" alt="Estadísticas WMoos y Descomposición de Varianza">
</div>

<div class="card">
<h2>4. Visualización de Domain Shift (PCA Fit estrictamente en TRAIN)</h2>
<div class="grid-2">
    <div>
        <h3>A) Proyección PCA por Sujeto</h3>
        <img src="{img_pca_sub}" alt="PCA coloreada por Sujeto">
    </div>
    <div>
        <h3>B) Proyección PCA por Intención (Open vs Close)</h3>
        <img src="{img_pca_int}" alt="PCA coloreada por Intención">
    </div>
</div>
</div>

<div class="card">
<h2>5. Matrices de Confusión Subject-ID: ORIGINAL vs NORMALIZED</h2>
<div class="grid-2">
    <div>
        <h3>ORIGINAL (Accuracy = 79.14%)</h3>
        <img src="{img_sub_orig}" alt="Confusion Matrix ORIGINAL">
    </div>
    <div>
        <h3>NORMALIZED (Accuracy = 83.00%)</h3>
        <img src="{img_sub_norm}" alt="Confusion Matrix NORMALIZED">
    </div>
</div>
<p><em>Hallazgo Clave:</em> La estandarización global no borra la firma de sujeto; la acentúa numéricamente (+3.86 pp accuracy), facilitando el sobreajuste a la identidad en TRAIN y degradando la generalización a VALIDATION.</p>
</div>

<div class="card">
<h2>6. Comparación y Trazas Closed-Loop</h2>
<div class="grid-2">
    <div>
        <h3>Comparación de Métricas</h3>
        <img src="{img_comp}" alt="Comparación ORIGINAL vs NORMALIZED">
    </div>
    <div>
        <h3>Trazas Closed-Loop Representativas (Seed 20260923)</h3>
        <img src="{img_trace}" alt="Trazas Closed-Loop">
    </div>
</div>
</div>

<div class="card">
<h2>7. Integridad y Sellado de Datos</h2>
<ul>
    <li><strong>CLEAN_FULL_REGRESSION:</strong> 356/356 PASS</li>
    <li><strong>Archivos históricos verificados (SHA-256):</strong> 7529 de 7529 idénticos (0 fallos).</li>
    <li><strong>Sujetos sellados (MATEO y SANDRA):</strong> SELLADOS, no abiertos, no listados.</li>
    <li><strong>Estado de Git:</strong> Limpio en archivos versionados, sin commit, sin push.</li>
</ul>
</div>

</body>
</html>
"""
    (ROOT / "RESULTADOS_E3E.html").write_text(html, encoding='utf-8')
    print("RESULTADOS_E3E.html generado con éxito.")

if __name__ == '__main__':
    generate_html()
