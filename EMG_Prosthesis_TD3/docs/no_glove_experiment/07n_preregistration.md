# ETAPA 7N — preinscripción del smoke conductual 60 frente a 62

Fecha de preinscripción: 2026-08-29.

Esta preinscripción se crea antes de construir o entrenar las dos políticas de
ETAPA 7N y antes de calcular sus métricas. La etapa queda limitada a un smoke
emparejado de seed única. No autoriza piloto, campaña multisemilla, DTW ni
hardware.

## 1. Pregunta causal y antecedente congelado

ETAPA 7M implementó y verificó el estado observable
`intentDeclaredRestHoldMarkov62`, sin entrenamiento:

- artefacto canónico:
  `C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7m_artifacts\stage7m_final\2026-08-29_00-58-24-394`;
- SHA-256 de `manifest.json`:
  `CDB80438A5BE67E90F2BD58699C38C989815265B26B7F95CC28EA1ED674C7812`;
- commit de implementación 7M:
  `45aab09ba08a6a8d041c732c4fd8dbfde85c02d0`;
- clasificación 7M: `intentDeclaredRestHoldMarkov62Implemented`.

La pregunta preinscrita es si hacer observables los dos bits causales de reposo
declarado y hold enclavado permite que un TD3 nuevo aprenda una conducta no
inferior a la del estado de 60 valores dentro del presupuesto smoke.

No se preinscribe que el estado 62 vaya a resolver la saturación ni que el MSE
sea su causa raíz. Un resultado negativo dentro de 200 episodios tampoco prueba
que los bits sean inútiles: solo niega evidencia suficiente bajo este protocolo.

## 2. Único factor intervenido

Control:

```text
observationVariant = intentMarkov60
stateLength         = 60
s60 = [phi_EMG(40), q(4), Deltaq(4), u_eff,t-1(4), q_ref(4), v_ref(4)]
```

Candidato:

```text
observationVariant = intentDeclaredRestHoldMarkov62
stateLength         = 62
s62 = [s60, declaredRest_t, holdLatch_t]
```

Los índices 61 y 62 son binarios. `declaredRest_t` expresa la decisión causal
del decodificador disponible en el estado actual. `holdLatch_t` se activa solo
cuando existe reposo declarado y

```text
mean((q_t - q_ref,t).^2) <= 1e-4
```

y permanece activo mientras continúe el reposo declarado. No modifica por sí
mismo `q_ref`, `v_ref`, reward, acción o simulador.

Se conservarán idénticos entre variantes, salvo rutas de salida:

- corpus sintético de entrenamiento, aceptación y reposo;
- calibración y contexto de sesión;
- seed de calibración y entrenamiento 11;
- referencia `emgIntent` y sus ecuaciones causales;
- reward `trackingIntentActionRateReward`;
- pesos `w_q=1`, `w_v=0`, `w_u=0.05`, `w_du=0.05`, `w_sat=0.02`,
  `u_soft=0.90`;
- TD3 feedforward y sus hiperparámetros;
- interfaz `baselineQuantized`;
- capa de seguridad de posición de simulación habilitada;
- `simMotors=true`, datos pregrabados y ninguna conexión de guante/hardware.

No se cargarán Agent7250, Agent200, checkpoints previos, buffers de experiencia
ni una base residual. Cada política se creará desde cero.

## 3. Inicialización pareada y límite de interpretación

Ambas variantes usarán `rng(11,"twister")`, el mismo constructor y los mismos
anchos ocultos. La capa de entrada del actor y de los críticos cambia de 60 a
62 entradas; por ello sus tensores no tienen la misma forma y no se exigirá ni
se afirmará igualdad exacta de pesos iniciales.

Se publicarán para cada variante:

- número de arreglos aprendibles y parámetros del actor;
- SHA-256 determinista de todos los parámetros iniciales del actor;
- dimensiones de cada arreglo;
- prueba de reproducibilidad por reconstrucción con la misma seed;
- confirmación de checkpoint de inicio vacío.

La comparación es pareada por generador, seed, arquitectura y procedimiento, no
por identidad tensorial imposible.

## 4. Presupuesto y checkpoints

```text
seed de entrenamiento      = 11
episodios por variante     = 200 máximo
cadencia de checkpoint     = 50 episodios
checkpoints obligatorios   = 50, 100, 150, 200
simulaciones aceptación    = 50 por checkpoint
simulaciones reposo        = 24 por checkpoint
seed de evaluación         = 7601
```

Los ocho checkpoints se publicarán y evaluarán. El checkpoint primario queda
preseleccionado como episodio 200; no se elegirá retrospectivamente el mejor.
Las trayectorias 50/100/150/200 se reportarán completas para mostrar evolución
y variabilidad temporal del smoke.

