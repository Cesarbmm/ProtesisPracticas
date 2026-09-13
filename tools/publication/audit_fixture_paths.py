import csv,json
from pathlib import Path
from build_publication import DEST,SOURCE,MAT
root=DEST/MAT;missing={};absolute=0
for p in (root/'analysis/paired_reference').rglob('*hashes*.csv'):
 try:
  with p.open(encoding='utf-8-sig') as f:rows=list(csv.DictReader(f))
 except Exception:continue
 for r in rows:
  name=r.get('path',r.get('file',''))
  if not name:continue
  q=Path(name)
  if q.is_absolute():
   absolute+=1
   try:relative=q.relative_to(SOURCE);dst=DEST/relative
   except ValueError:continue
  else:dst=(root/q).resolve()
  try:rel=dst.relative_to(DEST)
  except ValueError:continue
  if not dst.exists():missing[str(rel)]=str(SOURCE/rel)
for p in (SOURCE/MAT/'analysis/paired_reference').glob('*/smoke_path.txt'):
 dst=DEST/p.relative_to(SOURCE)
 if not dst.exists():missing[str(dst.relative_to(DEST))]=str(p)
report=dict(absoluteEntries=absolute,missing=missing)
(DEST/'.publication_local/fixture_path_audit.json').write_text(json.dumps(report,indent=2))
print(json.dumps({'absoluteEntries':absolute,'missingPaths':len(missing),'existingArchiveFiles':sum(Path(p).is_file() for p in missing.values())},indent=2))
