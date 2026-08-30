# ETAPA 7Q — atribución offline de comandos en `intentMarkov60`

Fecha de cierre: 2026-08-30.

## 1. Resultado de la etapa

Resultado de ejecución: **PASS**. Resultado científico preinscrito:
**`distributedOrUnresolved`**.

No se identificó un bloque único del estado que explique simultáneamente la
sensibilidad de la red, la asociación predictiva entre estados reales y los
cambios observados entre ventanas. La evidencia separa tres hechos:

- las features EMG dominan la sensibilidad local y la contribución diferencial
  sobre transiciones reales;
- `q` y `q_ref` predicen casi idénticamente la acción durante demanda cero,
  porque en esa cohorte `q≈q_ref` por definición;
- la acción efectiva anterior está correlacionada con la acción actual, pero su
  sensibilidad normalizada es pequeña y no satisface el gate de causa única.

Agent200 tampoco cumple la definición de `lateTrainingEmergence`. Sobre los
mismos estados reales de Agent200, su PWM absoluto medio es 0.912977 veces el
máximo de Agent50/100/150, no 1.25 veces o más. No se selecciona ninguna
ablación conductual.

## 2. Rama y SHA base/actual

```text
rama                  = experiment/no-glove-intent-control
main/base              = 6b213ba5c624fffb3f1094585c67d9c8ac43b737
preinscripción 7Q      = 61766bf3
implementación 7Q      = 417db38b
validación de hashes   = c0a4698b
auditoría de gradiente = 483135ff4aadb2f5e893367baf20884997a9b537
```

El manifiesto canónico fue generado con el árbol rastreado limpio en
`483135ff`. El archivo ajeno no rastreado `matlab_code.zip` permaneció intacto.
La rama no se empujó al remoto porque ETAPA 7Q no autorizó push.

## 3. Archivos creados y modificados

Documentación:

- `docs/no_glove_experiment/07q_preregistration.md`;
- `docs/no_glove_experiment/07q_command_attribution.md`;
- `matlab_code/workflows/published/README.md`.

Código offline:

- `matlab_code/src/evaluation/evaluateFrozenActorStateGradients.m`;
- `matlab_code/src/evaluation/loadNoGloveStage7qCheckpointSet.m`;
- `matlab_code/src/evaluation/analyzeNoGloveStage7qAttribution.m`;
- `matlab_code/workflows/published/run_no_glove_stage7q_command_attribution.m`;
- `matlab_code/tests/no_glove/testNoGloveStage7qCommandAttribution.m`.

No se modificaron `Env`, reward, referencia, estado, TD3, cuantización,
simulador, gate ni capa de seguridad.

## 4. Decisiones técnicas y justificación

### 4.1 Evidencia y cohortes

Se validaron por SHA-256 los checkpoints state-60:

| Checkpoint | SHA-256 |
|---:|---|
| Agent50 | `D697DA3BB6CE9672330A359DDE3DD43ACEECCB5E2F151EF6E13D3C8C2EC2D013` |
| Agent100 | `3B54D4C5122D7133E9472EE8ED641418A79E0FA7E57A6501AC1C5E611357AB3F` |
| Agent150 | `B760B7EE45F62D6B2E12C1B0A3281E119182CAF96653A293E07E9EFE567A7A66` |
| Agent200 | `440F003450A368A13A0E5DACB04FD7755BB929033EB879B217E47F32B5AA185E` |

La cohorte primaria reproduce exactamente 7P:

```text
contexto = initialRest o declaredRest
abs(v_ref,m) < 0.005
abs(q_ref,m-q_m) <= 1e-4
ventanas con al menos un componente elegible = 517
componentes motor-paso = 2 064
PWM no cero en Agent200 = 2 064/2 064
```

El corpus compartido tiene 3 410 estados Agent200 reales. Los cuatro actores se
reprodujeron sobre esos mismos estados para aislar evolución de política. Los
corpus propios de cada checkpoint se analizaron aparte para no confundir replay
compartido con trayectoria ejecutada. Se inventariaron 304 archivos de entrada.

### 4.2 Sensibilidad local

Para cada salida `m` e índice de estado `j`:

```text
g_t,m,j = d pi_m(s_t)/d s_t,j
S_raw(t,m,b) = sqrt(mean_j_in_b(g_t,m,j^2))
S_scaled(t,m,b) = sqrt(mean_j_in_b((g_t,m,j*sigma_j)^2))
share_b = S_scaled(t,m,b)/sum_k(S_scaled(t,m,k))
```

`sigma_j` se calculó una vez en las 3 410 ventanas Agent200 y se aplicó a los
cuatro checkpoints. Las 40 features EMG son valores estandarizados WMoos; no se
interpretaron como amplitudes físicas.

Mediana de `share_b` para Agent200:

| Motor | EMG | `q` | `Δq` | `u_eff,t-1` | `q_ref` | `v_ref` |
|---:|---:|---:|---:|---:|---:|---:|
| M1 | 0.6764 | 0.0733 | 0.0066 | 0.0377 | 0.2033 | 0.0027 |
| M2 | 0.6880 | 0.0390 | 0.0030 | 0.0423 | 0.2251 | 0.0025 |
| M3 | 0.5538 | 0.0611 | 0.0014 | 0.0386 | 0.3402 | 0.0049 |
| M4 | 0.7523 | 0.0129 | 0.0031 | 0.0220 | 0.2061 | 0.0036 |

