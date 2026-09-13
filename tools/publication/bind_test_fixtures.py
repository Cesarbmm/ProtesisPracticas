"""Binding de fixtures, sin cambiar tests ni hashes esperados. Restaurar antes de commit.
Solo el path de la excepcion historica autorizada del exportador se vincula al
worktree actual. Los manifiestos originales permanecen en backups byte-identicos.
"""
import argparse,csv,json,shutil
from pathlib import Path
from build_publication import DEST,SOURCE,MAT,digest
def main():
 ap=argparse.ArgumentParser();ap.add_argument('mode',choices=['prepare','restore']);mode=ap.parse_args().mode
 local=DEST/'.publication_local';back=local/'manifest_bindings';back.mkdir(exist_ok=True)
 if mode=='restore':
  for p in back.glob('*.csv'):
   target=DEST/MAT/'analysis/paired_reference'/p.stem/'historical_hashes_before.csv';shutil.copy2(p,target)
  print('Bindings restaurados');return
 audit=json.loads((local/'fixture_path_audit.json').read_text());copied=[]
 for rel,src in audit['missing'].items():
  low=rel.lower();src=Path(src)
  if not src.is_file() or 'sandbox' in low or '/data/' in low.replace('\\','/') or 'final_sealed_test' in low:continue
  dst=DEST/rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst);copied.append(rel)
 bindings=[]
 for stage in ['e3c_results','e3d_results']:
  p=DEST/MAT/'analysis/paired_reference'/stage/'historical_hashes_before.csv';b=back/(stage+'.csv')
  if not b.exists():shutil.copy2(p,b)
  raw=b.read_bytes();old=str(SOURCE/MAT/'exportE3AXViewerTrace.m').encode();new=str(DEST/MAT/'exportE3AXViewerTrace.m').encode()
  assert raw.count(old)==1;changed=raw.replace(old,new);p.write_bytes(changed)
  bindings.append(dict(stage=stage,originalSHA256=digest(b),fixtureSHA256=digest(p),change='path of pre-existing authorized exporter exception only; expected SHA unchanged'))
 (local/'fixture_binding_audit.json').write_text(json.dumps(dict(copiedAdditionalFiles=len(copied),bindings=bindings,testsModified=False,sealedRawRead=False),indent=2))
 print(json.dumps(dict(additionalFixtures=len(copied),bindings=bindings),indent=2))
if __name__=='__main__':main()
