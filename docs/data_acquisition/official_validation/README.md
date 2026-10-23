# Evidencia de preparación oficial Myo

Validación ejecutada con MATLAB R2023b sobre Windows, únicamente con fuentes MOCK. No se conectó hardware ni se inició una adquisición humana.

- [test_results.csv](test_results.csv): suite completa de adquisición; 113 regresiones anteriores y 24 pruebas nuevas.
- [mock_summary.json](mock_summary.json): resultado de la campaña oficial completa simulada.
- [integrity_summary.json](integrity_summary.json): comprobación por SHA256 de 503 archivos locales históricos y fuentes científicas protegidas. No se publican datos humanos ni sus archivos originales.
- [posture_confirmation_mock.png](posture_confirmation_mock.png): imagen instalada, identidad sintética y diez verificaciones obligatorias; todas visibles sin recortar el botón.
- [opening_PREPARE.png](opening_PREPARE.png), [opening_MOVE.png](opening_MOVE.png) y [closing_HOLD.png](closing_HOLD.png): GUI de captura con señal sintética; instrucciones y cues actuales conservados.

La suite ejecuta además el smoke V1 y el estrés anterior: 1.000 iteraciones de reemplazo / 3.000 promociones, 526 s simulados, 81 trials, sin temporales huérfanos. La campaña oficial mock recorre 833 s, 48 movimientos y 97 registros científicos sintéticos; valida hashes, manifest, nueva postura, seed derivada del UUID, ausencia de escritura en práctica y reserva de otra sesión.

La etiqueta «ready» valida preparación del software y contrato; el ajuste, orientación, postura y calidad física deben verificarse manualmente antes de cada captura. No es una declaración de DATASET_GENERAL_READY.

```text
OFFICIAL_CAMPAIGN_CONFIG = PASS
POSTURE_P0_SEATED_ARMREST = PASS
POSTURE_REFERENCE_HASH = PASS
MYO_PLACEMENT_CHECKLIST = PASS
PRECHECK_GATE = PASS
SESSION_RANDOMIZATION = PASS
S04_PROTOCOL_PRESERVED = PASS
HISTORICAL_COMPATIBILITY = PASS
PRACTICE_MODE = PASS
ALL_TESTS = 137/137
OFFICIAL_MOCK_SMOKE = PASS (833 s simulados; 48 movimientos; 97 registros)
HISTORICAL_FILES_PRESERVED = 503/503
READY_FOR_OFFICIAL_ACQUISITION = YES
HUMAN_ACQUISITION_STARTED = NO
MODELS_TRAINED = NO
```

## Archivos y propósito

Rutas de código relativas a `EMG_Prosthesis_TD3/matlab_code/`:

| Archivo | Cambio |
|---|---|
| acquisition/myoOfficialCampaignConfig.m | Descriptor oficial nuevo, P0_SEATED_ARMREST, P1 y JPG existente |
| acquisition/buildMyoOfficialProtocol.m | Reutiliza el protocolo científico; cambia sólo etiquetas de campaña, versión y postura |
| acquisition/runMyoMultiParticipantApp.m | Runner predeterminado de la campaña oficial; no conecta hardware |
| acquisition/MyoContinuousAcquisitionApp.m | Diez confirmaciones, ayuda P1, revisión de avisos, precheck guiado y recuperación de reserva/seed |
| acquisition/MyoParticipantRegistry.m | Derivación estable de seed y lectura de reservas pendientes; CSV anterior sin migración |
| acquisition/myoSessionSeed.m | UUID → seed uint32, sin reloj ni RNG global |
| acquisition/MyoAcquisitionSession.m | Verifica imagen actual y confirmaciones oficiales antes de crear carpeta/metadata |
| acquisition/myoPostureAssetPath.m | Resolución de JPG oficial y assets legacy sin rutas del equipo |
| acquisition/myoPrecheckInstruction.m | Reposo/apertura/cierre/reposo dentro de diagnóstico, no trials |
| acquisition/myoPrecheckReview.m | Presenta avisos existentes, exige reconocimiento y mantiene errores bloqueantes |
| acquisition/validateMyoPilot2Protocol.m | Admite la nueva postura sin cambiar condiciones ni tiempos |
| acquisition/validateMyoTrial.m | Lectura de nueva postura junto con las históricas |
| acquisition/prepareMyoCampaignAssets.m | Conserva PNG/manifest legacy; no vuelve a derivar una postura antigua desde el JPG reemplazado |
| acquisition/references/Referencia.jpg | Imagen ya reemplazada por el operador, preservada byte por byte y publicada en su mismo path |
| acquisition/runMyoMultiParticipantSmoke.m | Mock completo actualizado al contrato oficial, con hash y seed verificables |
| tests/acquisition/testMyoOfficialAcquisition.m | 24 pruebas oficiales deterministas |
| tests/acquisition/fixtures/MockMyoPrecheckSource.m | Avisos/errores de calidad sintéticos para tests |
| tests/acquisition/testMyoMultiParticipant.m | Selección explícita del descriptor piloto para mantener sus regresiones |

Documentación relativa a `docs/data_acquisition/`:

| Archivo | Cambio |
|---|---|
| OFFICIAL_MYO_ACQUISITION_PROTOCOL.md | Procedimiento físico A–G, contrato, seed y comando manual |
| MYO_GUI_USER_GUIDE.md | Entrada oficial actual y enlace a procedimiento |
| MULTIPARTICIPANT_CAMPAIGN_V2.md | Señala el alcance histórico del piloto, sin modificar sus resultados |
| MYO_CONTINUOUS_DATA_SCHEMA.md | Extensión de metadata oficial y compatibilidad sin migrar RAW |
| official_validation/* | Tests, resumen mock, integridad y capturas sintéticas |

Los generadores `buildMyoPilot2Protocol`, `buildMyoCampaignProtocol`, `myoProtocolTarget` y `assets/cues_manifest.json` no se modificaron. No se cambió ningún archivo bajo `data_acquisition` ni se añadieron RAW, MEX, DLL o SDK al commit.