EMG superó el gate de gradiente en M1, M2 y M4. En M3 fue el mayor bloque, pero
no alcanzó la relación 2:1 frente a `q_ref`; por eso no se redondeó a cuatro
motores.

### 4.3 Asociación entre estados reales

Se usó ridge con `lambda=1` y cinco folds agrupados por `source+episode`. Los
`R2` fuera de muestra de Agent200 fueron:

| Motor | EMG | `q` | `u_eff,t-1` | `q_ref` |
|---:|---:|---:|---:|---:|
| M1 | 0.0717 | 0.882955 | 0.3965 | 0.882962 |
| M2 | 0.0238 | 0.964048 | 0.4297 | 0.964064 |
| M3 | 0.0223 | 0.956428 | 0.3991 | 0.956428 |
| M4 | 0.0450 | 0.936336 | 0.3668 | 0.936361 |

`q` y `q_ref` quedaron prácticamente empatados. La cohorte exige error de
posición casi nulo, de modo que esta regresión no puede identificar cuál de los
dos explica la salida. Ningún bloque obtuvo margen 0.10 en tres motores y el
conteo de asociación fuerte fue cero para todos.

### 4.4 Transiciones reales

Solo se usaron pares consecutivos dentro del mismo episodio:

```text
C_t,m,b = sum_j_in_b(g_t-1,m,j*(s_t,j-s_t-1,j))
```

EMG concentró 98.09%, 96.18%, 99.05% y 96.35% de la contribución absoluta en
M1–M4, respectivamente. Hubo 443 transiciones elegibles en M1/M2/M4 y 435 en
M3. Las medianas del error de aproximación lineal fueron pequeñas
(`3.20e-7` a `1.67e-6`), pero las medias fueron 0.0827–0.3573 por algunos saltos
grandes que cruzan regiones no lineales. Por ello la contribución temporal se
interpreta como sensibilidad local a cambios observados, no como una
descomposición causal exacta.

### 4.5 Acción previa y evolución

En Agent200, la correlación `u_t` frente a `u_eff,t-1` fue 0.5847–0.6535 y la
coincidencia de signo fue 99.09–100%. Sin embargo, la fracción mediana de
sensibilidad del bloque fue solo 2.20–4.23%. La persistencia es real, pero no
satisface los tres gates de atribución.

Sobre los 2 064 componentes compartidos:

| Actor | PWM absoluto medio | PWM no cero | outward en límite | saturación |
|---:|---:|---:|---:|---:|
| Agent50 | 118.4302 | 98.4012% | 83.7694% | 0.3876% |
| Agent100 | 102.5426 | 99.3702% | 92.0058% | 0% |
| Agent150 | 96.6357 | 99.8062% | 92.6357% | 0% |
| Agent200 | 108.1240 | 100% | 92.6357% | 0% |

Agent200 no introduce tardíamente el fenómeno: el problema ya está presente en
Agent50 y el PWM medio de Agent200 es menor que el máximo anterior. En los 24
episodios `steadyRest` propios, los cuatro checkpoints conservaron 100% de PWM
no cero; sus PWM medios fueron 124.5333, 104.0000, 107.7333 y 115.7333.

## 5. Comandos/pruebas ejecutados y resultados exactos

```matlab
checkcode(file,'-id')
runtests('tests/no_glove/testNoGloveStage7qCommandAttribution.m')
runtests({'tests/no_glove/testNoGloveStage7qCommandAttribution.m', ...
          'tests/no_glove/testNoGloveStage7pInterfaceDiagnostic.m'})
runtests('tests/no_glove','IncludeSubfolders',true)
run_no_glove_stage7q_command_attribution(struct( ...
  'resultsRoot', ...
  'C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7q_artifacts\stage7q_final'))
```

Resultados:

```text
checkcode 7Q                  = 5 archivos, 0 diagnósticos
pruebas deterministas 7Q      = 9/9 PASS
preflight launcher 7Q+7P      = 17/17 PASS
regresión completa no-glove   = 194/194 PASS
fallos/incompletas            = 0/0
launcher canónico             = PASS
resultado científico          = distributedOrUnresolved
```

Replay de los cuatro actores:

| Actor | máximo batch vs log | máximo serial vs batch, 8 estados | discrepancias PWM |
|---:|---:|---:|---:|
| 50 | `1.847743988e-6` | `2.682209015e-7` | 0 |
| 100 | `1.575797796e-6` | `4.172325134e-7` | 0 |
| 150 | `1.803040504e-6` | `4.172325134e-7` | 0 |
| 200 | `1.773238182e-6` | `3.874301910e-7` | 0 |

