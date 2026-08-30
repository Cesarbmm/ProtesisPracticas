# ETAPA 7P — preinscripción de decisión de estado y diagnóstico de interfaz

Fecha: 2026-08-29.

ETAPA 7P es estrictamente offline. No entrena, no crea `Env`, no ejecuta la
planta simulada, no calcula DTW y no cambia reward, referencia, estado,
cuantización, TD3, simulador ni seguridad. Su objetivo es convertir la decisión
de 7O en una línea base explícita y escoger, con una regla previa, una sola
hipótesis para una ablación futura.

## 1. Evidencia congelada

Resultado canónico 7O:

```text
path   = C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7o_artifacts\stage7o_final\2026-08-29_22-22-07-025
SHA256(manifest.json) = 8173E7ABB11B0FAA7A7CB7AADE74502071E804BBD5F5E4E6145448FCA53254D9
scientificResult      = bitsContextDependent
recommendation        = holdTrainingReturnProvisionallyToIntentMarkov60
```

Padre 7N y actor primario:

```text
7N manifest SHA256 = 082DADB41DAA1DAB6AE2B5E02AE15191479410F10B5DF0398837814BFC53D480
checkpoint         = control60 Agent200
state              = intentMarkov60, 60 entradas
Agent200 SHA256    = 440F003450A368A13A0E5DACB04FD7755BB929033EB879B217E47F32B5AA185E
```

Corpus primario, sin muestreo aleatorio:

```text
acceptance = 50 episodios de control60/Agent200
steadyRest = 24 episodios de control60/Agent200
```

Se excluyen los episodios de entrenamiento: contienen exploración y actores en
evolución, no la política Agent200 congelada. No se cargan los pesos del estado
62 ni Agent7250.

## 2. Decisión de estado

Se registra `intentDeclaredRestHoldMarkov62` como variante rechazada
provisionalmente por `bitsContextDependent`. `intentMarkov60` vuelve a ser el
estado de referencia de la línea sin guante. Esta decisión no autoriza usar el
Agent200 de 60 entradas para continuar entrenamiento: en 7P solo se reproduce su
actor determinista offline.

## 3. Contrato de replay

Cada episodio debe contener estado N×60, acción cruda/efectiva/PWM N×4,
encoders posteriores, referencia, intervenciones de seguridad y procedencia de
intención schema 1. Se comprobará:

- `referenceSource="emgIntent"`;
- `observationVariant="intentMarkov60"`;
- arrays finitos y alineados;
- `referenceHistory(t)=q_ref` visible en `state_t`;
- `trackingPredictionHistory(t)=q` de `state_(t+1)` salvo el último paso;
- replay causal de procedencia `t-1 -> state_t`;
- salida serial de Agent200 igual a `actionLog`;
- salida batch equivalente a serial y cero discrepancias PWM;
- replay de `quantizeBaselineAction` igual a `actionSatLog/actionPwmLog`.

Todos los archivos de entrada se inventariarán con SHA-256.

## 4. Capa A — discontinuidad de interfaz

La interfaz congelada es:

```text
theta = 0.05
maxPwm = 255
levels = [0,64,96,128,160,192,224,255]
```

Se auditará por motor y fuente:

- fracción `abs(u)<theta`;
- fracción en PWM mínimo `abs(PWM)=64`;
- fracción en niveles superiores y saturación;
- distancia `d=abs(abs(u)-theta)`;
- vecindad preinscrita `d<=0.01`;
- histogramas por nivel y signo;
- no linealidad `abs(u_eff-u)`.

Para cada componente observado dentro de la vecindad se hará un único
contrafactual de interfaz, sin cambiar estado ni actor:

```text
si abs(u)<theta:  abs(u_cf)=theta
si abs(u)>=theta: abs(u_cf)=theta-epsilon
sign(u_cf)=sign(u)
epsilon=1e-6
```

Se medirán `deltaRaw`, `deltaEffective`, `deltaPwm`, cruce `0->64` o `64->0` y
`abs(deltaEffective)/abs(deltaRaw)`. El gate esperado exige que todos los casos
sean exclusivamente cruces `0<->64`, con salto efectivo `64/255`.

Se guardará además un barrido canónico firmado en:

```text
theta + [-0.01,-0.005,-epsilon,0,+0.005,+0.01]
```

El punto exacto `theta` debe mapear a PWM 64 y `theta-epsilon` a cero. Esto
demuestra una propiedad matemática de la interfaz; la ocupación observada mide
su exposición real.

## 5. Capa B — gate común, solo asociación

La procedencia causal reconstruirá por estado:

```text
initialRest
declaredRest
lowActivityCountdown
gateActive
```

Con umbral operativo `abs(v_ref)>=0.005`, se medirá cuántos motores están activos
en cada ventana del gate común (0 a 4). Por motor se reportará, condicionado a
`gateActive`:

- referencia activa/inactiva;
- PWM no cero y saturación;
- cercanía a `theta`;
- intervención de seguridad;
- demanda de control cero, definida como
  `abs(v_ref)<0.005` y `abs(q_ref-q)<=1e-4`.

No se construye un contrafactual de gate ni se atribuye causalidad. Un PWM no
cero con referencia de velocidad cero puede ser corrección de posición; por eso
se reporta aparte `zeroControlDemand`.

## 6. Capa C — seguridad, sin modificarla

Cada intervención registrada se estratificará por motor, fuente, estado del gate
y relación con límites normalizados `[0,1]`, usando tolerancia `1e-9`:

```text
outwardBoundary: en límite y PWM apunta hacia fuera
boundaryOther:   en límite sin comando hacia fuera
interior:        encoder observado fuera de los límites no; intervención lejos
                 del límite observado
```

También se reportarán conteo de pasos, conteo acumulado de intervenciones,
comando, saturación y demanda cero. Esta capa es descriptiva: no se reducirá ni
desactivará ninguna protección.

## 7. Regla preinscrita para escoger una sola hipótesis futura

Orden excluyente:

1. `quantizerPriority` si el barrido confirma el salto, todos los
   contrafactuales cercanos son `0<->64` y al menos 1% de los componentes
   observados está a distancia `<=0.01` de `theta`;
2. `gatePriority` solo si no pasa 1, al menos 10% de los componentes durante
   gate activo tiene referencia del motor inactiva y, dentro de ellos, al menos
   10% mantiene PWM no cero;
3. `noAblationSupported` en cualquier otro caso.

La seguridad nunca será escogida para relajarse. Sus resultados solo pueden
motivar en otra etapa una intervención aguas arriba que reduzca comandos
innecesarios conservando intacta la protección.

Si resulta `quantizerPriority`, la siguiente etapa propuesta será una ablación
offline de una sola interfaz alternativa sobre las mismas acciones congeladas,
sin entrenamiento. No se escogerán umbral y niveles en 7P.

## 8. Validación y entregables

- pruebas deterministas de límites, replay, alineación, clasificación y regla de
  selección;
- `checkcode` sin diagnósticos;
- regresión no-glove completa;
- CSV de componentes, barrido, resúmenes de interfaz, gate y seguridad;
- MAT, JSON, manifiesto, hashes y comando reproducible;
- informe `07p_interface_diagnostic.md`.

ETAPA 7P se detiene tras documentar y crear un commit. No autoriza smoke de 200,
piloto de 2 000 ni campaña. No se hará push salvo orden explícita.
