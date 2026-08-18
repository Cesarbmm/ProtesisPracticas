# Published Workflows

Launchers vigentes y helpers de campana que no forman parte del core reusable de `src/`.

## Contenido

- `run_residual_lift_pilot.m`: piloto residual base sobre `Agent7250`
- `run_residual_lift_multiseed.m`: reproducibilidad multi-seed
- `run_residual_lift_longrun.m`: variante larga con guardado disperso
- `run_residual_lift_stopband_discovery.m`: discovery de stop-band residual
- `run_residual_lift_stopband_confirmation.m`: confirmacion de stop-band residual
- `runResidualStopbandCampaignCore.m`: orquestacion comun de discovery y confirmation
- `summarizeResidualStopbandCampaign.m`: agregacion de metricas de campana
- `run_repo_smoke_validation.m`: validacion historica que incluye 200 episodios
  de entrenamiento; no usar como smoke de la linea sin guante
- `run_no_glove_stage1_validation.m`: pruebas y smoke EMG-only determinista,
  exclusivamente pregrabado y con `SimController`

## Regla

- mantener aqui los puntos de entrada activos del proyecto
- no mover runtime, evaluacion ni checkpoints reutilizables fuera de `src/`
- no mezclar aqui launchers legacy; esos quedan en `../legacy/`