La comprobación central de gradientes encontró una discrepancia entre 7 680
derivadas auditadas: Agent100, fila de corpus 975, M4, entrada 25. Las pendientes
unilaterales fueron distintas, demostrando un cruce de kink ReLU; el gradiente
analítico coincidió con una de las ramas dentro de tolerancia. Se registraron
`centralFailureCount=1`, `nonsmoothExceptionCount=1` y
`unexplainedFailureCount=0`. Los otros checkpoints tuvieron cero fallos
centrales. Este diagnóstico unilateral solo valida el gradiente; no participa
en la atribución científica.

Hubo dos detenciones seguras antes del resultado canónico:

1. un backend Java incompatible para SHA-256 se detuvo antes de crear salida o
   cargar actores; PowerShell confirmó el hash preinscrito y se reutilizó el
   backend validado por etapas anteriores;
2. el directorio parcial `2026-08-30_16-40-25-138` contiene solo preflight y no
   es evidencia científica; la ejecución se detuvo ante el kink antes de
   analizar o emitir clasificación.

## 6. Métricas y artefactos generados

Directorio canónico:

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7q_artifacts\stage7q_final\2026-08-30_16-44-30-296
```

Hash del manifiesto:

```text
SHA256(manifest.json) = 4ECA54839AC8CF60A48B5F6E13ABDEB386BEDA9A851C7421EE782F50D6EDF57F
```

Artefactos principales:

| Artefacto | SHA-256 |
|---|---|
| `stage7q_results.mat` | `D7F63CA60A8F4556DED3ECF9669D15B3C5E01886F1D34A40A778C5BDEDECF56F` |
| `gradient_block_summary.csv` | `70CABEA053B171A5DF0295282F1A382E013B5F2121D602C4A91D62ABA25A4BFD` |
| `block_association_summary.csv` | `4D69D72121CA0205BC4F58BBDD6CDC2AABB931FB3AC3E5345945D532A71628D0` |
| `temporal_contribution_summary.csv` | `F533251E421FFE1687E8020EBE3FA0BC3B228CEAC9D2E10E8C29BBF30C34BCDF` |
| `prior_action_summary.csv` | `9105F93D3C43173281DA40F0198BF7C87DDC8ACEA72AE326B2537E4EF5E0D331` |
| `shared_checkpoint_summary.csv` | `C7BB68964F22B9ECFD4447DAC8BE66C2E1A8393009A4E512D17994181B34762E` |
| `decision_audit.csv` | `61278C098DF2098653DB12D535C2A6C64DC8B032DB872230EBEE182C727A520D` |
| `input_inventory.csv` | `19E068E231CFD7AFDF2113B888595DDFB0694605B430768B74D58F5891C1AE75` |

El manifiesto contiene los hashes de los 19 artefactos. El comando completo está
en `reproducible_command.txt`.

## 7. Riesgos, supuestos y cuestiones no resueltas

- `q` y `q_ref` son casi colineales en demanda cero; sus `R2` no permiten
  atribución separada.
- La sensibilidad EMG describe features estandarizadas, no amplitud física ni
  causalidad de un canal muscular.
- La contribución lineal media se degrada en algunos saltos grandes, aunque la
  mediana es precisa. No debe extrapolarse como descomposición global.
- La correlación con acción previa no demuestra que la memoria de acción sea la
  causa: también puede reflejar estados persistentes y la propia dinámica.
- 6 650 componentes Agent200 apuntan hacia fuera en un límite. La seguridad los
  bloquea; no se interpretan como corriente eléctrica ni como fallo de la capa.
- La política continúa produciendo comandos altos en reposo. 7Q descarta una
  causa única bajo los gates preinscritos; no resuelve el problema.
- Agent7250 permaneció intacto, no fue cargado y conserva SHA-256
  `0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54`.

## 8. Confirmación de hardware

No se usó hardware, Myo, guante, puertos COM ni PWM físico. No se construyó
`Env`, no se ejecutó simulador, planta, DTW o entrenamiento. `simMotors=true`
solo describe la configuración congelada de los episodios leídos.

## 9. Commits de la etapa

```text
61766bf3 Preregister Stage 7Q command attribution
417db38b Add Stage 7Q offline command attribution
c0a4698b Use validated hashes for Stage 7Q parents
483135ff Qualify Stage 7Q gradients at ReLU kinks
```

El informe final se añade en un commit separado. No se hizo push.

## 10. Propuesta precisa para la siguiente etapa — no ejecutada

Proponer **ETAPA 7R: atribución EMG con pares de estados reales emparejados**:

1. mantener congelados `intentMarkov60`, Agent50/100/150/200 y el corpus 7Q;
2. construir pares dentro y entre episodios usando únicamente estados reales,
   emparejados por `q`, `q_ref`, `Δq` y acción previa, sin reemplazar bloques;
3. medir si diferencias de features EMG durante reposo predicen dirección y
   magnitud del comando una vez restringido el contexto mecánico;
4. separar familias WMoos y orden de canales, sin tratarlas como amplitud física;
5. verificar estabilidad por checkpoint y por fuente `acceptance/steadyRest`;
6. solo si una familia EMG mantiene efecto consistente y soporte suficiente,
   proponer después una única ablación offline aguas arriba.

No se autoriza entrenamiento, smoke, piloto, campaña ni modificación de la capa
de seguridad. ETAPA 7R no se ejecutó durante 7Q.
