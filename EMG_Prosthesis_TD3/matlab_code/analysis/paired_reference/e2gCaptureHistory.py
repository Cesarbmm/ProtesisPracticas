"""Inventario E2G único: conserva fuentes/resultados hasta E2F."""
import csv,hashlib,os
from pathlib import Path
here=Path(__file__).resolve().parent
root=here.parents[1]
out=here/'e2g_results';out.mkdir(exist_ok=True)
target=out/'historical_hashes_before.csv'
assert not target.exists(),'No recapturar después de medir.'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
sources=set()
with (here/'e2f_results/historical_hashes_before.csv').open(encoding='utf-8-sig') as f:
 for row in csv.DictReader(f):
  p=(root/row['path']).resolve();assert sha(p)==row['sha256'];sources.add(p)
for pat in ['e2f*.m','e2f*.py','run*E2F*.m','verifyE2F*.py']:sources.update(here.glob(pat))
sources.update((here/'e2f_results').rglob('*'))
sources.update((root/'tests/paired_reference').glob('*E2F*.m'))
sources.update((root.parent/'docs/paired_reference').glob('*E2F.md'))
for rel in ['src/preprocess/encoder2Flex.m','src/preprocess/reduceFlexDimension.m','src/runtime/getDataset.m','src/@RecordedGlove/RecordedGlove.m','src/@Glove/decodingSerialData.m','config/definitions.m','config/configurables.m']:
 sources.add(root/rel)
with target.open('w',newline='',encoding='utf-8') as f:
 w=csv.DictWriter(f,fieldnames=['path','sha256','bytes']);w.writeheader();count=0
 for p in sorted(sources):
  if not p.is_file():continue
  assert 'sandbox' not in str(p).lower()
  w.writerow(dict(path=os.path.relpath(p,root),sha256=sha(p),bytes=p.stat().st_size));count+=1
prereg=root.parent/'docs/paired_reference/PREREGISTRO_E2G.md'
(out/'preregistration.sha256').write_text(sha(prereg)+'\n',encoding='utf-8')
print(dict(historicalFiles=count,preregistrationSHA256=sha(prereg)))
