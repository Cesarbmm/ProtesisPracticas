"""Publicacion selectiva. El archivo cientifico nunca se modifica."""
import argparse,csv,hashlib,json,re,shutil,subprocess
from pathlib import Path
SOURCE=Path(r'C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit')
DEST=Path(__file__).resolve().parents[2]
PROJ='EMG_Prosthesis_TD3';MAT=PROJ+'/matlab_code'
RUNS={'e3ax_long':'run_20260908_141321_916_6ebf347b','e3b_long':'run_20260909_002700_470_a733a786','e3f_long':'run_20260910_002946_786_14f0a07f','e4_final_development':'run_20260910_084228_108_8176e5a9','final_sealed_test':'run_20260911_212959_985_f79338ed'}
def digest(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for x in iter(lambda:f.read(4*1024*1024),b''):h.update(x)
 return h.hexdigest()
def stage(rel):
 s=rel.lower()
 if 'sealed' in s:return 'FINAL_SEALED_TEST'
 if 'cap192' in s:return 'CAP192'
 for k in ['e4','e3f','e3e','e3d','e3c','e3b','e3ax','e3a','e2g','e2f','e2e','e2d','e2c','e2b','e2a','e0p']:
  if k in s:return k.upper().replace('E3AX','E3A-X')
 return 'SHARED'
def classify(p,rel):
 size=p.stat().st_size;s=rel.lower();ext=p.suffix.lower();name=p.name.lower()
 if any(x in s.split('/') for x in ['sandbox_physics','__pycache__','scratch','cache']):return False,'EXCLUDED','Cache/scratch/sandbox excluido'
 if '/tests/paired_reference/' in s and ext in ['.m','.csv','.json','.txt']:return True,'TESTS','Suite/fixture fuente existente'
 if ('/docs/paired_reference/' in s or s.startswith('docs/paired_reference/')) and ext=='.md':return True,('PREREGISTRATIONS' if 'preregistro' in name else 'RESULT REPORTS'),'Documento cientifico existente'
 if ext in ['.m','.py']:
  if p.parent==SOURCE/MAT:return True,'RUNNERS' if name.startswith('run') else 'PLOTTING HELPERS','Runner/helper autorizado'
  if '/analysis/paired_reference/' in s and not any(x.endswith(('_results','_preparation','_audit')) for x in s.split('/')[:-1]):return True,'PLOTTING HELPERS' if 'plot' in name else 'SOURCE CODE','Codigo de etapa y dependencias'
 if 'smoke' in s or name.endswith(('.log','.asv')) or name.startswith(('failed','diary')):return False,'EXCLUDED','Smoke/log temporal fuera de publicacion'
 if ext=='.md' and '/analysis/paired_reference/' in s:return True,'RESULT REPORTS','Informe persistido'
 if ext in ['.csv','.json','.txt'] and ('traces' in name or 'trajector' in name or 'bootstrap_draws' in name or (size>262144 and 'hash' not in name)):
  return False,'EXCLUDED','Trazas/tablas extensas conservadas solo en archivo local'
 if ext in ['.csv','.json','.txt'] and size<=2_000_000:
  if '/analysis/paired_reference/' in s:
   parts=s.split('/paired_reference/')[1].split('/')
   if len(parts)<=2 or (len(parts)<=3 and any(x in name for x in ['summary','gates','metrics','hash','integrity','selection','by_seed','intent','phase'])):
    return True,'SMALL SCIENTIFIC SUMMARIES','Resumen/tablas o ancla de integridad, <=2MB'
  if '/results/' in s:
   if any(x in name for x in ['summary','status','manifest','sha256','unblinding_evidence','post_test','learning_check']) and not name.endswith('.mat'):
    return True,'SMALL SCIENTIFIC SUMMARIES','Cierre/resumen persistido; no recalcular sellados'
 if ext in ['.png','.pdf'] and size<=750000:
  if (p.parent.name.endswith('_results') and 'summary' in name) or ('/results/' in s and 'summary' in name and '/figures/' in s):
   return True,'SMALL SCIENTIFIC SUMMARIES','Figura global pequena existente'
 return False,'EXCLUDED','Binario/traza/figura individual/artefacto voluminoso: archivo local solamente'
def candidates():
 roots=[SOURCE/PROJ/'docs/paired_reference',SOURCE/'docs/paired_reference',SOURCE/MAT/'analysis/paired_reference',SOURCE/MAT/'tests/paired_reference']
 files={p for d in roots if d.exists() for p in d.rglob('*') if p.is_file() and 'sandbox_physics' not in p.parts}
 files.update(p for p in (SOURCE/MAT).glob('*.m') if p.name!='runProsthesis.m')
 for folder,run in RUNS.items():
  d=SOURCE/MAT/'results'/folder/run
  files.update(p for p in d.rglob('*') if p.is_file())
 return sorted(files)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('mode',choices=['manifest','refine','copy']);args=ap.parse_args()
 out=DEST/'PUBLICATION_MANIFEST.csv'
 if args.mode in ['manifest','refine']:
  if args.mode=='manifest':assert not out.exists()
  rows=[]
  for p in candidates():
   rel=p.relative_to(SOURCE).as_posix();inc,typ,reason=classify(p,rel)
   # Nunca considerar datasets originales, por lo que no se abren ni para hash.
   assert '/data/' not in rel.lower() and 'sandbox_physics' not in rel.lower()
   # Excluidos no se abren: inventario de nombres/tamanos, sin consumir trazas.
   h=digest(p) if inc else 'NOT_READ_EXCLUDED'
   if p.name=='FINAL_AGENT.mat':h='2aa39fdf166c62fb6da057f1ddecb6455fbaa142f476718dd4e2725dfde08c90'
   rows.append(dict(source_path=str(p),destination_path=rel,stage=stage(rel),type=typ,size_bytes=p.stat().st_size,sha256=h,included='YES' if inc else 'NO',reason=reason))
  with out.open('w',encoding='utf-8',newline='') as f:
   w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
 else:
  with out.open(encoding='utf-8',newline='') as f:rows=list(csv.DictReader(f))
  for r in rows:
   if r['included']!='YES':continue
   src=Path(r['source_path']);dst=DEST/r['destination_path'];assert digest(src)==r['sha256'];dst.parent.mkdir(parents=True,exist_ok=True)
   if not dst.exists() or digest(dst)!=r['sha256']:shutil.copy2(src,dst)
 selected=[r for r in rows if r['included']=='YES']
 print(json.dumps(dict(candidates=len(rows),included=len(selected),includedBytes=sum(int(r['size_bytes']) for r in selected),byType={k:sum(r['type']==k for r in selected) for k in sorted({r['type'] for r in selected})}),indent=2))
if __name__=='__main__':main()
