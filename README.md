# ProtesisPracticas

Repositorio principal del proyecto de control de una protesis mioelectrica con aprendizaje por refuerzo.

La publicacion actual deja como resultado operativo final la linea residual sobre `Agent7250`:

- benchmark canonico: `Agent7250`
- candidato final canonico: `Agent1850`
- workflow recomendado: entrenar una rama residual desde cero sobre la politica base congelada

## Contenido publicado

- `EMG_Prosthesis_TD3/`: proyecto principal de MATLAB.
- `EMG_Prosthesis_TD3/matlab_code/`: codigo operativo para entrenamiento, test y auditoria.
- `EMG_Prosthesis_TD3/matlab_code/checkpoints/canonical/`: checkpoints canonicamente publicados.
- `EMG_Prosthesis_TD3/docs/td3_training_report/`: documentacion final curada.

Las salidas locales no se versionan:

- `Agentes/`
- `Imagenes/`

## Quick Start

Abre MATLAB y trabaja desde:

```matlab
cd('C:/ruta/al/repo/EMG_Prosthesis_TD3/matlab_code')
clearConfigurablesOverride()
```

### Workflow publicado recomendado

Entrenar una nueva corrida residual sobre el benchmark canonico:

```matlab
results = run_agent7250_residual_policy_pilot();
```

### Test del candidato final canonico

```matlab
runCheckpointTest(getResidualFinalCheckpointPath(), 50, true);
```

### Test del benchmark canonico

```matlab
runCheckpointTest(getAgent7250CheckpointPath(), 50, true);
```

### Entrenamiento base de referencia

```matlab
trainInterface('td3','','')
```

### Auditoria de checkpoints

```matlab
results = runCheckpointAudit(20, 50, 2, struct( ...
    'experimentDir', 'C:/ruta/a/una/corrida', ...
    'samplingPolicy', struct('mode','tail_every_k_last_n','k',50,'n',12)));
```

## Paths a revisar

En `EMG_Prosthesis_TD3/matlab_code/config/configurables.m`:

- `params.dataset_folder`
- `params.agents_directory`
- `params.comUNO`
- `params.comGlove`

`agentFile` ya no es necesario para el flujo publicado si usas los helpers canonicos.

## Documentacion

- `EMG_Prosthesis_TD3/README.md`: estado del proyecto y workflow final.
- `EMG_Prosthesis_TD3/matlab_code/README.md`: guia operativa exacta.
- `EMG_Prosthesis_TD3/docs/td3_training_report/README.md`: documentos y figuras canonicas.
