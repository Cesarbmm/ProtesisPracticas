"""Cierra sólo artefactos E2G; no autoriza ni ejecuta un entrenamiento."""
import csv,hashlib,json,os
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=HERE/'e2g_results'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run():
 S=json.loads((OUT/'scientific_summary.json').read_text(encoding='utf-8'));T=json.loads((OUT/'test_summary.json').read_text())
 with (OUT/'historical_hashes_before.csv').open(encoding='utf-8-sig') as f:history=list(csv.DictReader(f))
 for r in history:assert sha(ROOT/r['path'])==r['sha256'],r['path']
 assert T['previousPassed']==169 and T['newE2GPassed']==27 and T['passed']==196 and T['failed']==T['incomplete']==0
 gates=dict(S['gatesBeforeTests'],E=True,F=True);passed=all(gates.values())
 assert not passed,'No cambiar el cierre medido sin una revisión científica explícita.'
 S.update(gates=gates,tests=T,result='REFERENCE_CONTRACT_NOT_VALIDATED',RL_PILOT_AUTHORIZED=False,E3A_PREPARED=False,E3A_EXECUTED=False,
  historicalHashesIntact=True,historicalFiles=len(history),MATEO_SANDRA_SEALED=True,GIT_REPAIR_ATTEMPTED=False,PUSH=False)
 (OUT/'e2g_summary.json').write_text(json.dumps(S,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
 sources=set()
 for pat in ['e2g*.m','e2g*.py','run*E2G*.m','verifyE2G*.py']:sources.update(HERE.glob(pat))
 sources.update((ROOT/'tests/paired_reference').glob('*E2G*.m'));sources.update((ROOT.parent/'docs/paired_reference').glob('*E2G.md'))
 files=[p for p in OUT.rglob('*') if p.is_file() and p.name not in ['artifact_manifest.json','independent_verification.json'] and p.suffix!='.log']
 manifest=dict(artifacts=[dict(file=p.relative_to(OUT).as_posix(),sha256=sha(p),bytes=p.stat().st_size) for p in sorted(files)],
  sources=[dict(file=os.path.relpath(p,ROOT),sha256=sha(p),bytes=p.stat().st_size) for p in sorted(sources)],excluded=['*.log (salida de consola)','artifact_manifest.json','independent_verification.json'])
 (OUT/'artifact_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
 print(json.dumps(dict(result=S['result'],gates=gates,tests=T['passed'],artifacts=len(files),sources=len(sources)),indent=2))
if __name__=='__main__':run()
