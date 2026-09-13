"""Normaliza solo lineas vacias de codigo en la copia; conserva hash fuente y hash publicacion."""
import csv,re,json
from pathlib import Path
from build_publication import DEST,digest
def normalized(raw):return re.sub(rb'(?m)^[ \t]+(?=\r?$)',b'',raw)
def main():
 p=DEST/'PUBLICATION_MANIFEST.csv'
 with p.open(encoding='utf-8',newline='') as f:rows=list(csv.DictReader(f))
 changes=[]
 for r in rows:
  if r['included']!='YES':r['publication_sha256']='';continue
  dst=DEST/r['destination_path'];src=Path(r['source_path']);raw=src.read_bytes()
  if dst.suffix in ['.m','.py']:
   new=normalized(raw)
   if new!=raw:
    dst.write_bytes(new);changes.append(dict(path=r['destination_path'],sourceSHA256=r['sha256'],publicationSHA256=digest(dst),change='remove whitespace on otherwise empty code lines only'))
    r['reason']=r['reason'].split('; FORMAT_ONLY')[0]+'; FORMAT_ONLY blank code lines'
  r['publication_sha256']=digest(dst)
 with p.open('w',encoding='utf-8',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
 out=DEST/'.publication_local/format_only_changes.json';out.write_text(json.dumps(changes,indent=2))
 print(json.dumps({'formatOnlyFiles':len(changes),'testsWithFormatOnlyChange':[r['path'] for r in changes if '/tests/' in r['path']]},indent=2))
if __name__=='__main__':main()
