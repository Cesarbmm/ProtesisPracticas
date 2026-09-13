"""Cierre E3C: verifica entregables, preserva historia, publica informe local."""
import csv,difflib,hashlib,html,json,math,struct,zlib
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlparse,unquote
from e3cAnalyze import ROOT,OUT,SEEDS,read,write,avg,select
def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda:f.read(4*1024*1024),b''):h.update(b)
    return h.hexdigest()
def png_check(file):
    data=file.read_bytes();assert data[:8]==b'\x89PNG\r\n\x1a\n';i=8;complete=False
    while i<len(data):
        n=struct.unpack('>I',data[i:i+4])[0];kind=data[i+4:i+8];payload=data[i+8:i+8+n];crc=struct.unpack('>I',data[i+8+n:i+12+n])[0]
        assert zlib.crc32(kind+payload)&0xffffffff==crc
        if kind==b'IHDR':assert all(struct.unpack('>II',payload[:8]))
        if kind==b'IEND':complete=True
        i+=12+n
    assert complete and i==len(data)
def table_html(headers,rows):
    return '<table><thead><tr>'+''.join('<th>'+html.escape(str(h))+'</th>' for h in headers)+'</tr></thead><tbody>'+''.join('<tr>'+''.join('<td>'+str(c)+'</td>' for c in r)+'</tr>' for r in rows)+'</tbody></table>'
def table_md(headers,rows):
    return '\n'.join(['| '+' | '.join(headers)+' |','|'+'---|'*len(headers)]+['| '+' | '.join(str(c) for c in r)+' |' for r in rows])
