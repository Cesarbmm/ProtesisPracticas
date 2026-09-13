"""Integridad E3D: conservar anclas previas, no sustituir hashes discrepantes."""
import csv,hashlib,json,sys,shutil,difflib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];PR=ROOT/'analysis/paired_reference';OUT=PR/'e3d_results'
def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(4*1024*1024),b''):h.update(b)
    return h.hexdigest()
def rows(p):
    with p.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def table(p,r):
    with p.open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(r[0]));w.writeheader();w.writerows(r)
if __name__=='__main__':
    mode=sys.argv[1];OUT.mkdir(exist_ok=True);export=ROOT/'exportE3AXViewerTrace.m'
    if mode=='before':
        assert not (OUT/'historical_hashes_before.csv').exists()
        protected={}
        for r in rows(PR/'e3c_results/historical_hashes_before.csv'):
            p=Path(r['path'])
            if p==export:continue
            assert sha(p)==r['sha256'],str(p);protected[p]=r['sha256']
        for r in rows(PR/'e3c_results/implementation_hashes.csv'):
            p=Path(r['path']);assert sha(p)==r['sha256'],str(p);protected[p]=r['sha256']
        for directory in [PR/'e3c_results',PR/'e3c']:
            for p in directory.rglob('*'):
                if p.is_file():protected[p]=sha(p)
        for p in [ROOT/'tests/paired_reference/testE3CTemporal.m',ROOT.parent/'docs/paired_reference/PREREGISTRO_E3C.md',ROOT.parent/'docs/paired_reference/RESULTADOS_E3C.md',ROOT.parent/'docs/paired_reference/PREREGISTRO_E3D.md']:
            protected[p]=sha(p)
        table(OUT/'historical_hashes_before.csv',[{'path':str(p),'sha256':h} for p,h in sorted(protected.items())])
        shutil.copyfile(PR/'e3c_results/diagnostic_selection.csv',OUT/'diagnostic_selection.csv')
        shutil.copyfile(PR/'e3c_results/evaluation_selection.csv',OUT/'evaluation_selection.csv')
        (OUT/'exportE3AXViewerTrace_before.m.txt').write_bytes(export.read_bytes())
    failures=[];manifest=rows(OUT/'historical_hashes_before.csv')
    for r in manifest:
        p=Path(r['path'])
        if mode!='before' and p==export:continue
        if not p.exists() or sha(p)!=r['sha256']:failures.append(str(p))
    result={'files':len(manifest),'failures':failures,'pass':not failures,'authorizedChange':'exportE3AXViewerTrace: E3D class recognition only'}
    (OUT/f'integrity_{mode}.json').write_text(json.dumps(result,indent=2))
    if mode!='before':
        diff=''.join(difflib.unified_diff((OUT/'exportE3AXViewerTrace_before.m.txt').read_text().splitlines(True),export.read_text().splitlines(True),fromfile='before',tofile='E3D'))
        (OUT/'authorized_exporter.diff').write_text(diff)
    print(json.dumps(result));assert not failures
