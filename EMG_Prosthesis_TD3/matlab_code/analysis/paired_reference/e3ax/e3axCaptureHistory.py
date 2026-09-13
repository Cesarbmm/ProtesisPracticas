"""Congela el cierre E2G antes de entregar E3AX; no recaptura."""
from pathlib import Path
import csv,hashlib,os
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];PR=HERE.parent;OUT=PR/'e3ax_preparation';OUT.mkdir(exist_ok=True)
target=OUT/'historical_hashes_before.csv';assert not target.exists()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
sources=set()
with (PR/'e2g_results/historical_hashes_before.csv').open(encoding='utf-8-sig') as f:
 for r in csv.DictReader(f):p=(ROOT/r['path']).resolve();assert sha(p)==r['sha256'];sources.add(p)
for pat in ['e2g*.m','e2g*.py','run*E2G*.m','verifyE2G*.py']:sources.update(PR.glob(pat))
sources.update((PR/'e2g_results').rglob('*'));sources.update((ROOT.parent/'docs/paired_reference').glob('*E2G.md'));sources.update((ROOT/'tests/paired_reference').glob('*E2G.m'))
with target.open('w',newline='',encoding='utf-8') as f:
 w=csv.DictWriter(f,fieldnames=['path','sha256','bytes']);w.writeheader()
 for p in sorted(sources):
  if p.is_file():w.writerow(dict(path=os.path.relpath(p,ROOT),sha256=sha(p),bytes=p.stat().st_size))
print('HISTORICAL_FILES',sum(p.is_file() for p in sources))
