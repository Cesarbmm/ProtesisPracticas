"""Captura/verifica integridad sin recorrer datasets ni sandbox."""
from pathlib import Path
import csv, hashlib, json, sys
ROOT=Path(__file__).resolve().parents[3]
PR=ROOT/"analysis/paired_reference"
OUT=PR/"cap192_results"
RUN=ROOT/"results/e3ax_long/run_20260908_141321_916_6ebf347b"
def sha(p):
    h=hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda:f.read(4*1024*1024),b""): h.update(chunk)
    return h.hexdigest()
def read(p):
    with p.open(encoding="utf-8-sig",newline="") as f:return list(csv.DictReader(f))
def main():
    OUT.mkdir(exist_ok=True)
    manifest=OUT/"historical_hashes_before.csv"
    if "--verify" in sys.argv:
        rows=read(manifest)
        for r in rows:r["currentSHA256"]=sha(ROOT/r["path"]);r["unchanged"]=r["currentSHA256"]==r["sha256"]
        with (OUT/"historical_integrity_after.csv").open("w",newline="",encoding="utf-8") as f:
            w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
        summary={"files":len(rows),"unchanged":all(r["unchanged"] for r in rows)}
        (OUT/"historical_integrity.json").write_text(json.dumps(summary,indent=2),encoding="utf-8")
        print(summary);assert summary["unchanged"];return
    assert not manifest.exists(),"No recapturar el baseline."
    known={}
    for source in [PR/"e3ax_preparation/historical_hashes_before.csv",PR/"e3ax_run_audit/run_integrity_before.csv"]:
        for r in read(source):
            p=(ROOT/r["path"]).resolve();actual=sha(p);assert actual==r["sha256"],str(p);known[p]=actual
    paths=list((PR/"e3ax").glob("*.*"))+list((ROOT/"tests/paired_reference").glob("testE3AX*.m"))
    paths+=list(ROOT.glob("runE3AX*.m"))
    paths+=list((ROOT.parent/"docs/paired_reference").glob("*E3AX*.md"))
    paths+=[ROOT.parent/"docs/paired_reference/PREREGISTRO_CAP192.md"]
    paths+=list((RUN/"evaluation").rglob("*.csv"))+list((RUN/"evaluation").rglob("*.mat"))+list((RUN/"evaluation").rglob("*.json"))
    for p in paths:
        if p.is_file() and p.resolve() not in known:known[p.resolve()]=sha(p)
    import os
    rows=[{"path":os.path.relpath(p,ROOT),"sha256":h,"bytes":p.stat().st_size} for p,h in sorted(known.items())]
    with manifest.open("w",newline="",encoding="utf-8") as f:
        w=csv.DictWriter(f,fieldnames=["path","sha256","bytes"]);w.writeheader();w.writerows(rows)
    print({"protectedFiles":len(rows),"beforeComparisons":True})
if __name__=="__main__":main()