El launcher deberá rechazar cualquier ejecución que exceda 200 episodios, use
otra seed, omita un checkpoint, cambie el agente inicial o active hardware.

## 5. Métricas preinscritas

En aceptación, por checkpoint y variante:

- `trackingMSE`, `trackingMAE`, `velocityMSE`;
- `actionL2`, `deltaActionL2`, `saturationFraction`;
- métricas anteriores por motor;
- flags de dirección, ausencia de movimiento y límites;
- intervenciones de la capa de seguridad.

En reposo, por checkpoint y variante:

- fracción de componentes y ventanas con comando PWM no nulo;
- PWM absoluto medio;
- `saturationFraction` total y por motor;
- falsa activación del decodificador del corpus;
- NaN/Inf, límites, flags funcionales e intervenciones.

Para el candidato 62, usando los estados y la procedencia causal guardados:

- fracción y conteo de `declaredRest_t=1`;
- fracción y conteo de `holdLatch_t=1`;
- conteos de mismatch frente al replay causal;
- `farStarted`: entrada a reposo declarado con MSE de posición mayor a `1e-4`;
- activaciones prematuras del latch en `farStarted`;
- fracción de comandos durante latch activo e inactivo.

El uso conductual de bits se describirá como asociación observada entre los bits
y las acciones. No se interpretará como importancia causal de red sin una
ablación adicional de entradas.

## 6. Gates preinscritos

Primero se exige validez de ejecución para ambas variantes y todos los
checkpoints:

```text
episodios entrenados por variante                  = 200
checkpoints por variante                           = 4 exactos
checkpoints evaluados en aceptación/reposo         = 4/4 exactos
NaN/Inf                                             = 0
violaciones de posición                             = 0
checkpoint cargado para iniciar entrenamiento      = ninguno
Agent7250/Agent200 usados o cargados                = no
hardware/COM/PWM físico                             = no
mismatch causal de bits 61/62 del candidato         = 0
activación prematura de holdLatch en farStarted     = 0
```

El gate científico primario se aplica al checkpoint preseleccionado 200. Para
declarar `state62BehavioralSmokeSupported`, el candidato debe cumplir todos:

```text
trackingMSE_candidato / trackingMSE_control         <= 1.05
actionL2_candidato / actionL2_control               <= 1.05
deltaActionL2_candidato / deltaActionL2_control     <= 1.05
deltaActionL2_candidato                             <= 0.257108
saturation_candidato / saturation_control           <= 1.05
saturation_candidato                                <= 0.196043
saturación en reposo                                = 0
ventanas de reposo con algún PWM                    <= 0.01
falsa activación del decodificador en reposo        <= 0.01
flags funcionales Motor 2                           = 0
flags funcionales M1, M3 y M4                       = 0
intervenciones de seguridad candidato               <= control
```

Cuando un denominador sea cero, el ratio será 1 si ambos valores son cero e
infinito si solo el candidato es no nulo. Se usa tolerancia numérica `1e-12`.

La clasificación se decidirá jerárquicamente:

1. `executionInvalid` si falla contrato, reproducibilidad o cobertura;
2. `safetyOrFiniteFailure` ante NaN/Inf o violaciones;
3. `state62SemanticFailure` ante mismatch o latch prematuro;
4. `trackingNoninferiorityFailed`;
5. `actionRegularityGateFailed`;
6. `restGateFailed`;
7. `functionalGateFailed`;
8. `state62BehavioralSmokeSupported` si todos los gates pasan;
9. `state62SmokeUnresolved` para cualquier combinación no cubierta.

Los checkpoints 50/100/150 son secundarios y no pueden sustituir al 200. Se
publicará para cada gate cuántos de los cuatro checkpoints lo cumplen.

## 7. Reproducibilidad y detención

La etapa generará un launcher único, manifiesto JSON, perfiles efectivos,
checksums de datasets, calibración, inicializaciones, checkpoints y artefactos,
tablas CSV, resultados MAT e informe offline. Los artefactos grandes vivirán
fuera del repositorio; el código y el informe versionado indicarán su ruta.

Si las pruebas unitarias o el preflight fallan, se prohíbe entrenar. Si una
variante termina y la otra falla, podrá reanudarse exclusivamente desde el run
completo de la primera sin reentrenarlo, preservando sus hashes. No se permite
reanudar entrenamiento desde un checkpoint parcial.

Al finalizar se detendrá ETAPA 7N aun si pasa. No se ejecutarán piloto,
multisemilla, campaña, DTW, Myo ni hardware sin una orden posterior explícita.
