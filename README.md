# ProtesisPracticas

Repositorio principal del proyecto de control de una protesis mioelectrica con aprendizaje por refuerzo.

## Estado actual

El punto oficial del proyecto queda asi:

- benchmark oficial: `Agent7250`
- linea residual activa: `stop-band` confirmada alrededor de `2000` episodios
- referencia residual historica single-run: `Agent1850`
- nombre operativo de la ruta residual: `Residual Lift`

Las salidas locales no se versionan:

- `Agentes/`
- `Imagenes/`

## Contenido publicado

- `EMG_Prosthesis_TD3/`: proyecto principal de MATLAB
- `EMG_Prosthesis_TD3/matlab_code/`: codigo operativo para entrenamiento, test y auditoria
- `EMG_Prosthesis_TD3/matlab_code/checkpoints/canonical/`: checkpoints canonicamente publicados
- `EMG_Prosthesis_TD3/docs/td3_training_report/`: documentacion final curada

## Arranque rapido

Abre MATLAB y trabaja desde:

```matlab
cd('C:/ruta/al/repo/EMG_Prosthesis_TD3/matlab_code')
addpath(genpath(pwd))
clearConfigurablesOverride()
```

### Flujo residual activo

Para seguir la linea actual con parada temprana controlada:

```matlab
results = run_residual_lift_stopband_confirmation();
```

Si quieres descubrir una nueva banda antes de confirmar:

```matlab
results = run_residual_lift_stopband_discovery();
```

### Entrenamiento residual generico sobre cualquier base

```matlab
results = run_residual_lift_pilot(struct( ...
    'baseCheckpointPath', "C:/ruta/a/tu/AgentXXXX.mat"));
```

### Tests canonicamente publicados

```matlab
runCheckpointTest(getAgent7250CheckpointPath(), 50, true);
runCheckpointTest(getResidualFinalCheckpointPath(), 50, true);
```

## Migracion a otra PC

```powershell
git clone https://github.com/Cesarbmm/ProtesisPracticas.git
cd ProtesisPracticas
git checkout main
```

Luego en MATLAB:

```matlab
cd('C:/ruta/al/clon/ProtesisPracticas/EMG_Prosthesis_TD3/matlab_code')
addpath(genpath(pwd))
clearConfigurablesOverride()
```

Si vas a usar solo simulacion, normalmente basta con revisar en `configurables.m`:

- `dataset_folder`
- `agents_directory`

Si va a haber hardware, revisa ademas:

- `comUNO`
- `comGlove`

## Documentacion

- `EMG_Prosthesis_TD3/README.md`: estado del proyecto y flujos principales
- `EMG_Prosthesis_TD3/matlab_code/README.md`: guia operativa exacta
- `EMG_Prosthesis_TD3/docs/td3_training_report/README.md`: documentos y figuras canonicas
