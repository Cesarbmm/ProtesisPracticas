# ProtesisPracticas

Repositorio principal del proyecto **EMG_Prosthesis_TD3**, orientado al control proporcional de una prótesis mioeléctrica de cuatro motores mediante señales EMG y aprendizaje por refuerzo con TD3.

Repositorio público: https://github.com/Cesarbmm/ProtesisPracticas

## Estado oficial del proyecto

La rama `main` contiene la línea publicada y reproducible del proyecto:

- benchmark operativo oficial: `Agent7250`;
- checkpoint canónico: `EMG_Prosthesis_TD3/matlab_code/checkpoints/canonical/Agent7250_valid_baseline/Agent7250_valid_baseline.mat`;
- observación oficial: `markov52`;
- reward oficial: `trackingMseActionRateReward`;
- interfaz de acción oficial: `baselineQuantized`;
- línea residual y `stop-band`: experimentos derivados que no reemplazan al benchmark.

Las campañas posteriores de 12k, 20k y 50k episodios no superaron de forma conjunta el tracking, esfuerzo, saturación y suavidad de Agent7250. Por ello, Agent7250 permanece como referencia para comparar nuevos experimentos y como candidato para la preparación previa a hardware.

## De la base de Fuertes Bustos a Agent7250

El manuscrito base de Fuertes Bustos et al. ya planteaba una acción continua de cuatro motores en `[-1,1]`; por tanto, no debe describirse como un sistema estrictamente no continuo. La diferencia principal es que esa etapa demostró viabilidad conceptual, mientras que Agent7250 se construyó después de auditar la reward, el orden temporal de `step`, el simulador, el logging y el protocolo de selección.

| Elemento | Trabajo base de Fuertes Bustos et al. | Benchmark Agent7250 |
|---|---|---|
| Estado | `44D = 40 EMG + 4 encoders` | `52D = 40 EMG + 4 encoders + 4 deltaEncoders + 4 acciones previas` |
| Acción | 4 comandos continuos en `[-1,1]`, escalados a PWM | 4 acciones continuas con aplicación efectiva `baselineQuantized` |
| Reward | Combinación heredada de dirección, distancia, movimiento y suavidad | `trackingMseActionRateReward` con tracking, esfuerzo y cambio de acción |
| Protocolo reportado | 48 episodios de evaluación | 50 simulaciones auditadas |
| trackingMAE | `0.1553` | `0.160336` |
| trackingMSE | No reportado | `0.043045` |
| actionL2 | No reportado | `0.596444` |
| saturationFraction | No reportado | `0.392086` |
| deltaActionL2 | No reportado | `0.321385` |
| Trazabilidad | Prueba de viabilidad conceptual | Benchmark operativo con métricas globales y por motor |

El MAE no debe compararse como si ambos resultados provinieran del mismo protocolo: entre ambas etapas cambiaron el simulador, la reward, la observación y la auditoría. La contribución de Agent7250 no es simplemente reducir una cifra aislada, sino establecer una referencia reproducible y defendible para las campañas posteriores.

## Configuración oficial de Agent7250

| Parámetro | Valor |
|---|---:|
| Arquitectura | TD3 feedforward, 64 unidades ocultas |
| Sample time | `0.2 s` |
| Actor learning rate | `1e-4` |
| Critic learning rate | `1e-3` |
| Discount factor | `0.95` |
| Mini-batch | `64` |
| Experience buffer | `1e5` |
| Target smooth factor | `5e-3` |
| Policy update frequency | `2` |
| Target update frequency | `2` |
| Exploration standard deviation | `0.2` |
| Exploration decay | `1e-4` |
| Minimum exploration deviation | `0.02` |
| Target policy deviation | `0.2` |
| Target policy noise clip | `0.5` |

## Métricas oficiales de Agent7250

| Métrica | Valor |
|---|---:|
| trackingMSE | `0.043045` |
| trackingMAE | `0.160336` |
| actionL2 | `0.596444` |
| saturationFraction | `0.392086` |
| deltaActionL2 | `0.321385` |
| absPwmMean | `178.288566` |

## Estado de validación previa a hardware

La validación con Myo real se mantiene separada del benchmark de simulación. Se verificó la adquisición de ocho canales y el pipeline `EMG → features → markov52 → Agent7250` sin conectar la mano ni el guante físico. Agent7250 mostró acciones elevadas en reposo, por lo que se desarrolló una compuerta diagnóstica de reposo en simulación. La mano física continúa deshabilitada hasta completar la validación estructurada y los límites de seguridad. El guante físico también permanece fuera del flujo; no forma parte de las 52 entradas del agente y se utilizaba únicamente como referencia de tracking/reward.

## Contenido publicado

- `EMG_Prosthesis_TD3/`: proyecto principal de MATLAB.
- `EMG_Prosthesis_TD3/matlab_code/`: entrenamiento, evaluación y auditoría.
- `EMG_Prosthesis_TD3/matlab_code/checkpoints/canonical/`: checkpoints canónicos publicados.
- `EMG_Prosthesis_TD3/docs/td3_training_report/`: documentación y figuras curadas.
- `Agentes/` e `Imagenes/`: salidas locales no versionadas.

## Arranque rápido

```matlab
cd('C:/ruta/al/repo/EMG_Prosthesis_TD3/matlab_code')
addpath(genpath(pwd))
clearConfigurablesOverride()
```

Comprobar el benchmark canónico:

```matlab
checkpointPath = getAgent7250CheckpointPath();
disp(checkpointPath)
```

Ejecutar el test oficial en simulación:

```matlab
runCheckpointTest(getAgent7250CheckpointPath(), 50, true);
```

## Flujos experimentales derivados

La línea residual utiliza Agent7250 como base congelada, pero no sustituye al benchmark oficial.

```matlab
results = run_residual_lift_stopband_confirmation();
```

Para descubrir otra banda de parada:

```matlab
results = run_residual_lift_stopband_discovery();
```

Para iniciar una línea residual sobre otro checkpoint:

```matlab
results = run_residual_lift_pilot(struct( ...
    'baseCheckpointPath', "C:/ruta/a/tu/AgentXXXX.mat"));
```

## Migración a otra PC

```powershell
git clone https://github.com/Cesarbmm/ProtesisPracticas.git
cd ProtesisPracticas
git checkout main
```

Luego, desde MATLAB:

```matlab
cd('C:/ruta/al/clon/ProtesisPracticas/EMG_Prosthesis_TD3/matlab_code')
addpath(genpath(pwd))
clearConfigurablesOverride()
```

Para simulación, normalmente basta con revisar:

- `dataset_folder`;
- `agents_directory`.

Los puertos `comUNO` y `comGlove` solo deben revisarse en una fase de hardware expresamente autorizada.

## Documentación

- `EMG_Prosthesis_TD3/README.md`: estado del proyecto y flujos principales.
- `EMG_Prosthesis_TD3/matlab_code/README.md`: guía operativa detallada.
- `EMG_Prosthesis_TD3/docs/td3_training_report/README.md`: documentos y figuras canónicas.
