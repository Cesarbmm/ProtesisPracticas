"""Congela una vez la integridad de fuentes recibidas, sin recorrer sandbox."""
import csv
import hashlib
from pathlib import Path

here = Path(__file__).resolve().parent
root = here.parents[1]
out = here / "e2d_results"
out.mkdir(exist_ok=True)
target = out / "historical_hashes_before.csv"
assert not target.exists(), "El inventario inicial no se regenera tras medir."
hash_file = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
sources = set()
with (here / "e2c_results/historical_hashes_before.csv").open(encoding="utf-8-sig") as f:
    for item in csv.DictReader(f):
        p = (root / item["path"]).resolve()
        assert hash_file(p) == item["sha256"], str(p)
        sources.add(p)
for pattern in ("e2c*.m", "run*E2C*.m", "verifyE2C*.py"):
    sources.update(here.glob(pattern))
sources.update((here / "e2c_results").glob("*"))
sources.update((root / "tests/paired_reference").glob("*E2C*.m"))
sources.update((root.parent / "docs/paired_reference").glob("*E2C.md"))
with (here / "e2c_results/m3_raw_provenance.csv").open(encoding="utf-8-sig") as f:
    for item in csv.DictReader(f):
        p = Path(item["file"]).resolve()
        assert hash_file(p) == item["sha256"]
        sources.add(p)
import os
with target.open("w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=["path", "sha256", "bytes"])
    writer.writeheader()
    count = 0
    for p in sorted(sources):
        if not p.is_file():
            continue
        assert "sandbox" not in str(p).lower()
        writer.writerow(dict(path=os.path.relpath(p, root), sha256=hash_file(p), bytes=p.stat().st_size))
        count += 1
print(f"ARCHIVOS_HISTORICOS_CONGELADOS = {count}")
