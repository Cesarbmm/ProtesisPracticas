# EMG_Prosthesis_TD3

Proyecto MATLAB para entrenar y evaluar agentes TD3 en el control de una protesis mioelectrica usando senales EMG.

## Estado publicado

La version actual del proyecto deja este punto fijo:

- benchmark oficial: `Agent7250`
- linea residual activa: `stop-band` confirmada alrededor de `2000` episodios
- referencia residual reproducible historica previa: `seed 22`
- mejor residual single-run historico: `Agent1850`

La `stop-band` confirmada pasa a ser la nueva linea operativa para continuar la exploracion residual, pero `Agent7250` sigue siendo el benchmark oficial.

## Requisitos

- MATLAB
- Reinforcement Learning Toolbox
- Deep Learning Toolbox
- Signal Processing Toolbox
- dataset en `matlab_code/data/datasets/Denis Dataset/`

## Estructura relevante

- `matlab_code/config/`: configuracion global
- `matlab_code/src/`: entorno, reward, auditoria y launchers
- `matlab_code/agents/`: definicion de agentes y rama residual
- `matlab_code/checkpoints/canonical/`: benchmark y residual publicado
- `docs/td3_training_report/`: documentacion final curada

## Flujos principales

Trabaja desde:

```matlab
cd('C:/ruta/al/repo/EMG_Prosthesis_TD3/matlab_code')
addpath(genpath(pwd))
clearConfigurablesOverride()
```

### Flujo residual activo con stop-band

```matlab
results = run_residual_lift_stopband_confirmation();
```

Esto usa:

- base congelada `Agent7250`
- una banda de parada temprana ya confirmada
- auditoria completa y retest final por seed

### Discovery de una nueva stop-band

```matlab
results = run_residual_lift_stopband_discovery();
```

### Residual generico sobre cualquier base

```matlab
results = run_residual_lift_pilot(struct( ...
    'baseCheckpointPath', "C:/ruta/a/tu/AgentXXXX.mat"));
```

### Tests canonicos

```matlab
runCheckpointTest(getAgent7250CheckpointPath(), 50, true);
runCheckpointTest(getResidualFinalCheckpointPath(), 50, true);
```

### Entrenamiento base de referencia

```matlab
trainInterface('td3','','')
```

## Portabilidad

En otra PC normalmente solo hay que revisar en `matlab_code/config/configurables.m`:

- `params.dataset_folder`
- `params.agents_directory`

Y solo si se usa hardware:

- `params.comUNO`
- `params.comGlove`

`dataset_folder` y `agents_directory` deben quedar relativos/portables para el flujo publicado.

## Documentacion adicional

- `matlab_code/README.md`: guia operativa detallada
- `docs/td3_training_report/README.md`: documentos, figuras y compilacion manual
