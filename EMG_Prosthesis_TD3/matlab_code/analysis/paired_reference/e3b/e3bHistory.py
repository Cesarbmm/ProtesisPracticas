from pathlib import Path
import csv, hashlib, json, sys, os
ROOT=Path(__file__).resolve().parents[3]; PR=ROOT/"analysis/paired_reference"; OUT=PR/"e3b_preparation"
def sha(p):
 h=hashlib.sha256()
 with p.open("rb") as f:
  for b in iter(lambda:f.read(4194304),b""):h.update(b)
 return h.hexdigest()
def read(p):
 with p.open(encoding="utf-8-sig",newline="") as f:return list(csv.DictReader(f))
OUT.mkdir(exist_ok=True); manifest=OUT/"historical_hashes_before.csv"
if "--verify" in sys.argv:
 rows=read(manifest)
 for r in rows:r["current"]=sha(ROOT/r["path"]);r["unchanged"]=r["current"]==r["sha256"]
 with (OUT/"historical_integrity.csv").open("w",newline="",encoding="utf-8") as f:
  w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
 s={"files":len(rows),"unchanged":all(r["unchanged"] for r in rows),"authorizedViewerSHA256":sha(ROOT/"exportE3AXViewerTrace.m")}
 (OUT/"historical_integrity.json").write_text(json.dumps(s,indent=2));print(s);assert s["unchanged"]
else:
 assert not manifest.exists(),"No recapturar hashes."
 known={}
 for r in read(PR/"cap192_results/historical_hashes_before.csv"):
  p=(ROOT/r["path"]).resolve();assert sha(p)==r["sha256"];known[p]=r["sha256"]
 paths=list((PR/"cap192").glob("*.*"))+list((PR/"cap192_results").rglob("*"))+[ROOT/"tests/paired_reference/testCAP192Diagnostic.m",ROOT.parent/"docs/paired_reference/RESULTADOS_CAP192.md",ROOT.parent/"docs/paired_reference/PREREGISTRO_E3B_CATEGORICAL.md"]
 for p in paths:
  if p.is_file():known[p.resolve()]=sha(p)
 with manifest.open("w",newline="",encoding="utf-8") as f:
  w=csv.writer(f);w.writerow(["path","sha256"])
  for p,h in sorted(known.items()):w.writerow([os.path.relpath(p,ROOT),h])
 p=ROOT/"exportE3AXViewerTrace.m"
 (OUT/"viewer_before.m").write_bytes(p.read_bytes())
 (OUT/"authorized_change.json").write_text(json.dumps({"path":str(p.relative_to(ROOT)),"beforeSHA256":sha(p),"reason":"Adaptacion categórica del exportador autorizada por usuario"},indent=2))
 print({"frozen":len(known),"beforeSmoke":True})
