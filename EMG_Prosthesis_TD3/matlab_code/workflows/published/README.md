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
- `run_no_glove_stage2_offline_validation.m`: calibración sintética por sesión,
  decodificación de dos sinergias y referencia viable; no construye `Env`, no
  usa simulador, agente, entrenamiento ni hardware

- `run_no_glove_stage3_state_validation.m`: smoke simulado de `intentMarkov60`,
  dimensiones 44/52/60/132, referencia causal y alineación acción-EMG; no
  carga agente, no entrena y no usa hardware

- `run_no_glove_stage4_reward_validation.m`: validacion numerica de la
  recompensa causal sin DTW y smoke completo EMG-only con `intentMarkov60`,
  `baselineQuantized` y `SimController`; no carga agente, no entrena y no usa
  hardware

## Regla

- mantener aqui los puntos de entrada activos del proyecto
- no mover runtime, evaluacion ni checkpoints reutilizables fuera de `src/`
- no mezclar aqui launchers legacy; esos quedan en `../legacy/`
