"""Verifica copia selectiva y prepara lista explicita para Git; no publica por si mismo."""
import csv,json,subprocess
from pathlib import Path
from build_publication import SOURCE,DEST,digest
from normalize_archive_blank_lines import normalized
def main():
 with (DEST/'PUBLICATION_MANIFEST.csv').open(encoding='utf-8') as f:rows=list(csv.DictReader(f))
 included=[r for r in rows if r['included']=='YES'];mismatch=[]
 for r in included:
  p=DEST/r['destination_path']
  if not p.is_file() or digest(p)!=r.get('publication_sha256',r['sha256']):mismatch.append(r['destination_path'])
 assert not mismatch,mismatch
 assert not any('sandbox_physics' in r['destination_path'].lower() for r in included)
 assert not any('/data/' in r['destination_path'].lower() or r['destination_path'].lower().endswith('.mat') for r in included)
 staged=subprocess.check_output(['git','diff','--cached','--name-only','--diff-filter=ACM'],cwd=DEST,text=True).splitlines()
 assert not any('sandbox_physics' in p.lower() or p.lower().endswith(('.mat','.fig','.zip')) for p in staged)
 # Garantizar aserciones intactas, incluidas las comprobaciones de hashes.
 tests=[r for r in included if r['type']=='TESTS']
 assert all(normalized((DEST/r['destination_path']).read_bytes())==normalized(Path(r['source_path']).read_bytes()) for r in tests)
 for r in included:
  if Path(r['destination_path']).suffix in ['.m','.py']:assert normalized((DEST/r['destination_path']).read_bytes())==normalized(Path(r['source_path']).read_bytes())
 # Git no debe convertir los finales de linea de los artefactos archivados.
 index=subprocess.check_output(['git','ls-files','-s','-z'],cwd=DEST).split(b'\0');oids={}
 for entry in index:
  if entry:
   meta,p=entry.split(b'\t',1);oids[p.decode()]=meta.split()[1].decode()
 selected=[r for r in included if r['destination_path'] in oids]
 batch=subprocess.Popen(['git','cat-file','--batch'],cwd=DEST,stdin=subprocess.PIPE,stdout=subprocess.PIPE)
 import hashlib
 indexMismatch=[]
 for r in selected:
  batch.stdin.write((oids[r['destination_path']]+'\n').encode());batch.stdin.flush()
  header=batch.stdout.readline();n=int(header.split()[2]);blob=batch.stdout.read(n);batch.stdout.read(1)
  if hashlib.sha256(blob).hexdigest()!=r.get('publication_sha256',r['sha256']):indexMismatch.append(r['destination_path'])
 batch.stdin.close();batch.wait()
 assert not indexMismatch,dict(indexMismatch=len(indexMismatch),examples=indexMismatch[:8])
 report=dict(includedFiles=len(included),includedBytes=sum(int(r['size_bytes']) for r in included),testsAssertionsUnchanged=True,codeChangesOnlyBlankLineWhitespace=True,sandboxIncluded=False,rawDatasetIncluded=False,modelIncluded=False,copyHashesMatch=True)
 out=DEST/'.publication_local/publication_integrity.json';out.write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
if __name__=='__main__':main()
