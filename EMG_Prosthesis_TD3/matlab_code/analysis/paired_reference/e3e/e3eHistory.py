"""Integridad E3E: verificar anclas previas, registrar artefactos históricos congelados."""
import csv, hashlib, json, sys, shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PR = ROOT / 'analysis/paired_reference'
OUT = PR / 'e3e_results'
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
        # Cargar hashes históricos previos de E3D
        for r in rows(PR / 'e3d_results/historical_hashes_before.csv'):
            p = Path(r['path'])
            if p == EXPORT:
                protected[p] = sha(p)
                continue
            assert sha(p) == r['sha256'], f"Discrepancia en {p}"
            protected[p] = r['sha256']

        # Incorporar artefactos de E3D
        for directory in [PR / 'e3d_results', PR / 'e3d']:
            for p in directory.rglob('*'):
                if p.is_file():
                    protected[p] = sha(p)
        for p in [ROOT / 'tests/paired_reference/testE3DTemporalIntent.m',
                  ROOT.parent / 'docs/paired_reference/PREREGISTRO_E3D.md',
                  ROOT.parent / 'docs/paired_reference/RESULTADOS_E3D.md']:
            if p.is_file():
                protected[p] = sha(p)

        table(OUT / 'historical_hashes_before.csv',
              [{'path': str(p), 'sha256': h} for p, h in sorted(protected.items(), key=lambda x: str(x[0]))])

        # Copiar selecciones diagnósticas históricas
        if (PR / 'e3d_results/diagnostic_selection.csv').exists():
            shutil.copyfile(PR / 'e3d_results/diagnostic_selection.csv', OUT / 'diagnostic_selection.csv')
        if (PR / 'e3d_results/evaluation_selection.csv').exists():
            shutil.copyfile(PR / 'e3d_results/evaluation_selection.csv', OUT / 'evaluation_selection.csv')

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
        'stage': 'E3E_BEFORE' if mode == 'before' else 'E3E_AFTER'
    }
    (OUT / f'integrity_{mode}.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
    assert not failures, f"Fallos de integridad: {failures}"
