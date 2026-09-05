# CLAUDE.md — Contrato de trabajo del proyecto EMG_Prosthesis_TD3

> Este archivo vive en la RAÍZ del worktree
> `experiment/no-glove-paired-reference-td3`. Claude Code lo lee al arrancar cada sesión.

## Idioma

Responder SIEMPRE en español. Código y nombres de archivo en inglés, como el resto del repo.

## Qué es este proyecto

Control mioeléctrico continuo de una prótesis de 4 motores con TD3, en MATLAB
(Reinforcement Learning Toolbox). Benchmark operativo vigente: `Agent7250`
(`matlab_code/checkpoints/canonical/Agent7250_valid_baseline/`), con
`trackingMSE = 0.043045`, `trackingMAE = 0.160336`, `actionL2 = 0.596444`,
`saturationFraction = 0.392086`, `deltaActionL2 = 0.321385`.

## Línea de trabajo actual

Sustituir el guante físico por un estimador de referencia aprendido de los pares históricos
EMG–guante, conservando TD3. Ver `docs/paired_reference/00_LINEA_RECOMENDADA.md`.

## Reglas duras — no negociables

1. **No entrenar.** Claude Code no lanza entrenamientos ni campañas. Prepara scripts, tests y
   documentos; el usuario ejecuta MATLAB y pega los resultados.
2. **No `git push`.** Nunca. Ni a `main` ni a la rama de trabajo.
3. **No tocar `main`.** Todo ocurre en la rama de la etapa.
4. **No crear sub-etapas.** Existen E0…E4 y nada más. Una hipótesis nueva se escribe en
   `BACKLOG.md` con una línea y se sigue con la etapa en curso. Si crees que hace falta una `E3a`,
   PARA y pregunta.
5. **Un cambio por etapa.** Nunca modificar simultáneamente decoder, observación, reward y acción.
6. **Preregistro antes de correr.** Ninguna etapa se ejecuta sin `PREREGISTRO_Ex.md` con el umbral
   de decisión escrito de antemano. Un resultado sin umbral previo siempre "parece prometedor".
7. **No reintroducir** `intentMarkov60/62`, `motionPermission`, gate de reposo, hold latch,
   `actionCommandScale ≠ 1.0`, calibración sintética ni las dos sinergias.
8. **Splits por sujeto**, compartidos entre decoder y RL. Escalers ajustados sólo en train.

## Invariantes que hay que preservar

- Observación `markov52` = 40 EMG + 4 enc + 4 Δenc + 4 a_{t-1}.
- Reward `trackingMseActionRateReward`, λ_a = 0.01, λ_Δa = 0.05.
- Interfaz `baselineQuantized`, niveles `[0 64 96 128 160 192 224 255]`, `speeds = 255*[1 1 1 1]`,
  `actionCommandScale = 1.0`.
- La ruta histórica `referenceSource="glove"` debe seguir siendo **byte-idéntica**. Todo test que
  la compare es bloqueante.
- El guante nunca entra en la observación. En la línea nueva tampoco entra en la reward: sólo se usa
  como verdad de terreno de auditoría, en test.

## Métricas obligatorias en todo informe

`trackingMSE`, `trackingMAE`, `actionL2`, `saturationFraction`, `deltaActionL2`, y por motor
`responseRange`, `flat_response`, `action_no_motion`, `high_action_flat_response`.

Cuando la referencia sea estimada, reportar **las dos**:
`trackingMSE_vs_estimate` y `trackingMSE_vs_trueGlove`.

## Baselines obligatorios en toda etapa con tracking

`u = 0`, `P` con Kp barrido, y TD3 — los tres sobre la MISMA referencia. Un TD3 que no bate a
`decoder + P` en el compromiso completo no es una contribución.

## Definición de "etapa terminada"

Una etapa entrega exactamente cuatro cosas, ni una más:

1. `docs/paired_reference/0X_<nombre>.md` — resultados y lectura
2. `matlab_code/workflows/published/run_paired_reference_stageX_*.m` — un workflow reproducible
3. `matlab_code/tests/paired_reference/testPairedReferenceStageX*.m` — tests que pasan
4. una línea en `docs/paired_reference/DECISIONES.md` con el veredicto: SIGUE / PARA / VUELVE

## Estilo de respuesta esperado

- Empezar por el veredicto, después la evidencia.
- Citar archivo y línea al afirmar algo sobre el código. Si no lo has leído, dilo.
- Distinguir siempre: medido / inferido / supuesto.
- Intentar refutar la hipótesis del usuario antes de aceptarla. La ETAPA 12 se construyó sobre un
  `actionCommandScale = 0.2510` que nadie cuestionó durante tres etapas.
