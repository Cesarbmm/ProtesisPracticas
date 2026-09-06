# identification/ — S4 ejecutada · `DYNAMIC_MEMORY_NOT_JUSTIFIED`

Resultado completo: **`S4_RESULTADOS.md`**. Umbrales fijados antes de ajustar:
`../PREREGISTRO_S4_DYNAMIC_IDENTIFICATION.md`.

Resumen en una línea: añadir memoria de velocidad (`tau`) al modelo de planta no mejora
nada. El `tau` identificado es ≤ 2.7 ms, la mejora held-out mediana es −0.016 %, y ninguna
de las 56 condiciones mejora por encima del suelo de repetibilidad. **No se creó
`DynamicPlantAdapter`**; S5 y S6 quedan bloqueadas.

## Qué hay aquí

| Archivo | Qué es |
|---|---|
| `S4_RESULTADOS.md` | Informe: suelo de repetibilidad, split, modelos A y B, parámetros, errores por motor/dirección/PWM, límites y decisión |
| `s4_repetition_split.csv` | Split congelado FIT/VALIDATION por repetición (268 filas) |
| `s4_condition_floor.csv` | Repeatability floor por condición, calculado sólo con FIT |
| `s4_identified_parameters.csv` | `v_inf` por condición y `tau` por motor, con marca `at_bound` |
| `s4_validation_heldout.csv` | Métricas held-out de A y B por condición |
| `buildS4IdentificationDataset.m` | Dataset largo + split + floor desde `pattern_curve.mat` |
| `s4Conditions.m` | Estructura por condición, con límites empíricos y verificación del split |
| `reducedOrderPlantResponse.m` | Modelos A y B: solución analítica + RK4 para el test de convergencia |
| `fitReducedOrderPlant.m` | Ajuste determinista sobre FIT (rejilla + `fminbnd`) |
| `validateReducedOrderPlant.m` | Evaluación held-out con las métricas del preregistro |
| `runSandboxS4Identification.m` | Orquestador: ejecuta todo y aplica el gate C1-C5 |
| `s4_fig1..3*.png` | Figuras del informe |

## Reglas que siguen vigentes para cualquier continuación

1. **Se ajusta contra `pattern_curve.mat`**, nunca con `J`/`B`/`Kt` inventados. Se comprobó
   además que esos parámetros físicos **no son identificables** con estos datos.
2. **Partición honesta por repetición**, disjunta y congelada antes de ajustar. Hay un test
   que corrompe las repeticiones VALIDATION y exige que el ajuste no cambie.
3. **Preregistro propio** antes de tocar el primer parámetro de cualquier modelo nuevo.
4. Nada de topes elásticos, fricción de Coulomb, redes ni Simscape sin identificación
   previa y sin autorización explícita.

La hipótesis que los datos señalan para una eventual **S4b** —no abierta— está en
`S4_RESULTADOS.md` §9: la estructura dominante es una **velocidad dependiente de la
posición**, `dq/dt = f(q, u)`, no una velocidad con memoria.
