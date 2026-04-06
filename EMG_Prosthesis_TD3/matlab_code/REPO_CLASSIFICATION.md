# Repo Classification

Clasificacion operativa del arbol `matlab_code/` para la primera pasada de estabilizacion.

## 1. Core estable

Estos archivos sostienen el flujo base de simulacion, entrenamiento, evaluacion o carga de checkpoints y deben permanecer estables.

- entrenamiento y evaluacion:
  - `src/runtime/trainInterface.m`
  - `src/evaluation/runCheckpointTest.m`
  - `src/evaluation/runCheckpointAudit.m`
  - `src/evaluation/evaluateCheckpointSuite.m`
  - `src/evaluation/analyzeExperimentRun.m`
  - `src/evaluation/classifyBenchmarkAcceptance.m`
- helpers de checkpoints:
  - `src/checkpoints/getAgent7250Benchmark.m`
  - `src/checkpoints/getAgent7250CheckpointPath.m`
  - `src/checkpoints/getResidualFinalCheckpointPath.m`
  - `src/checkpoints/getResidualSeed22CheckpointPath.m`
  - `src/checkpoints/getCanonicalCheckpointRoot.m`
  - `src/checkpoints/loadSavedAgent.m`
- dataset y configuracion:
  - `src/runtime/getDataset.m`
  - `src/runtime/clearConfigurablesOverride.m`
  - `src/runtime/setConfigurablesOverride.m`
  - `config/configurables.m`
  - `config/definitions.m`
- entorno y dispositivos:
  - `src/@Env/`
  - `src/@Controller/`
  - `src/@SimController/`
  - `src/@RecordedMyo/`
  - `src/@RecordedGlove/`
  - `src/@FakeMyo/`
  - `src/@FakeGlove/`
- rewards y preprocesado:
  - `src/reward_functions/`
  - `src/preprocess/`
- agentes vigentes:
  - `agents/agentTd3.m`
  - `agents/agentTd3ResidualLift.m`
  - `agents/agentTd3Residual7250.m`
  - `agents/load_agent.m`

## 2. Flujos publicados vigentes

Estos launchers siguen representando la linea activa o la evaluacion canonica del proyecto.

- stop-band residual:
  - `workflows/published/run_residual_lift_stopband_discovery.m`
  - `workflows/published/run_residual_lift_stopband_confirmation.m`
  - `workflows/published/runResidualStopbandCampaignCore.m`
  - `workflows/published/summarizeResidualStopbandCampaign.m`
- residual reusable:
  - `workflows/published/run_residual_lift_pilot.m`
  - `workflows/published/run_residual_lift_multiseed.m`
  - `workflows/published/run_residual_lift_longrun.m`
  - `workflows/published/run_repo_smoke_validation.m`
  - `src/evaluation/reconstructResidualPolicyDiagnostics.m`
- auditoria y resumen:
  - `src/evaluation/buildCheckpointAuditSummary.m`
  - `src/checkpoints/discoverCheckpointsInExperiment.m`
  - `src/checkpoints/inferEpisodeFromCheckpointName.m`
  - `src/evaluation/summarizeEpisodeDirectory.m`
  - `src/evaluation/readExperienceEpisode.m`

## 3. Historico o experimental

Estos archivos no deben borrarse en la primera pasada, pero tampoco deben seguir mezclados con el camino oficial sin clasificacion explicita.

- launchers de barridos y fases historicas:
  - `workflows/legacy/run_agent7250_*.m`
  - `workflows/legacy/run_longrun_td3_audit.m`
  - `workflows/legacy/run_longrun_residual_audit.m`
  - `workflows/legacy/run_td3_longrun.m`
  - `workflows/legacy/run_markov52_*.m`
  - `workflows/legacy/run_priority_*.m`
- viewers legacy:
  - `analysis/legacy/trainingViewer.m`
  - `analysis/legacy/discreteTrainerViewer.m`
- duplicado anomalo:
  - `analysis/legacy_config_copy/`
- materiales historicos:
  - `development/archive/`
  - `development/README.md`
  - `examples/`
  - `episodes/FINAL/`

## 4. Problemas estructurales ya identificados

- `src/` ya quedo reservado para core reusable
- los launchers vigentes ya salieron a `workflows/published/`, asi que la siguiente limpieza debe centrarse en archivo historico y documentacion residual
- `analysis/legacy/` contiene rutas absolutas legacy
- `analysis/legacy_config_copy/` conserva una copia historica del duplicado previo de `config/analysis/`
- `reward_functions/` ya reemplazo el nombre con espacio y queda como ruta estable
- `development/` ya se formalizo como archivo historico, pero todavia conserva datos y scripts de procedencia que no deben mezclarse con runtime

## 5. Objetivo de reorganizacion para la segunda pasada

La reordenacion objetivo debe ser:

- `src/` para core reusable y helpers operativos
- `workflows/` o `experiments/` para launchers `run_*` de estudios y campanas
- `analysis/legacy/` para viewers no portables o dependientes de rutas antiguas
- `development/archive/` mantenido como archivo historico fuera del camino oficial

La primera pasada no elimina nada.
La segunda pasada puede mover archivos si antes se actualizan referencias, documentacion y pruebas.
