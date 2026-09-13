"""Fixtures locales no versionados. Copias independientes: nunca hardlinks al archivo."""
import csv,json,shutil
from pathlib import Path
from build_publication import DEST,SOURCE,MAT
def main():
 with (DEST/'PUBLICATION_MANIFEST.csv').open(encoding='utf-8') as f:rows=list(csv.DictReader(f))
 copy=[];skipped=[]
 for r in rows:
  if r['included']=='YES':continue
  rel=r['destination_path'];src=Path(r['source_path']);low=rel.lower()
  if any(x in low for x in ['final_sealed_test/','__pycache__','smoke','scratch','sandbox']):continue
  if '/analysis/paired_reference/' not in low and '/results/' not in low:continue
  if src.suffix.lower() not in ['.mat','.csv','.json','.txt','.png','.fig','.html','.pdf']:continue
  dst=DEST/rel
  if not dst.exists():copy.append((src,dst))
 print(json.dumps({'fixtureFiles':len(copy),'fixtureBytes':sum(p.stat().st_size for p,d in copy)},indent=2),flush=True)
 for k,(src,dst) in enumerate(copy):
  dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
  if k%1000==0:print('fixtures',k,flush=True)
 out=DEST/'.publication_local';out.mkdir(exist_ok=True)
 (out/'fixtures.json').write_text(json.dumps({'files':len(copy),'source':str(SOURCE),'sealedRawRead':False,'finalSealedTrajectoriesCopied':False,'versioned':False},indent=2))
if __name__=='__main__':main()
