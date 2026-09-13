"""Congela fuentes recibidas hasta E2E antes del oracle; no recaptura."""
import csv,hashlib,os
from pathlib import Path
here=Path(__file__).resolve().parent
root=here.parents[1]
out=here/'e2f_results'
out.mkdir(exist_ok=True)
target=out/'historical_hashes_before.csv'
assert not target.exists(), 'No recapturar tras medir.'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
sources=set()
with (here/'e2e_results/historical_hashes_before.csv').open(encoding='utf-8-sig') as f:
 for row in csv.DictReader(f):
  p=(root/row['path']).resolve();assert sha(p)==row['sha256'];sources.add(p)
for pat in ['e2e*.m','e2e*.py','run*E2E*.m','verifyE2E*.py']:sources.update(here.glob(pat))
sources.update((here/'e2e_results').rglob('*'))
sources.update((root/'tests/paired_reference').glob('*E2E*.m'))
sources.update((root.parent/'docs/paired_reference').glob('*E2E.md'))
sources.update((root.parent/'prosthesis_code').rglob('*'))
with target.open('w',newline='',encoding='utf-8') as f:
 w=csv.DictWriter(f,fieldnames=['path','sha256','bytes']);w.writeheader();count=0
 for p in sorted(sources):
  if not p.is_file():continue
  assert 'sandbox' not in str(p).lower()
  w.writerow(dict(path=os.path.relpath(p,root),sha256=sha(p),bytes=p.stat().st_size));count+=1
prereg=root.parent/'docs/paired_reference/PREREGISTRO_E2F.md'
(out/'preregistration.sha256').write_text(sha(prereg)+'\n',encoding='utf-8')
print(dict(historicalFiles=count,preregistrationSHA256=sha(prereg)))
