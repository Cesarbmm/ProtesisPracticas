"""Congela historial y seleccion diagnostica E3B antes de medir E3C."""
import csv, hashlib, json, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
PR=ROOT/'analysis/paired_reference'
OUT=PR/'e3c_results'
RUN=ROOT/'results/e3b_long/run_20260909_002700_470_a733a786'
def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(4*1024*1024),b''): h.update(b)
    return h.hexdigest()
def rows(p):
    with p.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def table(p,r):
    with p.open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(r[0]));w.writeheader();w.writerows(r)
if __name__=='__main__':
    OUT.mkdir(exist_ok=True)
    if sys.argv[1]=='before':
        assert not (OUT/'historical_hashes_before.csv').exists()
        protected={}
        for file in ['historical_hashes_before.csv','implementation_hashes.csv']:
            for r in rows(PR/'e3b_preparation'/file):
                p=(ROOT/r['path']).resolve();assert sha(p)==r['sha256'];protected[p]=r['sha256']
        for p in RUN.rglob('*'):
            if p.is_file():protected[p]=sha(p)
        for p in (PR/'e3b_run_audit').rglob('*'):
            if p.is_file():protected[p]=sha(p)
        p=ROOT.parent/'docs/paired_reference/PREREGISTRO_E3C.md';protected[p]=sha(p)
        (OUT/'exportE3AXViewerTrace_before.m.txt').write_bytes((ROOT/'exportE3AXViewerTrace.m').read_bytes())
        table(OUT/'historical_hashes_before.csv',[{'path':str(p),'sha256':h} for p,h in sorted(protected.items())])
        E=rows(RUN/'evaluation/best_checkpoint/metrics/episode_metrics.csv')
        TD=rows(ROOT/'results/e3ax_long/run_20260908_141321_916_6ebf347b/evaluation/best_checkpoint/metrics/episode_metrics.csv')
        key=lambda r:(r['subject'],int(r['repetition']),int(r['side']))
        E=[r for r in E if r['subject'] in ['JOE','JONATHAN','KHAROL']]
        opening=[r for r in E if r['side']=='2'];closing=[r for r in E if r['side']=='1'];chosen={}
        def choose(r,reason):
            k=key(r)
            if k in chosen:chosen[k]['reason']+='; '+reason
            else:chosen[k]={'subject':k[0],'row':k[1],'side':k[2],'reason':reason,'e3bMSE':r['trackingMSE'],'e3bFlat':r['flat_response']}
        choose(sorted(opening,key=lambda r:(-float(r['trackingMSE']),key(r)))[0],'peor MSE apertura')
        choose(sorted(opening,key=lambda r:(-float(r['flat_response']),-float(r['trackingMSE']),key(r)))[0],'maxima flat apertura')
        median=lambda seq:sorted(seq,key=lambda r:(float(r['trackingMSE']),key(r)))[(len(seq)-1)//2]
        choose(median(opening),'mediana inferior apertura VALIDATION')
        td={key(r):float(r['trackingMSE']) for r in TD}
        choose(sorted(closing,key=lambda r:(-(td[key(r)]-float(r['trackingMSE'])),key(r)))[0],'mayor mejora cierre frente TD3')
        for s in ['JOE','JONATHAN','KHAROL']:choose(median([r for r in opening if r['subject']==s]),'mediana apertura '+s)
        table(OUT/'diagnostic_selection.csv',list(chosen.values()))
        print(json.dumps(list(chosen.values()),indent=2))
    failures=[];count=0
    for r in rows(OUT/'historical_hashes_before.csv'):
        p=Path(r['path']);count+=1
        if sys.argv[1]!='before' and p==ROOT/'exportE3AXViewerTrace.m':continue
        if not p.is_file() or sha(p)!=r['sha256']:failures.append(str(p))
    result={'files':count,'failures':failures,'pass':not failures,'allowedChange':'exportE3AXViewerTrace.m ONLY; diff must be reviewed'}
    (OUT/('integrity_'+sys.argv[1]+'.json')).write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result));assert not failures
