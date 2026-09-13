"""Seleccion explicita de archivos para commits pequenos. Nunca git add de resultados completos."""
import argparse,csv,subprocess
from pathlib import Path
from build_publication import DEST,MAT
ap=argparse.ArgumentParser();ap.add_argument('part',choices=['record','e4','closure']);part=ap.parse_args().part
with (DEST/'PUBLICATION_MANIFEST.csv').open(encoding='utf-8') as f:rows=list(csv.DictReader(f))
files=[]
for r in rows:
 if r['included']!='YES':continue
 st=r['stage'];p=r['destination_path']
 if (part=='record' and st not in ['E4','FINAL_SEALED_TEST']) or (part=='e4' and st=='E4') or (part=='closure' and st=='FINAL_SEALED_TEST'):files.append(p)
if part=='record':files+=['.gitignore']
if part=='closure':
 files+=['PUBLICATION_MANIFEST.csv','docs/paired_reference/FINAL_CAMPAIGN_CLOSURE.md','docs/paired_reference/PUBLICATION_VALIDATION.md',MAT+'/runPublicationRegressions.m','EMG_Prosthesis_TD3/docs/paired_reference/FINAL_CAMPAIGN_CLOSURE.md']
 files += [p.relative_to(DEST).as_posix() for p in (DEST/'tools/publication').glob('*.py')]
 files += [p.relative_to(DEST).as_posix() for p in (DEST/MAT/'analysis/paired_reference/publication_results').glob('*') if p.suffix in ['.csv','.json']]
files=sorted(set(files))
assert not any(p.lower().endswith(('.mat','.fig','.zip')) or 'sandbox_physics' in p.lower() for p in files)
for start in range(0,len(files),30):
 subprocess.run(['git','add','-f','--',*files[start:start+30]],cwd=DEST,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
 # Reaplicar atributos -text incluso si el cache stat no detecta cambio de archivo.
 subprocess.run(['git','add','--renormalize','--',*files[start:start+30]],cwd=DEST,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
print(part,len(files),'rutas explicitamente seleccionadas')
