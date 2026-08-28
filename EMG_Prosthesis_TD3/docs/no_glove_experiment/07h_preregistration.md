# ETAPA 7H - pre-registro de penalización causal durante hold

Fecha de pre-registro: 2026-08-28.

Este documento fija la hipótesis, el factor experimental, los parámetros y
los gates antes de implementar la recompensa, entrenar agentes o inspeccionar
resultados de ETAPA 7H. La autorización se limita al smoke emparejado descrito
aquí. No autoriza piloto 2k, campaña, hardware ni DTW.

## Hipótesis

ETAPA 7F mostró que incrementar globalmente `w_u` de `0.01` a `0.05` reduce
esfuerzo de aceptación, pero no elimina comandos de reposo. ETAPA 7G mostró
que un umbral global de acción capaz de suprimir reposo perdería cerca de 81%
de los comandos de movimiento del candidato.

La hipótesis 7H es más estrecha: añadir esfuerzo solo cuando la referencia
está detenida y la posición de decisión ya está cerca del objetivo puede
reducir PWM innecesario en reposo sin penalizar el esfuerzo requerido durante
movimiento o corrección lejos del objetivo.

## Contrato causal y fórmula

`q_decision,t` es el encoder normalizado presente en `state_t`, antes de
aplicar `u_t`. `q_ref,t` y `v_ref,t` son la posición y velocidad de referencia
visibles en el mismo estado. No se permite usar EMG leída para `state_(t+1)`.

```text
e_hold,t = q_decision,t - q_ref,t

I_hold,t = 1[max_m |v_ref,t,m| <= epsilon_v]
           * 1[mean_m(e_hold,t,m^2) <= epsilon_q2]

r_7H,t = r_base,t
         - w_hold * I_hold,t * mean_m(u_eff,t,m^2)
```

El vector de reward resta el término por componente y la reward escalar sigue
siendo la media de cuatro motores.

Parámetros fijados:

```text
epsilon_v  = 1e-12
epsilon_q2 = 1e-4
w_hold control   = 0.00
w_hold candidato = 0.20
```

`epsilon_q2=1e-4` equivale a RMS agregado de error normalizado `0.01`. El
indicador se calcula en el estado de decisión para que la acción actual no
pueda cambiar retroactivamente si el término se aplica en esa transición.

## Factor único y condiciones congeladas

Ambas variantes usarán una nueva ruta explícita de reward con idéntica fórmula
y diagnósticos. La única diferencia entre perfiles, aparte de rutas de salida,
será `intentHoldActionWeight`:

```text
control   = 0.00
candidato = 0.20
```

Valores compartidos:

```text
w_q=1.00, w_v=0.00, w_u=0.05, w_du=0.05
w_sat=0.02, u_soft=0.90
referenceSource=emgIntent
observationVariant=intentMarkov60
actionInterfaceVariant=baselineQuantized
TD3 feedforward 60 -> 64 -> 64 -> 4
simulationPositionSafety=clipTrajectoryOutput, enabled
simMotors=true
```

Se congelan calibración, datasets, decodificador, `q_ref`, target, estado,
cuantización, simulador, seguridad, arquitectura y todas las demás opciones.
La capa de seguridad permanece independiente de la reward.

## Protocolo emparejado

```text
agentes nuevos                  = 2
checkpoint inicial             = ninguno
seed de entrenamiento          = 11
episodios por variante         = 200
checkpoints                    = 50, 100, 150, 200
seed de evaluación             = 7601
simulaciones de aceptación     = 50
simulaciones de reposo         = 24
```

Antes de entrenar se exigirá:

1. pruebas unitarias de casos manuales y contrato temporal;
2. episodio simulado completo con logs finitos;
3. igualdad numérica exacta entre la ruta base y la nueva ruta cuando
   `w_hold=0`;
4. igualdad exacta de inicialización de actores;
5. igualdad de contenidos de datasets y calibración;
6. perfiles iguales salvo `w_hold` y rutas necesarias;
7. `newTraining=true`, checkpoint vacío y replay buffer reiniciado.

Si falla una condición, el entrenamiento queda prohibido.

## Gates pre-registrados

Validez y seguridad:

```text
NaN/Inf                                      = 0
episodios con violación de posición          = 0
intervenciones de seguridad candidato        <= control
```

Aceptación:

```text
trackingMSE_candidato / trackingMSE_control   <= 1.05
actionL2_candidato                           <= actionL2_control
deltaActionL2_candidato                      <= deltaActionL2_control
deltaActionL2_candidato                      <= 0.257108
saturationFraction_candidato                 <= control
saturationFraction_candidato                 <= 0.196043
flags funcionales Motor 2                    = 0
flags funcionales agregados M1/M3/M4         = 0
```

Reposo:

```text
windowAnyCommandFraction                     <= 0.01
saturationFraction                           = 0
falseActivationFraction del decodificador    <= 0.01
restHoldActiveFraction                       >= 0.90
```

`restHoldActiveFraction` verifica exposición a la intervención; si es menor,
la prueba se clasificará como soporte de hold insuficiente en lugar de afirmar
que la hipótesis fue refutada.

## Clasificación pre-registrada

Orden de clasificación:

1. `safetyOrValidityFailure` si falla finitud o límites;
2. `holdExposureInsufficient` si el candidato no activa `I_hold` en al menos
   90% de las ventanas de reposo;
3. `trackingRegression` si tracking excede el límite;
4. `restGateFailed` si persisten comandos/saturación o activación falsa;
5. `functionalGateFailed` si hay flags de motores;
6. `dynamicRegularityGateFailed` si esfuerzo, variación, saturación o
   intervenciones empeoran;
7. `holdConditionedRegularizationSupported` solo si pasan todos los gates;
8. `ablationUnresolved` para cualquier combinación restante.

Pasar el smoke no identifica una causa raíz y no autoriza automáticamente un
piloto. Fallarlo no demuestra que toda reward condicionada a reposo sea
inválida.

## Exclusiones

- No se carga ni reutiliza Agent7250 o un agente 7F para entrenar.
- No se cambia el umbral `0.05` ni los niveles PWM.
- No se introduce watchdog como sustituto de la seguridad.
- No se modifica el decodificador ni se interpretan features WMoos como
  amplitudes físicas.
- No se calcula DTW.
- No se usa hardware, puerto COM, PWM físico, guante ni Myo real.
- No se inicia piloto o campaña aunque el smoke pase.
