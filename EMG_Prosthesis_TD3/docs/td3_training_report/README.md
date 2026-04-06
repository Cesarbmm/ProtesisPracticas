# TD3 Prosthesis Documentation

Carpeta canonica de documentacion tecnica, didactica y de presentacion del proyecto.

## Punto actual documentado

El estado final reflejado por esta carpeta es:

- benchmark oficial: `Agent7250`
- linea residual activa: `stop-band` confirmada alrededor de `2000` episodios
- referencia historica single-run: `Agent1850`

## Documentos canonicos retenidos

### Base tecnica e historica

- `td3_protesis_evolucion_y_baseline_20260322.tex`
- `td3_protesis_evolucion_y_baseline_20260322.pdf`
- `avance_exploracion_threshold_y_siguiente_intervencion_20260325.md`
- `avance_exploracion_threshold_y_siguiente_intervencion_20260325.tex`
- `avance_exploracion_threshold_y_siguiente_intervencion_20260325.pdf`
- `fase_residual_agent7250_y_barridos_alpha_20260326.tex`
- `fase_residual_agent7250_y_barridos_alpha_20260326.pdf`

### Reportes finales

- `reporte_general_td3_protesis_estado_final_20260326.tex`
- `reporte_general_td3_protesis_estado_final_20260326.pdf`
- `reporte_reproducibilidad_residual_multiseed_20260330.tex`
- `reporte_reproducibilidad_residual_multiseed_20260330.pdf`
- `reporte_corrida_larga_residual_20260402.tex`
- `reporte_corrida_larga_residual_20260402.pdf`
- `reporte_corridas_largas_base_y_residual_20260404.tex`
- `reporte_corridas_largas_base_y_residual_20260404.pdf`
- `reporte_fase_stopband_residual_20260405.tex`
- `reporte_fase_stopband_residual_20260405.pdf`

### Paper, guias y presentacion

- `ieee_paper_td3_prosthesis_residual_20260330.tex`
- `ieee_paper_td3_prosthesis_residual_20260330.pdf`
- `guia_didactica_td3_protesis_20260326.tex`
- `guia_didactica_td3_protesis_20260326.pdf`
- `guia_tecnica_codigo_y_paths_20260325.tex`
- `guia_tecnica_codigo_y_paths_20260325.pdf`
- `guia_charla_divulgativa_td3_protesis_20260326.tex`
- `guia_charla_divulgativa_td3_protesis_20260326.pdf`
- `presentacion_final_td3_protesis_20260326.tex`
- `presentacion_final_td3_protesis_20260326.pdf`

### Bibliografia

- `references.bib`
- `referencias_protesis_TD3_4.xlsx`

## Figuras canonicas retenidas

### Baseline y transicion inicial

- `figures/training_progress_8000eps_valid_baseline.png`
- `figures/test_episode_49_valid_baseline_8000.png`
- `figures/training_progress_12000eps_valid_baseline.png`
- `figures/test_episode_49_extension_12000.png`
- `figures/test_episode_49_agent1100_low_exploration.png`
- `figures/threshold_exploration_tradeoff_20260325.png`
- `figures/aligned_action_pilot_tradeoff_20260325.png`
- `figures/aligned_action_pilot_bin_usage_20260325.png`

### Fase residual y multi-seed

- `figures/post7250_interventions_tradeoff_20260326.png`
- `figures/residual_agent1850_training_progress_20260326.png`
- `figures/residual_agent1850_episode49_20260326.png`
- `figures/residual_phase_tradeoff_20260326.png`
- `figures/residual_alpha_sweep_metrics_20260326.png`
- `figures/residual_alpha_diagnostics_20260326.png`
- `figures/residual_multiseed_summary_20260330.png`

### Corridas largas

- `figures/agent7250_longrun_training_progress_20260404.png`
- `figures/agent7250_longrun_checkpoint_evolution_20260404.png`
- `figures/agent7250_longrun_candidate_comparison_20260404.png`
- `figures/agent7250_longrun_best_visual_20260404.png`
- `figures/agent7250_longrun_benchmark_visual_20260404.png`
- `figures/longrun_residual_training_progress_20260402.png`
- `figures/longrun_residual_checkpoint_evolution_20260402.png`
- `figures/longrun_residual_candidate_comparison_20260402.png`
- `figures/longrun_residual_best_visual_20260402.png`
- `figures/longrun_residual_benchmark_visual_20260402.png`

### Stop-band residual

- `figures/residual_stopband_discovery_training_overview_20260405.png`
- `figures/residual_stopband_discovery_winner_episodes_20260405.png`
- `figures/residual_stopband_discovery_comparison_20260405.png`
- `figures/residual_stopband_confirmation_training_overview_20260405.png`
- `figures/residual_stopband_confirmation_winner_episodes_20260405.png`
- `figures/residual_stopband_confirmation_comparison_20260405.png`

### Guias y presentacion

- `figures/guia_tecnica_pipeline_20260325.png`
- `figures/charla_linea_proyecto_20260326.png`
- `figures/charla_training_residual_20260326.png`
- `figures/charla_test_residual_20260326.png`
- `figures/charla_comparacion_final_20260326.png`
- `figures/charla_comparacion_base_a_final_20260326.png`

## Compilacion manual

Compila cada documento desde esta carpeta.

### Paper IEEE

```text
pdflatex -interaction=nonstopmode -halt-on-error ieee_paper_td3_prosthesis_residual_20260330.tex
bibtex ieee_paper_td3_prosthesis_residual_20260330
pdflatex -interaction=nonstopmode -halt-on-error ieee_paper_td3_prosthesis_residual_20260330.tex
pdflatex -interaction=nonstopmode -halt-on-error ieee_paper_td3_prosthesis_residual_20260330.tex
```

### Reporte integrador de la fase stop-band

```text
pdflatex -interaction=nonstopmode -halt-on-error reporte_fase_stopband_residual_20260405.tex
pdflatex -interaction=nonstopmode -halt-on-error reporte_fase_stopband_residual_20260405.tex
```

### Presentacion final

```text
pdflatex -interaction=nonstopmode -halt-on-error presentacion_final_td3_protesis_20260326.tex
pdflatex -interaction=nonstopmode -halt-on-error presentacion_final_td3_protesis_20260326.tex
```

## Politica de versionado

Se conservan solo:

- documentos finales `.tex`, `.pdf` y `.md`
- bibliografia canonicamente usada
- figuras realmente usadas por esos documentos
- scripts fuente utiles

No se conservan:

- auxiliares de LaTeX y Beamer
- reportes smoke
- figuras smoke
- duplicados intermedios de paper o reportes
