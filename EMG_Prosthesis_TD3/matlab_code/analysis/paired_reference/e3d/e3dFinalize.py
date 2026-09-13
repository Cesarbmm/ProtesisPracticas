"""Informe local E3D y verificacion de entregables; nunca entrena."""
import json,html,sys
from pathlib import Path
from e3dAnalyze import ROOT,OUT,SEEDS,KINDS,read,write,avg,select
from e3dHistory import sha
sys.path.insert(0,str(ROOT/'analysis/paired_reference/e3c'))
from e3cFinalize import png_check,table_html,table_md
def main():
    s=json.loads((OUT/'scientific_summary.json').read_text());A=s['means']['BASELINE'];B=s['means']['TEMPORAL_EMG']
    previous=json.loads((OUT/'regression_tests/summary.json').read_text());assert previous['passed']==326 and previous['failed']==0
    tests=read(OUT/'testsCore_results.csv')+read(OUT/'testsArtifacts_results.csv')
    assert len({r['Name'] for r in tests})==len(tests) and all(r['Passed']=='1' and r['Failed']=='0' and r['Incomplete']=='0' for r in tests)
    write('all_e3d_test_results.csv',tests);integrity=json.loads((OUT/'integrity_after.json').read_text());assert integrity['pass']
    inventory=[];models=[];selection=read(OUT/'evaluation_selection.csv')
    for seed in SEEDS:
        for kind in KINDS:
            folder=OUT/f'{kind}_{seed}';model=folder/'checkpoints/ProbeEpoch040.mat';models.append(dict(kind=kind,seed=seed,path=str(model),sha256=sha(model)))
            assert len(list((folder/'figures').rglob('*.png')))==200 and len(list((folder/'figures').rglob('*.fig')))==200
            for ep in selection:
                direction='closing' if ep['side']=='1' else 'opening';stem=f"{ep['subject']}_row{int(ep['row']):04d}_{direction}"
                png=folder/'figures'/ep['split']/(stem+'.png');fig=png.with_suffix('.fig');png_check(png);assert fig.stat().st_size>1000
                inventory.append(dict(kind=kind,seed=seed,subject=ep['subject'],row=ep['row'],direction=direction,split=ep['split'],png=png.relative_to(OUT).as_posix(),fig=fig.relative_to(OUT).as_posix()))
    write('figure_inventory.csv',inventory);write('model_hashes.csv',models)
    annotations=list((OUT/'annotated').rglob('*.png'));viewer=list((OUT/'viewer').rglob('viewer_trace.mat'))
    assert len(annotations)==12 and len(viewer)==18
    for p in annotations:
        png_check(p)
        for suffix in ['.fig','.csv','.mat']:assert p.with_suffix(suffix).is_file()
    sources=list((ROOT/'analysis/paired_reference/e3d').glob('*.m'))+list((ROOT/'analysis/paired_reference/e3d').glob('*.py'))+[ROOT/'tests/paired_reference/testE3DTemporalIntent.m',ROOT/'exportE3AXViewerTrace.m']
    write('implementation_hashes.csv',[dict(path=str(p),sha256=sha(p)) for p in sources])
    s.update(PREVIOUS_TESTS='326/326',NEW_E3D_TESTS=f'{len(tests)}/{len(tests)}',TOTAL_TESTS=f'{326+len(tests)}/{326+len(tests)}',
        ANNOTATED_FIGURES=12,COMPACT_FIGURES=1200,VIEWER_TRACES_READY=18,HISTORICAL_HASHES_INTACT=True,HISTORICAL_ENTRIES=integrity['files'])
    (OUT/'summary.json').write_text(json.dumps(s,indent=2),encoding='utf-8')
    header=['Metrica VALIDATION','BASELINE','TEMPORAL_EMG','Diferencia temporal - baseline']
    core=[[label,f'{A[key]:.6f}',f'{B[key]:.6f}',f'{B[key]-A[key]:+.6f}'] for key,label in [
        ('directionF1','Direction macro-F1'),('phaseDirectionF1','Phase-direction macro-F1'),('oracleF1','Oracle-action macro-F1 (auxiliar)'),
        ('oracleNLL','Oracle-action NLL (auxiliar)'),('MSE','MSE global'),('openingMSE','MSE apertura'),('closingMSE','MSE cierre'),
        ('reward','Reward'),('flat','Flat response'),('PWM0Fraction','PWM0'),('actionNoMotion','Action no motion'),('maxCategoryFraction','Max category fraction')]]
    gateRows=[[k,'PASS' if v else 'FAIL'] for k,v in s['gates'].items()]
    seedsRows=[]
    for kind in KINDS:
        for r in s['bySeed'][kind]:
            seedsRows.append([kind,r['seed'],*[f'{r[k]:.6f}' for k in ['directionF1','phaseDirectionF1','openingMSE','closingMSE','MSE','maxCategoryFraction']],r['cycles'],r['periodic'],r['m3Reversals']])
    sh=read(OUT/'intent_all.csv');subjectRows=[]
    for split in ['TRAIN','VALIDATION']:
        subjects=['ALL']+(['BLANCA','CECILIA','DENIS','EMILIA','GABI','GABRIEL','IVANNA'] if split=='TRAIN' else ['JOE','JONATHAN','KHAROL'])
        for subject in subjects:
            for kind,control in [('BASELINE','ordered'),('TEMPORAL_EMG','ordered'),('TEMPORAL_EMG','shuffled')]:
                row=[split,subject,kind,control]
                for task in ['direction','phase_direction']:
                    values=[r for r in sh if r['split']==split and r['subject']==subject and r['kind']==kind and r['control']==control and r['task']==task]
                    assert len(values)==3;row+=[f"{avg(r['macroF1'] for r in values):.6f}",f"{avg(r['NLL'] for r in values):.6f}"]
                subjectRows.append(row)
    closed=read(OUT/'closed_loop_all.csv');closedRows=[]
    for split in ['TRAIN','VALIDATION']:
        for dim,val,label in [('all','ALL','Global'),('direction','1','Cierre'),('direction','2','Apertura')]:
            for kind in KINDS:
                rows=[r for r in closed if r['kind']==kind and r['split']==split and r['dimension']==dim and r['value']==val]
                assert len(rows)==3
                closedRows.append([split,label,kind,*[f'{avg(r[k] for r in rows):.6f}' for k in ['trackingMSE','rewardMean','MAE','correlation','flat_response','action_no_motion','PWM0Fraction']],
                    sum(int(r['cycles']) for r in rows),sum(int(r['periodic']) for r in rows),sum(int(r['m3Reversals']) for r in rows)])
    failed=[k for k,v in s['gates'].items() if not v]
    conclusion=('Todos los gates preregistrados pasan. Corresponde preparar E3E, sin ejecutarlo.' if not failed else
        'No se demuestra el contexto temporal EMG con el criterio solicitado. Fallan: '+', '.join(failed)+'. Se cierra la via recurrente con Denis/WMoos actuales. No se prepara E3E ni se prueban otros L o arquitecturas.')
    description=f'''E3D_RESULT = {s['E3D_RESULT']}

{conclusion}

Se entrenaron seis probes supervisados (tres seeds pareadas, 40 epocas cada uno), no RL. Se reutilizaron 2076 muestras TRAIN y 862 VALIDATION de las mismas 200 demostraciones Oracle de E3C. Despues se ejecutaron 1200 episodios con acciones propias en GloveFreePolicyRuntime; el teacher se adjunto posteriormente para calcular metricas en el horizonte comun. La terminacion del runtime sigue siendo EMG-only.

La comparacion separa memoria EMG40 de mecanica actual12. BASELINE usa FC64/ReLU sobre EMG actual; TEMPORAL_EMG usa GRU64 sobre los ocho EMG causales mas recientes. Ambas concatenan mecanica actual antes de FC64/ReLU y cuatro heads15. Heads adicionales direction2 y phase_direction6 supervisan intencion; son salidas y nunca inputs de la accion. Perdida identica CE direccion + CE fase-direccion + media CE de cuatro acciones. La etiqueta Oracle sigue siendo auxiliar.

Direction gain = {s['DIRECTION_GAIN_PP']:+.6f} pp; phase-direction gain = {s['PHASE_DIRECTION_GAIN_PP']:+.6f} pp. Phase-direction ordenado = {B['phaseDirectionF1']:.6f}; pasado EMG permutado = {s['shuffled']['phaseDirectionF1']:.6f}; ganancia de orden = {s['ORDER_GAIN_PP']:+.6f} pp. El shuffle conserva EMG actual y mecanica actual intactos; prefijos de uno/dos pasos no permiten cambiar el orden del pasado.

E3C permanece TEMPORAL_INFORMATION_NOT_DEMONSTRATED. Sus resultados y gates no se cambian. E3D no demuestra que un agente de RL recurrente aprenderia lo mismo: los probes reciben supervision directa de intencion y de acciones privilegiadas. El conjunto de estados de entrenamiento proviene del experto, mientras la evaluacion cerrada utiliza acciones propias. Los targets de fase usan la duracion teacher completa solo como etiqueta offline. Estas limitaciones impiden extrapolar a hardware o a reconstruccion continua individual del glove.

E3B BEST global MSE = {s['E3B_BEST']['MSE']:.12f}. Gaps TEMPORAL_EMG - E3B: global {s['GLOBAL_GAP_TO_E3B']:+.12f}, apertura {s['OPENING_GAP_TO_E3B']:+.12f}, cierre {s['CLOSING_GAP_TO_E3B']:+.12f}. No son gates ni justifican escalar PPO.

Las metricas continuas son medias de los tres seeds, con agregacion macro historica por sujeto/direccion. Los conteos se muestran por seed y sumados; no son nuevas personas ni episodios independientes. MAX_CATEGORY_FRACTION se calcula sobre transiciones, por motor; el gate usa la media de los maximos por seed. El CSV pwm_distributions conserva todos los motores, categorias, sujetos y direcciones. Flat_response y action_no_motion mantienen definiciones historicas; PWM0 se informa por separado para evitar confundir inmovilidad con control.

Evidencia: 1200 compactas PNG+FIG, doce annotated PNG+FIG+CSV+MAT y dieciocho viewer traces MAT. Las annotated y viewer usan el primer seed fijado, no el mejor, y los seis episodios seleccionados antes por E3B. CSV/MAT distinguen PWM/255 de probabilidad. El exportador mantiene el formato y solo reconoce la clase E3D adicional; no importa sandbox ni recalcula otra planta.

Regresiones {s['PREVIOUS_TESTS']}; nuevos tests {s['NEW_E3D_TESTS']}; total {s['TOTAL_TESTS']}. Integridad de {integrity['files']} entradas historicas comprobada; unica extension autorizada: reconocimiento del actor E3D en exportE3AXViewerTrace (diff adjunto). No Git repair, cambio de rama, commit ni push. MATEO/SANDRA sellados; referencia no validada; hardware no autorizado.
'''
    sections=[
        ('Resumen VALIDATION',header,core),
        ('Gates congelados',['Gate','Resultado'],gateRows),
        ('Variabilidad por seed',['Modelo','Seed','Direction F1','Phase-dir F1','Opening MSE','Closing MSE','Global MSE','Max category','Ciclos','Periodos','M3'],seedsRows),
        ('Closed-loop',['Split','Direccion','Modelo','MSE','Reward','MAE','Correlacion','Flat','No motion','PWM0','Ciclos total3','Periodos total3','M3 total3'],closedRows),
        ('Intencion por sujeto',['Split','Sujeto','Modelo','Orden','Direction F1','Direction NLL','Phase-dir F1','Phase-dir NLL'],subjectRows)]
    md='# E3D — Contexto temporal de intencion EMG\n\n'+description+'\n'
    for title,h,rows in sections:md+='\n## '+title+'\n\n'+table_md(h,rows)+'\n'
    md+='\n## Reproduccion\n\nDesde matlab_code, en MATLAB: addpath(\'analysis/paired_reference/e3d\'); runE3DTemporalIntentAudit("preflight"); runE3DTemporalIntentAudit("train"); runE3DTemporalIntentAudit("evaluate"); runE3DTemporalIntentAudit("figures");\n\nLos modelos existentes se reutilizan, no se sobrescriben. Analisis: python analysis/paired_reference/e3d/e3dAnalyze.py. Regresiones: e3dRunRegressionTests. Tests nuevos: runE3DTemporalIntentAudit("tests"). Exportaciones y enlaces en RESULTADOS_E3D.html. Nunca invocar train RL.\n'
    (OUT/'RESULTADOS_E3D.md').write_text(md,encoding='utf-8');(ROOT.parent/'docs/paired_reference/RESULTADOS_E3D.md').write_text(md,encoding='utf-8')
    parts=['<!doctype html><html lang="es"><meta charset="utf-8"><title>E3D — Resultados y figuras</title><style>body{font:16px system-ui;margin:2rem;max-width:1500px;color:#142335}table{border-collapse:collapse;font-size:13px;width:100%}td,th{border:1px solid #c7d3df;padding:7px;text-align:left}th{background:#e6edf6;position:sticky;top:0}tr:nth-child(even){background:#f4f7fa}img{max-width:100%}input{padding:12px;width:75%;margin:16px 0}pre{white-space:pre-wrap}a{color:#064da5}.scroll{overflow:auto}</style><h1>E3D: '+html.escape(s['E3D_RESULT'])+'</h1><pre>'+html.escape(description)+'</pre><img src="e3d_summary.png" alt="Resumen E3D">']
    for title,h,rows in sections:parts+=['<h2>'+title+'</h2><div class="scroll">'+table_html(h,rows)+'</div>']
    parts+=['<h2>Figuras diagnosticas: seleccion congelada</h2>']
    for p in sorted(annotations):
        rel=p.relative_to(OUT).as_posix();parts+=['<p>'+html.escape(rel)+'</p><a href="'+rel+'"><img loading="lazy" src="'+rel+'"></a><p>']
        for ext in ['.fig','.csv','.mat']:parts+=['<a href="'+p.with_suffix(ext).relative_to(OUT).as_posix()+'">'+ext[1:].upper()+'</a> ']
        parts+=['</p>']
    parts+=['<h2>1200 figuras compactas</h2><p>Una figura con cuatro motores por episodio, modelo y seed. Filtrar por sujeto, split, modelo o seed.</p><input id="filter" placeholder="Ejemplo: TEMPORAL_EMG JOE opening"><div id="gallery">']
    rows=[[r[k] for k in ['kind','seed','split','subject','row','direction']]+[f'<a href="{r["png"]}">PNG</a>',f'<a href="{r["fig"]}">FIG</a>'] for r in inventory]
    parts +=[table_html(['Modelo','Seed','Split','Sujeto','Fila','Direccion','Imagen','MATLAB'],rows),'</div><h2>Viewer traces</h2><ul>']
    for p in sorted(viewer):rel=p.relative_to(OUT).as_posix();parts+=['<li><a href="'+rel+'">'+html.escape(rel)+'</a></li>']
    parts+=['</ul><h2>Datos y tests</h2><ul>']
    for name in ['summary.json','scientific_summary.json','gates.csv','by_seed.csv','shuffled_by_seed.csv','intent_all.csv','imitation_all.csv','closed_loop_all.csv','pwm_distributions.csv','figure_inventory.csv','model_hashes.csv','all_e3d_test_results.csv','regression_tests/test_results.csv','integrity_after.json','authorized_exporter.diff','RESULTADOS_E3D.md']:
        parts+=['<li><a href="'+name+'">'+name+'</a></li>']
    parts+=['</ul><script>document.getElementById("filter").addEventListener("input",function(){const q=this.value.toLowerCase().split(/\\s+/);document.querySelectorAll("#gallery tbody tr").forEach(r=>r.hidden=!q.every(s=>r.innerText.toLowerCase().includes(s)));});</script></html>']
    (OUT/'RESULTADOS_E3D.html').write_text(''.join(parts),encoding='utf-8')
    print(json.dumps({k:s[k] for k in ['E3D_RESULT','PREVIOUS_TESTS','NEW_E3D_TESTS','TOTAL_TESTS','ANNOTATED_FIGURES','COMPACT_FIGURES','VIEWER_TRACES_READY']},indent=2))
if __name__=='__main__':main()
