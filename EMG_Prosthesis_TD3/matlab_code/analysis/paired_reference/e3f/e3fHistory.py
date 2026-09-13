import csv, hashlib, json, sys, shutil
from pathlib import Path

ROOT = Path(r'C:/Users/Cesarbmm/ProtesisPracticas_e2b_audit/EMG_Prosthesis_TD3/matlab_code')
PR = ROOT / 'analysis/paired_reference'
OUT = PR / 'e3f_results'
EXPORT = ROOT / 'exportE3AXViewerTrace.m'

def sha(p):
    h = hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda: f.read(4*1024*1024), b''):
            h.update(b)
    return h.hexdigest()

def rows(p):
    with p.open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))

def table(p, r):
    with p.open('w', encoding='utf-8', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(r[0]))
        w.writeheader()
        w.writerows(r)

if __name__ == '__main__':
    mode = sys.argv[1] if len(sys.argv) > 1 else 'before'
    OUT.mkdir(exist_ok=True)

    if mode == 'before':
        if (OUT / 'historical_hashes_before.csv').exists():
            (OUT / 'historical_hashes_before.csv').unlink()
        protected = {}
        # Cargar hashes históricos previos de E3E
        for r in rows(PR / 'e3e_results/historical_hashes_before.csv'):
            p = Path(r['path'])
            if p == EXPORT:
                protected[p] = sha(p)
                continue
            assert sha(p) == r['sha256'], f'Discrepancia en {p}'
            protected[p] = r['sha256']

        # Incorporar artefactos de E3E
        for directory in [PR / 'e3e_results', PR / 'e3e']:
            for p in directory.rglob('*'):
                if p.is_file() and p.name != 'integrity_after.json':
                    protected[p] = sha(p)
        for p in [ROOT / 'tests/paired_reference/testE3EDomainAudit.m',
                  ROOT.parent / 'docs/paired_reference/PREREGISTRO_E3E_DOMAIN_AUDIT.md',
                  ROOT.parent / 'docs/paired_reference/RESULTADOS_E3E_DOMAIN_AUDIT.md',
                  ROOT.parent / 'docs/paired_reference/PREREGISTRO_E3F_SUBJECT_INVARIANT_PPO.md']:
            if p.is_file():
                protected[p] = sha(p)

        table(OUT / 'historical_hashes_before.csv',
              [{'path': str(p), 'sha256': h} for p, h in sorted(protected.items(), key=lambda x: str(x[0]))])

    failures = []
    manifest = rows(OUT / 'historical_hashes_before.csv')
    for r in manifest:
        p = Path(r['path'])
        if not p.exists() or sha(p) != r['sha256']:
            failures.append(str(p))

    result = {
        'files': len(manifest),
        'failures': failures,
        'pass': not failures,
        'stage': 'E3F_BEFORE' if mode == 'before' else 'E3F_AFTER'
    }
    (OUT / f'integrity_{mode}.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
    assert not failures, f'Fallos de integridad: {failures}'
