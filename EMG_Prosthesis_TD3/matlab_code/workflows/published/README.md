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

- `run_no_glove_stage5_plant_diagnostic.m`: baseline P/PD cuantizado y
  diagnóstico reproducible de la planta simulada mediante escalones y rampas
  por motor; mide retardo, ganancia, zona muerta, velocidad, saturación y
  conversión `encoder2Flex` sin modificar el simulador ni usar hardware

- `run_no_glove_stage6_smoke.m`: entrenamiento desde cero de un TD3
  feedforward `intentMarkov60`, limitado a 200 episodios y seed 11; usa un
  corpus EMG sintético de la misma sesión sintética de calibración
- `run_no_glove_stage6_pilot.m`: piloto separado de 2000 episodios con seeds
  `[11,22,33]`; no es invocado automáticamente por el smoke
- `run_no_glove_stage6_campaign.m`: campaña 12k multisemilla; exige un
  manifiesto de piloto con gate aprobado antes de comenzar
- `run_no_glove_stage6b_boundary_diagnostic.m`: diagnóstico estrictamente
  offline de un smoke 6A fallido; alinea estado, referencia, PWM y encoder
  posterior, estratifica mecanismos por motor y no carga agente, simulador o DTW
- `run_no_glove_stage6c_matched_controller.m`: comparación emparejada de las
  trazas Agent200 con el controlador P validado en ETAPA 5; reutiliza exactamente
  `q_ref`, `v_ref` e inicio por episodio, simula solo la fuente convencional y no
  carga agente, entrena, calcula DTW ni usa hardware
- `run_no_glove_stage7_offline_temporal_analysis.m`: evaluacion temporal
  estrictamente offline de las trazas emparejadas de ETAPA 6C; calcula MSE sin
  desplazamiento y con lags discretos, correlacion y una ruta DTW multivariable
  compartida para los cuatro motores, preservando el error de extremo y sin
  cargar agente, construir `Env`, invocar simulador/reward o usar hardware
- `run_no_glove_stage7a_lag_confirmation.m`: confirmacion offline de retardos
  con `repetitionId` held-out y soporte interior identico para todos los lags;
  termina en el gate y no ejecuta compensacion, filtro, DTW, agente, `Env`,
  simulador, reward, entrenamiento ni hardware

## Regla

- mantener aqui los puntos de entrada activos del proyecto
- no mover runtime, evaluacion ni checkpoints reutilizables fuera de `src/`
- no mezclar aqui launchers legacy; esos quedan en `../legacy/`