def main():
    s=json.loads((OUT/'scientific_summary.json').read_text());assert not s['TEMPORAL_INFORMATION_SUPPORTED']
    previous=json.loads((OUT/'regression_tests/summary.json').read_text());assert previous['passed']==294 and previous['failed']==0
    tests=read(OUT/'testsCore_results.csv')+read(OUT/'testsArtifacts_results.csv');assert len(tests)==32 and len({r['Name'] for r in tests})==32
    assert all(r['Passed']=='1' and r['Failed']=='0' and r['Incomplete']=='0' for r in tests);write('all_e3c_test_results.csv',tests)
    h=json.loads((OUT/'integrity_after.json').read_text());assert h['pass']
    selection=read(OUT/'evaluation_selection.csv');diagnostics=read(OUT/'diagnostic_selection.csv');inventory=[];model_hashes=[]
    for seed in SEEDS:
        for kind in ['FF','GRU']:
            folder=OUT/f'{kind}_{seed}';model=folder/'checkpoints/ProbeEpoch040.mat';model_hashes.append(dict(kind=kind,seed=seed,path=str(model),sha256=sha(model)))
            assert len(list((folder/'figures').rglob('*.png')))==200 and len(list((folder/'figures').rglob('*.fig')))==200
            for ep in selection:
                direction='closing' if ep['side']=='1' else 'opening';stem=f"{ep['subject']}_row{int(ep['row']):04d}_{direction}"
                png=folder/'figures'/ep['split']/(stem+'.png');fig=png.with_suffix('.fig');png_check(png);assert fig.stat().st_size>1000
                inventory.append(dict(kind=kind,seed=seed,subject=ep['subject'],row=ep['row'],direction=direction,split=ep['split'],png=str(png.relative_to(OUT)).replace('\\','/'),fig=str(fig.relative_to(OUT)).replace('\\','/')))
    write('figure_inventory.csv',inventory);write('model_hashes.csv',model_hashes)
    assert len(list((OUT/'annotated').rglob('*.png')))==12 and len(list((OUT/'annotated').rglob('*.fig')))==12
    for p in (OUT/'annotated').rglob('*.png'):png_check(p)
    assert len(list((OUT/'viewer').rglob('viewer_trace.mat')))==18
    before=(OUT/'exportE3AXViewerTrace_before.m.txt').read_text(encoding='utf-8');after=(ROOT/'exportE3AXViewerTrace.m').read_text(encoding='utf-8')
    diff=''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='exportE3AXViewerTrace antes E3C',tofile='exportE3AXViewerTrace E3C'))
    (OUT/'authorized_exporter.diff').write_text(diff,encoding='utf-8')
    sources=list((ROOT/'analysis/paired_reference/e3c').glob('*.m'))+list((ROOT/'analysis/paired_reference/e3c').glob('*.py'))+[ROOT/'tests/paired_reference/testE3CTemporal.m',ROOT/'exportE3AXViewerTrace.m']
    write('implementation_hashes.csv',[dict(path=str(p),sha256=sha(p)) for p in sources])
    s.update(ANNOTATED_TEST_FIGURES_CREATED=12,COMPACT_TEST_FIGURES_CREATED=1200,ANNOTATED_FORMATS=['PNG','FIG','CSV','MAT'],COMPACT_FORMATS=['PNG','FIG'],VIEWER_TRACES_READY=18,PREVIOUS_TESTS='294/294',NEW_E3C_TESTS='32/32',TOTAL_TESTS='326/326',HISTORICAL_HASHES_INTACT=True,AUTHORIZED_HISTORICAL_CHANGE='exportE3AXViewerTrace only',E3D_PREPARATION=False)
    (OUT/'summary.json').write_text(json.dumps(s,indent=2),encoding='utf-8')
    I=read(OUT/'imitation_all.csv');C=read(OUT/'closed_loop_all.csv');P=read(OUT/'phase_all.csv');PWM=read(OUT/'pwm_distributions.csv')
    imrows=[]
    for split in ['TRAIN','VALIDATION']:
        for kind,control in [('FF','ordered'),('GRU','ordered'),('GRU','shuffled')]:
            vals=[r for r in I if r['kind']==kind and r['control']==control and r['split']==split and r['dimension']=='all' and r['motor']=='0']
            imrows.append([split,kind+(' shuffled' if control=='shuffled' else ''),*[f"{avg(r[k] for r in vals):.6f}" for k in ['macroF1','NLL','accuracy','top2','jointExact','jointNLL']]])
    clrows=[]
    for split in ['TRAIN','VALIDATION']:
        for direction in ['ALL','1','2']:
            for kind in ['FF','GRU']:
                dim='all' if direction=='ALL' else 'direction';vals=[r for r in C if r['kind']==kind and r['split']==split and r['dimension']==dim and r['value']==direction]
                clrows.append([split,{'ALL':'Global','1':'Cierre','2':'Apertura'}[direction],kind,*[f"{avg(r[k] for r in vals):.6f}" for k in ['trackingMSE','rewardMean','MAE','correlation','flat_response','action_no_motion']]])
    prows=[]
    for task in ['direction','phase','phase_direction']:
        for kind in ['FF','GRU']:
            vals=[r for r in P if r['kind']==kind and r['split']=='VALIDATION' and r['task']==task]
            prows.append([task,kind,*[f"{avg(r[k] for r in vals):.6f}" for k in ['accuracy','macroF1','NLL']]])
    gate_rows=[[k,'PASS' if v else 'FAIL'] for k,v in s['gates'].items()]
    bootstrap_rows=[]
    for group,metrics in s['bootstrap'].items():
        for metric,v in metrics.items():bootstrap_rows.append([group,metric,f"{v['meanDifference']:.6f}",f"[{v['CI95'][0]:.6f}, {v['CI95'][1]:.6f}]",v['episodes']])
    zero=[]
    for kind in ['FF','GRU']:
        vals=[r for r in PWM if r['kind']==kind and r['split']=='VALIDATION' and r['dimension']=='direction' and r['value']=='2' and r['category']=='1']
        zero.append((kind,avg(r['fraction'] for r in vals)))
    corpus=read(OUT/'sample_inventory.csv');order_fraction=sum(int(r['length'])>=3 for r in corpus if r['split']=='VALIDATION')/sum(r['split']=='VALIDATION' for r in corpus)
    intro=("E3C_RESULT = TEMPORAL_INFORMATION_NOT_DEMONSTRATED. No se prepara E3D. Se conservaron la receta y los gates antes de medir: "
           "tres seeds supervisadas (20260912/13/14), 40 epocas, Adam LR0.001, batch64, L8 real. No hubo entrenamiento RL. "
           "Los 2.076 estados TRAIN y 862 VALIDATION proceden de las200 demostraciones Oracle H5, reconstruidas con igualdad exacta de planta y estado previo causal. "
           "Cada una de las seis politicas congeladas se evaluo en140TRAIN+60VALIDATION con sus propias acciones y runtime EMG-only.")
    findings=(f"GRU mejora apertura frente a FF: MSE {s['GRU_OPENING_MSE']:.6f} vs {s['FF_OPENING_MSE']:.6f} "
              f"({100*(s['GRU_OPENING_MSE']/s['FF_OPENING_MSE']-1):+.2f}%), flat_response {100*s['GRU_OPENING_FLAT_RESPONSE']:.2f}% vs {100*s['FF_OPENING_FLAT_RESPONSE']:.2f}%. "
              f"Sin embargo, Oracle-action macro-F1 gana solo {s['MACRO_F1_GAIN_PP']:.3f} pp (se exigian3), y NLL empeora {s['NLL_CHANGE_PCT']:.2f}% "
              "en lugar de mejorar5%. NLL empeora en las tres seeds. Los gatesA/B, orden y consistencia entre seeds fallan. No ajustar umbrales ni receta.")
    temporal=(f"Desordenar el pasado conservando el estado actual reduce F1 {100*(s['GRU_ORACLE_MACRO_F1']-s['SHUFFLED_HISTORY_MACRO_F1']):.3f}pp "
              f"y aumenta NLL {100*(s['SHUFFLED_HISTORY_NLL']/s['GRU_ORACLE_NLL']-1):.2f}% frente a GRU ordenado. "
              f"Se altera el orden en {100*order_fraction:.2f}% de ventanas VALIDATION; prefijos1/2 no tienen pasado permutable. "
              "Existe sensibilidad al orden, pero la perdida F1 no alcanza1pp preregistrado. La perturbacion es fuera de distribucion y las arquitecturas "
              "no tienen igual numero de parametros; por tanto la diferencia GRU/FF no aisla exclusivamente memoria.")
    compare=("Frente a E3B BEST, GRU mejora apertura (MSE0.048368 vs0.056553; flat27.78% vs45.83%; accion activa sin movimiento42.95% vs87.50%), "
             "pero empeora cierre (0.091429 vs0.058324) y MSE global VALIDATION (0.069898 vs0.057439). "
             "Cero retrocesosM3, ciclos finales y periodicidades finales en cada seed GRU VALIDATION. "
             "La categoria mas frecuente por motor llega como maximo a72.39%, inferior al gate90%; no equivale a control suficiente. "
             "La comparacion favorable frente al FF debil no prueba superioridad global frente a la politica RL anterior.")
    caveats=(f"La politica FF emite PWM0 en {100*zero[0][1]:.2f}% de comandos de apertura VALIDATION, frente a {100*zero[1][1]:.2f}% GRU "
             "(media de motor y seed, ponderada por comandos dentro de motor). action_no_motion excluye acciones cero; su valor menor en FF "
             "no demuestra mas movimiento util. FF presenta colapso global de alguna cabeza en2/3seeds (maximos96.52%,90.26%,77.15%); "
             "GRU no lo presenta bajo el umbral90%. Esa debilidad del FF limita la interpretacion de la ventaja en lazo cerrado. "
             "El bootstrap es pareado por episodio, con semillas promediadas primero; no usa pasos como replicas "
             "independientes ni cambia gates. Episodios de un mismo sujeto pueden correlacionarse; no es un test final. "
             "La distribucion de entrada supervisada usa acciones previas del experto; la propia politica puede visitar otros estados. "
             "Oracle H5 conoce teacher futuro, por lo que parte de su accion puede no ser inferible causalmente. "
             "Las categorias poco frecuentes cuentan en macro-F1 de15clases (F1=0 con denominador0). "
             "Este resultado no demuestra ausencia universal de informacion temporal: se limita a L8, GRU64, esta receta/dataset y estas etiquetas.")
    causal=("Entrada al modelo: exclusivamente markov52 ANTES de la accion. Teacher/Oracle/reward/fase/indice de episodio no entran a la red. "
            "La ventana nunca cruza episodios y no incluye futuro. GRU se evalua desde hidden0 sobre la ultima ventana real de hasta8estados; "
            "no persiste memoria anterior a L8. El readout lineal secundario de fase/direccion se ajusto sobre latentes congelados, soloTRAIN, "
            "sin gradiente hacia la politica. No es decoder ni controlador nuevo. Teacher original solo sirve para etiquetas y metricas posteriores; "
            "reward, planta, Ts, PWM, WMoos y markov52 historicos no se modificaron.")
    integrity=("Pruebas:294/294 regresiones historicas reejecutadas y32/32 E3C:326/326. Se verificaron2179 entradas historicas; "
               "unica excepcion autorizada: exportE3AXViewerTrace reconoce/reset E3CProbeActor y etiqueta su procedencia, manteniendo formato/rutas previas. "
               "El diff esta guardado. No se reparo Git, no push ni cambio de rama. MATEO/SANDRA sellados; referencia fisica no validada, hardware no autorizado. "
               "Se comprobaron determinismo de los seis modelos, teacher contrafactual sin cambios de accion, ventanas causales, CSV/MAT anotados y viewer contra trazas.")
    sections=[('Imitacion Oracle: media de tres seeds',['Split','Modelo','Macro-F1','NLL/head','Accuracy/head','Top2/head','Exact4','NLL conjunta'],imrows),
              ('Lazo cerrado: media de tres seeds',['Split','Direccion','Modelo','MSE','Reward','MAE','Correlacion','Flat','Accion sin movimiento'],clrows),
              ('Gate congelado',['Criterio','Resultado'],gate_rows),('Bootstrap pareado GRU menos FF',['Grupo','Metrica','Diferencia','IC95%','Episodios'],bootstrap_rows),
              ('Diagnostico secundario de fase',['Target','Modelo','Accuracy','Macro-F1','NLL'],prows)]
    report='# Resultados E3C — auditoria temporal\n\n'+'\n\n'.join([intro,findings,temporal,compare,causal])+'\n\n'
    body='<h1>E3C: informacion temporal no demostrada segun el gate</h1>'+''.join('<p>'+html.escape(p)+'</p>' for p in [intro,findings,temporal,compare,causal])
    body+='<img src="e3c_summary.png" alt="Resumen E3C">'
    for title,headers,rows in sections:
        report+='## '+title+'\n\n'+table_md(headers,rows)+'\n\n';body+='<h2>'+title+'</h2>'+table_html(headers,rows)
    report+=caveats+'\n\n'+integrity+'\n\n';body+=''.join('<p>'+html.escape(p)+'</p>' for p in [caveats,integrity])
    report+='## Figuras y trazas\n\n1200 figuras compactas PNG+FIG (200por probe/seed),12comparaciones anotadas PNG+FIG+CSV+MAT y18viewer_trace.mat. '
    report+='Se conservan las400figuras BEST/LAST E3B originales. Primera seed para diagnosticos elegida antes de medir; ninguna seleccion por resultados E3C.\n\n'
    report+=f"[Informe navegable]({(OUT/'RESULTADOS_E3C.html').as_posix()})\n\n[Resumen JSON]({(OUT/'summary.json').as_posix()})\n\n"
    report+='Comandos desde matlab_code: addpath(\'analysis/paired_reference/e3c\'); runE3CTemporalAudit(\'testsCore\'); runE3CTemporalAudit(\'testsArtifacts\'); '
    report+='Los modelos existentes no se sobrescriben ni reentrenan; stages evaluate/figures permiten completar postprocesado. '
    report+='python analysis/paired_reference/e3c/e3cAnalyze.py reproduce estadisticas; e3cHistory.py after verifica integridad; e3cFinalize.py reconstruye este cierre.\n\n'
    report+='E3C_RESULT = TEMPORAL_INFORMATION_NOT_DEMONSTRATED\n\nE3D_PREPARATION = NO\n\nE3D_LONG_TRAINING_STARTED = NO\n\nPUSH = NO\n'
    (OUT/'RESULTADOS_E3C.md').write_text(report,encoding='utf-8');(ROOT.parent/'docs/paired_reference/RESULTADOS_E3C.md').write_text(report,encoding='utf-8')
    body+='<h2>Figuras anotadas: seleccion congelada</h2><p>Etiquetas = PWM/255. Las probabilidades y valores exactos estan en CSV/MAT.</p>'
    for comparison in ['FF_vs_GRU','E3B_vs_GRU']:
        body+='<h3>'+comparison+'</h3><div class="gallery">'
        for ep in diagnostics:
            direction='closing' if ep['side']=='1' else 'opening';stem=f"{ep['subject']}_row{int(ep['row']):04d}_{direction}";base=f'annotated/{comparison}/{stem}'
            body+=f'<article><a href="{base}.png"><img loading="lazy" src="{base}.png"></a><p>{stem} — {html.escape(ep["reason"])}</p><a href="{base}.fig">FIG</a> · <a href="{base}.csv">CSV</a> · <a href="{base}.mat">MAT</a></article>'
        body+='</div>'
    body+='<h2>1200 figuras compactas</h2><p>Filtrar por modelo, seed, sujeto, fila, TRAIN/VALIDATION o opening/closing.</p><input id="filter" placeholder="Ejemplo: GRU 20260912 JOE opening"><table id="episodes"><thead><tr><th>Modelo</th><th>Seed</th><th>Split</th><th>Sujeto</th><th>Fila</th><th>Direccion</th><th>Figura</th></tr></thead><tbody>'
    for r in inventory:
        body+='<tr>'+''.join('<td>'+str(r[k])+'</td>' for k in ['kind','seed','split','subject','row','direction'])+f'<td><a href="{r["png"]}">PNG</a> · <a href="{r["fig"]}">FIG</a></td></tr>'
    body+='</tbody></table><h2>Artefactos auditables</h2><ul>'
    for name in ['summary.json','by_seed.csv','imitation_all.csv','closed_loop_all.csv','phase_all.csv','pwm_distributions.csv','paired_episode_differences.csv','bootstrap_draws.csv','gates.csv','all_e3c_test_results.csv','historical_hashes_before.csv','authorized_exporter.diff','model_hashes.csv']:
        body+=f'<li><a href="{name}">{name}</a></li>'
    body+='</ul><h2>Viewer pasivo</h2><ul>'
    for p in sorted((OUT/'viewer').rglob('viewer_trace.mat')):
        rel=p.relative_to(OUT).as_posix();body+=f'<li><a href="{rel}">{html.escape(rel)}</a></li>'
    old=ROOT/'results/e3b_long/run_20260909_002700_470_a733a786/TEST_COMPORTAMENTAL.html'
    body+='</ul><p><a href="'+old.as_uri()+'">E3B BEST/LAST: informe y400figuras originales</a></p>'
    style='body{font:16px system-ui;max-width:1450px;margin:30px auto;padding:0 20px;color:#182b3d}p{line-height:1.6}table{width:100%;border-collapse:collapse;margin:20px 0}th,td{padding:7px;border-bottom:1px solid #ccd7df;text-align:left}th{background:#eaf0f5}img{max-width:100%}.gallery{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:22px}input{font:inherit;padding:12px;width:90%}article{border:1px solid #d2d9e2;padding:10px}'
    script="document.getElementById('filter').addEventListener('input',function(){const terms=this.value.toLowerCase().split(/\\s+/).filter(Boolean);document.querySelectorAll('#episodes tbody tr').forEach(r=>r.hidden=!terms.every(t=>r.textContent.toLowerCase().includes(t)));});"
    (OUT/'RESULTADOS_E3C.html').write_text('<!doctype html><html lang="es"><meta charset="utf-8"><title>Resultados E3C</title><style>'+style+'</style>'+body+'<script>'+script+'</script></html>',encoding='utf-8')
    links=[]
    class LinkParser(HTMLParser):
        def handle_starttag(self,tag,attrs):
            links.extend(v for k,v in attrs if k in ('href','src'))
    page=(OUT/'RESULTADOS_E3C.html').read_text(encoding='utf-8');LinkParser().feed(page)
    for link in links:
        u=urlparse(link)
        if u.scheme in ('http','https'):continue
        file=Path(unquote(u.path.lstrip('/'))) if u.scheme=='file' else OUT/unquote(u.path)
        assert file.exists(),('Enlace roto',link)
    assert '.split(/\\s+/)' in page
    (OUT/'html_validation.json').write_text(json.dumps({'linksChecked':len(links),'brokenLinks':0,'searchFilterConfigured':True},indent=2),encoding='utf-8')
    print(json.dumps({k:s[k] for k in ['E3C_RESULT','ANNOTATED_TEST_FIGURES_CREATED','COMPACT_TEST_FIGURES_CREATED','VIEWER_TRACES_READY','TOTAL_TESTS','E3D_PREPARATION']},indent=2))
if __name__=='__main__':main()
