# TD3 Prosthesis Documentation

Esta carpeta contiene la documentacion tecnica canónica del proyecto.

## Documentos principales

- `guia_didactica_td3_protesis_20260323.tex`
- `guia_didactica_td3_protesis_20260323.pdf`
- `td3_protesis_evolucion_y_baseline_20260322.tex`
- `td3_protesis_evolucion_y_baseline_20260322.pdf`
- `references.bib`

## Figuras canónicas

- `figures/training_progress_8000eps_valid_baseline.png`
- `figures/test_episode_49_valid_baseline_8000.png`

## Compilacion

Desde esta carpeta, compila cada documento por separado.

### Guia didactica

```text
pdflatex guia_didactica_td3_protesis_20260323.tex
bibtex guia_didactica_td3_protesis_20260323
pdflatex guia_didactica_td3_protesis_20260323.tex
pdflatex guia_didactica_td3_protesis_20260323.tex
```

### Reporte longitudinal / baseline

```text
pdflatex td3_protesis_evolucion_y_baseline_20260322.tex
bibtex td3_protesis_evolucion_y_baseline_20260322
pdflatex td3_protesis_evolucion_y_baseline_20260322.tex
pdflatex td3_protesis_evolucion_y_baseline_20260322.tex
```

## Politica de versionado

En Git se conservan solo:

- los `.tex` canónicos;
- sus PDFs finales;
- `references.bib`;
- las figuras realmente usadas.

Los auxiliares de LaTeX y builds intermedios se ignoran.
