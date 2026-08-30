# ETAPA 7O — preinscripción de auditoría contrafactual de bits 61/62

Fecha de preinscripción: 2026-08-29.

Esta preinscripción se crea antes de cargar los actores para calcular efectos
contrafactuales. ETAPA 7O es exclusivamente offline: no entrena, no instancia
`Env`, no simula la planta y no modifica reward, cuantización, TD3, simulador ni
capa de seguridad.

## 1. Evidencia de entrada congelada

Artefacto canónico ETAPA 7N:

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7n_artifacts\stage7n_corrected_final\2026-08-29_07-34-46-814
manifest SHA-256 = 082DADB41DAA1DAB6AE2B5E02AE15191479410F10B5DF0398837814BFC53D480
result              = PASS
scientificResult    = actionRegularityGateFailed
hardwareUsed        = false
```

Checkpoints primarios congelados:

```text
estado 60, Agent200
path   = C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7n_artifacts\stage7n_final\2026-08-29_07-20-16-394\control60_training\2026-08-29_07-20-29-220\seed_11\training\26-08-29 07 20 53\Agent200.mat
SHA256 = 440F003450A368A13A0E5DACB04FD7755BB929033EB879B217E47F32B5AA185E

estado 62, Agent200
path   = C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7n_artifacts\stage7n_final\2026-08-29_07-20-16-394\candidate62_training\2026-08-29_07-23-27-451\seed_11\training\26-08-29 07 23 47\Agent200.mat
SHA256 = 2A51F0F1F8800C2F44F6C632109EBB0A3E146907496A47EA0DED85450AB92E69
```

Checkpoints secundarios del actor 62, sin capacidad de sustituir Agent200:

```text
Agent50   B4E9D705EB713DC1507B0FD55785A24186C239C0BF263F38E06E3E0FE792BA55
Agent100  3F82182EE3F99FBEF23D327A76900B13A9B481FF9EBB707F66AD4D74D2F7F17F
Agent150  301231C840DF2E6704149AF380D496B84575D66C50AB422737C753A9287850FC
```

No se cargarán Agent7250, Agent200 histórico de estado 60 como punto de partida,
buffers para continuar aprendizaje ni ningún crítico para entrenar. El actor 60
Agent200 se evalúa solo como referencia offline sobre el mismo prefijo.

## 2. Corpus fijo y trazabilidad

El corpus se construirá a partir de `stateLog` e `intentProvenanceLog` de la
variante 62 de ETAPA 7N:

1. 200 episodios publicados durante entrenamiento del candidato;
2. 50 episodios de aceptación de su checkpoint 200;
3. 24 episodios de reposo de su checkpoint 200.

Cada archivo será inventariado con SHA-256. Se verificará antes de usarlo:

- `referenceSource="emgIntent"`;
- `observationVariant="intentDeclaredRestHoldMarkov62"`;
- estado finito N×62;
- bits binarios;
- procedencia causal schema 2;
- bits 61/62 iguales al replay independiente;
- las primeras 60 dimensiones no se alteran entre contrafactuales.

Las filas se ordenarán por fuente, episodio y paso. Para evitar que el tamaño de
un contexto domine el resultado se conservarán como máximo 512 filas por
contexto, seleccionadas mediante índices uniformemente espaciados y
deterministas. No se usa aleatoriedad.

## 3. Contextos preinscritos

Los contextos son exclusivos y se asignan con esta prioridad:

1. `initialRest`: primer estado de cada episodio;
2. `driftAfterLatch`: `declaredRest=1`, `holdLatch=1` y MSE de posición `>1e-4`;
3. `latchActive`: `declaredRest=1`, `holdLatch=1` y MSE `<=1e-4`;
4. `declaredRestFar`: `declaredRest=1`, `holdLatch=0` y MSE `>1e-4`;
5. `nearBeforeLatch`: `declaredRest=1`, `holdLatch=0` y MSE `<=1e-4`;
6. `lowActivityCountdown`: procedencia alineada con
   `lowActivityCountdown=true`;
7. `intentionalMovement`: estado restante con `declaredRest=0`,
   `holdLatch=0` y `max(abs(v_ref))>1e-12` o gate EMG activo;
8. `uncategorized`: auditoría de cobertura; no entra en la clasificación.

Si un contexto solicitado no existe en los logs se reportará con conteo cero;
no se fabricarán estados para rellenarlo.

## 4. Contrafactuales

Para cada prefijo fijo `x=s(1:60)` se construirán:

```text
s00 = [x,0,0]
s10 = [x,1,0]
s11 = [x,1,1]
s01 = [x,0,1]
```

Contrastes causales primarios:

```text
restEffect  : s00 -> s10
latchEffect : s10 -> s11
```

La combinación `s01` no es alcanzable por el contrato 7M. Se evaluará como
`oodInvalid01`, separada en tablas y manifiesto, sin participar en la
clasificación ni recomendación principal.

El actor 60 recibirá exactamente `x`; su salida se publicará como referencia,
no como efecto de bits. Los actores 62 de episodios 50/100/150 se evaluarán sobre
el mismo corpus fijo y únicamente como evolución secundaria. Agent200 queda
preseleccionado como resultado primario.

## 5. Cuantización congelada

No se cambia `baselineQuantized`:

```text
maxPwm             = 255
activationThreshold= 0.05
commandLevels      = [0,64,96,128,160,192,224,255]
```

La auditoría llamará `quantizeBaselineAction` sin editarla. Para cada acción se
guardarán acción cruda, acción efectiva y PWM firmado.

## 6. Métricas por motor, contexto y contraste

Para `u_off,pwm_off -> u_on,pwm_on`:

```text
deltaRaw              = u_on-u_off
deltaAbsRaw           = abs(u_on)-abs(u_off)
deltaAbsPwm           = abs(pwm_on)-abs(pwm_off)
rawChanged            = abs(deltaRaw)>1e-6
rawMagnitudeReduced   = deltaAbsRaw < -1e-6
rawMagnitudeIncreased = deltaAbsRaw > +1e-6
pwmChanged            = pwm_on ~= pwm_off
quantizationLevelChanged = abs(pwm_on) ~= abs(pwm_off)
zeroTo64              = abs(pwm_off)==0  y abs(pwm_on)==64
sixtyFourToZero       = abs(pwm_off)==64 y abs(pwm_on)==0
saturationEntry       = abs(u_eff,off)<0.95 y abs(u_eff,on)>=0.95
saturationExit        = abs(u_eff,off)>=0.95 y abs(u_eff,on)<0.95
beneficialPwm         = deltaAbsPwm<0
adversePwm            = deltaAbsPwm>0
```

Se reportarán medias absolutas, máximos, fracciones y conteos. “Beneficioso”
significa reducir magnitud/PWM en el sentido de reposo; sensibilidad sin cambio
PWM no se llamará beneficiosa.

## 7. Gradientes

Se calculará mediante `dlgradient`:

```text
G(m,b) = d actorOutput_m / d state_b,  b in {61,62}
```

Los gradientes se publicarán por fila, motor, bit y contexto. Se cruzará una
muestra determinista contra diferencia central con `h=1e-4`; tolerancia
`max(1e-5,1e-3*abs(gradiente))`. Un gradiente local no implica cambio de PWM ni
beneficio.

## 8. Clasificación preinscrita

Solo Agent200 y los contrastes `restEffect`/`latchEffect` participan.
`uncategorized` y `oodInvalid01` se excluyen.

```text
rawSensitive = algún rawChanged o abs(gradiente)>1e-6
pwmSensitive = algún pwmChanged
netBenefit(c,m,k) = fraction(beneficialPwm)-fraction(adversePwm)
```

Se calcula `macroNetBenefit` como media con igual peso de todas las celdas no
vacías contexto×motor×contraste. Margen de dominancia: 0.05.

Jerarquía exacta:

1. `bitsIgnored`: `rawSensitive=false`;
2. `bitsRawOnly`: `rawSensitive=true` y `pwmSensitive=false`;
3. `bitsBeneficial`: `macroNetBenefit>=0.05` y ninguna celda tiene
   `netBenefit<=-0.05`;
4. `bitsAdversarial`: `macroNetBenefit<=-0.05` y ninguna celda tiene
   `netBenefit>=0.05`;
5. `bitsContextDependent`: cualquier otro resultado con cambios PWM.

La presencia de direcciones opuestas por contexto, motor o contraste conduce a
`bitsContextDependent`, aunque la media global sea favorable.

## 9. Recomendación preinscrita

- `bitsIgnored`, `bitsRawOnly` o `bitsAdversarial`: recomendar descartar el
  estado 62 y volver a `intentMarkov60`;
- `bitsBeneficial`: conservar 62 solo como hipótesis y proponer un nuevo smoke
  cerrado de 200 episodios; nunca piloto largo;
- `bitsContextDependent`: no autorizar nuevo entrenamiento y volver
  provisionalmente a `intentMarkov60` hasta diseñar una intervención única que
  resuelva los contextos adversos.

En todos los casos se registran, sin corregir en 7O:

- discontinuidad PWM `0 -> 64`;
- pequeña penalización específica de saturación;
- gate común de reposo;
- numerosas intervenciones de seguridad de ETAPA 7N.

## 10. Límites y detención

El launcher debe fallar si detecta entrenamiento, `Env`, simulación, hardware,
Myo, guante, DTW, cambio de cuantización o hash inesperado. Generará CSV, MAT,
JSON, hashes, comando reproducible e informe offline.

Al finalizar se detendrá. No se autoriza ni ejecuta piloto de 2 000 episodios,
campaña ni nuevo smoke dentro de ETAPA 7O.
