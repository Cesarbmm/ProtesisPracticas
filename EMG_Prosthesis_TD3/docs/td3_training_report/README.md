# TD3 Prosthesis Documentation

Carpeta canonica de documentacion tecnica, didactica y de presentacion del proyecto.

## Documentos retenidos

- `references.bib`
- `referencias_protesis_TD3_4.xlsx`
- `td3_protesis_evolucion_y_baseline_20260322.tex`
- `td3_protesis_evolucion_y_baseline_20260322.pdf`
- `avance_exploracion_threshold_y_siguiente_intervencion_20260325.md`
- `avance_exploracion_threshold_y_siguiente_intervencion_20260325.tex`
- `avance_exploracion_threshold_y_siguiente_intervencion_20260325.pdf`
- `fase_residual_agent7250_y_barridos_alpha_20260326.tex`
- `fase_residual_agent7250_y_barridos_alpha_20260326.pdf`
- `ieee_paper_td3_prosthesis_residual_20260330.tex`
- `ieee_paper_td3_prosthesis_residual_20260330.pdf`
- `reporte_reproducibilidad_residual_multiseed_20260330.tex`
- `reporte_reproducibilidad_residual_multiseed_20260330.pdf`
- `reporte_general_td3_protesis_estado_final_20260326.tex`
- `reporte_general_td3_protesis_estado_final_20260326.pdf`
- `guia_didactica_td3_protesis_20260326.tex`
- `guia_didactica_td3_protesis_20260326.pdf`
- `guia_tecnica_codigo_y_paths_20260325.tex`
- `guia_tecnica_codigo_y_paths_20260325.pdf`
- `guia_charla_divulgativa_td3_protesis_20260326.tex`
- `guia_charla_divulgativa_td3_protesis_20260326.pdf`
- `presentacion_final_td3_protesis_20260326.tex`
- `presentacion_final_td3_protesis_20260326.pdf`

## Figuras retenidas

- `figures/training_progress_8000eps_valid_baseline.png`
- `figures/test_episode_49_valid_baseline_8000.png`
- `figures/training_progress_12000eps_valid_baseline.png`
- `figures/test_episode_49_extension_12000.png`
- `figures/test_episode_49_agent1100_low_exploration.png`
- `figures/threshold_exploration_tradeoff_20260325.png`
- `figures/aligned_action_pilot_tradeoff_20260325.png`
- `figures/aligned_action_pilot_bin_usage_20260325.png`
- `figures/post7250_interventions_tradeoff_20260326.png`
- `figures/residual_agent1850_training_progress_20260326.png`
- `figures/residual_agent1850_episode49_20260326.png`
- `figures/residual_phase_tradeoff_20260326.png`
- `figures/residual_alpha_sweep_metrics_20260326.png`
- `figures/residual_alpha_diagnostics_20260326.png`
- `figures/residual_multiseed_summary_20260330.png` (generated after running the multi-seed campaign)
- `figures/guia_tecnica_pipeline_20260325.png`
- `figures/charla_linea_proyecto_20260326.png`
- `figures/charla_training_residual_20260326.png`
- `figures/charla_test_residual_20260326.png`
- `figures/charla_comparacion_final_20260326.png`
- `figures/charla_comparacion_base_a_final_20260326.png`

## Compilacion

Compila cada documento por separado desde esta carpeta.

### Guia didactica

```text
pdflatex guia_didactica_td3_protesis_20260326.tex
bibtex guia_didactica_td3_protesis_20260326
pdflatex guia_didactica_td3_protesis_20260326.tex
pdflatex guia_didactica_td3_protesis_20260326.tex
```

### Guia sencilla para charla

Las figuras ya quedan versionadas. El script es opcional y sirve solo para regenerarlas localmente a partir de resultados guardados:

```text
matlab -batch "cd('C:/ruta/al/repo/EMG_Prosthesis_TD3/docs/td3_training_report/scripts'); build_charla_divulgativa_figures"
matlab -batch "cd('C:/ruta/al/repo/EMG_Prosthesis_TD3/docs/td3_training_report/scripts'); build_residual_multiseed_publication_figure"
pdflatex guia_charla_divulgativa_td3_protesis_20260326.tex
bibtex guia_charla_divulgativa_td3_protesis_20260326
pdflatex guia_charla_divulgativa_td3_protesis_20260326.tex
pdflatex guia_charla_divulgativa_td3_protesis_20260326.tex
```

### Guia tecnica de codigo y paths

```text
pdflatex guia_tecnica_codigo_y_paths_20260325.tex
pdflatex guia_tecnica_codigo_y_paths_20260325.tex
```

### Reporte longitudinal y baseline

```text
pdflatex td3_protesis_evolucion_y_baseline_20260322.tex
bibtex td3_protesis_evolucion_y_baseline_20260322
pdflatex td3_protesis_evolucion_y_baseline_20260322.tex
pdflatex td3_protesis_evolucion_y_baseline_20260322.tex
```

### Avance de exploracion

```text
pdflatex avance_exploracion_threshold_y_siguiente_intervencion_20260325.tex
pdflatex avance_exploracion_threshold_y_siguiente_intervencion_20260325.tex
```

### Fase residual

```text
pdflatex fase_residual_agent7250_y_barridos_alpha_20260326.tex
bibtex fase_residual_agent7250_y_barridos_alpha_20260326
pdflatex fase_residual_agent7250_y_barridos_alpha_20260326.tex
pdflatex fase_residual_agent7250_y_barridos_alpha_20260326.tex
```

### Paper IEEE final

```text
pdflatex ieee_paper_td3_prosthesis_residual_20260330.tex
bibtex ieee_paper_td3_prosthesis_residual_20260330
pdflatex ieee_paper_td3_prosthesis_residual_20260330.tex
pdflatex ieee_paper_td3_prosthesis_residual_20260330.tex
```

### Reporte de reproducibilidad multi-seed

```text
pdflatex reporte_reproducibilidad_residual_multiseed_20260330.tex
pdflatex reporte_reproducibilidad_residual_multiseed_20260330.tex
```

### Reporte general final

```text
pdflatex reporte_general_td3_protesis_estado_final_20260326.tex
bibtex reporte_general_td3_protesis_estado_final_20260326
pdflatex reporte_general_td3_protesis_estado_final_20260326.tex
pdflatex reporte_general_td3_protesis_estado_final_20260326.tex
```

### Presentacion final

```text
pdflatex presentacion_final_td3_protesis_20260326.tex
pdflatex presentacion_final_td3_protesis_20260326.tex
```

## Politica de versionado

Se conservan solo:

- documentos canonicos `.tex`, `.pdf` y `.md`;
- `references.bib` y el Excel bibliografico;
- figuras realmente usadas;
- scripts fuente utiles.

Los auxiliares de LaTeX, Beamer y builds intermedios se ignoran.
