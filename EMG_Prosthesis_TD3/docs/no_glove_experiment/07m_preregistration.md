# ETAPA 7M — Preinscripción de observabilidad causal `intentDeclaredRestHoldMarkov62`

Fecha: 2026-08-29  
Rama: `experiment/no-glove-intent-control`  
Base `main`: `6b213ba5c624fffb3f1094585c67d9c8ac43b737`  
Padre canónico 7L: `C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7l_artifacts\stage7l_final\2026-08-28_21-44-35-302`  
SHA-256 del manifiesto 7L: `32F43B59C4D579649549FFD4ED030531A97C13BD94E1D24F1D3E6AA58F43466B`

Esta preinscripción se congela antes de implementar o ejecutar el smoke de la
nueva observación. ETAPA 7M hace observable el contrato offline respaldado en
7L, pero no modifica reward, referencia, acción, cuantización, simulador o
seguridad. No carga agentes, no entrena, no calcula DTW y no usa hardware.

## 1. Objetivo y límite

Se añadirá, únicamente mediante override, la variante:

\[
s_{62,t}=[s_{60,t},R_t,L_t],
\]

donde:

\[
s_{60,t}=[\phi_{EMG,t}(40),q_t(4),\Delta q_t(4),u_{eff,t-1}(4),
          q_{ref,t}(4),v_{ref,t}(4)].
\]

`legacy44`, `markov52`, `stackedEmg132` e `intentMarkov60` deben conservar sus
dimensiones, índices, límites y conducta. El valor global por defecto seguirá
siendo `markov52`. El decoder seguirá siendo opt-in y la variante 62 requerirá
`referenceSource="emgIntent"`, calibración válida y `simMotors=true`.

No se creará actor o crítico de 62 entradas y no se reutilizarán pesos de
Agent7250 o Agent200.

## 2. Índices y límites

El layout preinscrito es:

| Campo | Índices MATLAB | Longitud |
|---|---:|---:|
| EMG WMoos | 1:40 | 40 |
| encoder normalizado | 41:44 | 4 |
| delta de encoder | 45:48 | 4 |
| acción efectiva anterior | 49:52 | 4 |
| posición de referencia | 53:56 | 4 |
| velocidad de referencia | 57:60 | 4 |
| reposo declarado `R_t` | 61 | 1 |
| memoria de hold `L_t` | 62 | 1 |

Los bits se representarán como dobles exactos en `{0,1}` y su especificación
numérica será `[0,1]`. Las primeras 60 posiciones deben ser idénticas, bit a
bit dentro de tolerancia `1e-12`, a `intentMarkov60` para la misma trayectoria.

## 3. Máquina causal

Se añadirá un umbral específico de observación, registrado en configuración:

\[
\theta_{near}=10^{-4}.
\]

No se reutilizará silenciosamente un coeficiente de reward para determinar el
estado. Para el encoder causal disponible y la referencia que aparecerán en la
misma observación:

\[
E_t=\operatorname{mean}((q_t-q_{ref,t})^2), \qquad
N_t=[E_t\leq\theta_{near}].
\]

La recurrencia es exactamente la de 7L:

\[
L_t=\begin{cases}
0,&\neg R_t,\\
1,&R_t\land N_t,\\
L_{t-1},&R_t\land\neg N_t.
\end{cases}
\]

En `reset`, `q_ref,0=q_0`, la procedencia es
`episodeInitialization`, `R_0=1`, `N_0=1` y por tanto `L_0=1`. La memoria no se
hereda entre episodios.

Después de la inicialización, `R_t=1` únicamente si la transición que produjo
la referencia de `state_t` fue clasificada como `decoderRest`. En particular,
`activeCountdownZero`, `activeSynergyZero`, límites mecánicos y movimiento
fuerzan `R_t=0` y liberan `L_t` en esa misma observación.

## 4. Alineación temporal

La secuencia autorizada para la transición `t` es:

1. `state_t`, incluidos `R_t,L_t`, queda guardado;
2. `action_t` se cuantiza y aplica al simulador;
3. se observa `q_(t+1)` y la nueva EMG;
4. `reward_t` se calcula contra `q_ref,t`, `v_ref,t` y `q_t`;
5. solo después se decodifica la nueva EMG y se produce
   `q_ref,(t+1),v_ref,(t+1)`;
6. se calcula `R_(t+1)` por procedencia y `L_(t+1)` con
   `q_(t+1),q_ref,(t+1)`;
7. se devuelve `state_(t+1)`.

Por tanto, la EMG leída durante la transición no puede cambiar `reward_t` ni los
bits ya visibles al seleccionar `action_t`.

## 5. Logging

La ruta 62 registrará de forma aditiva, en la entrada de procedencia de cada
transición:

- `declaredRestBefore`, `holdLatchBefore` y MSE anterior;
- `declaredRestAfter`, `holdLatchAfter`, `nearTargetAfter` y MSE posterior;
- versión explícita del contrato 62.

Esos campos describen la transición `state_t -> state_(t+1)`. La ruta
`intentMarkov60` conservará el esquema de logging 7K sin esos campos. El archivo
de episodio guardará además el estado final de los bits y el umbral efectivo.
El logging no será entrada del reward.

## 6. Comparaciones y pruebas preinscritas

Se ejecutarán dos entornos simulados emparejados, con la misma calibración,
dataset, acciones deterministas, reward e interfaz `baselineQuantized`:

- control: `intentMarkov60`;
- candidata: `intentDeclaredRestHoldMarkov62`.

La comparación exigirá:

1. diferencia máxima del prefijo de 60 componentes <= `1e-12`;
2. diferencia máxima de reward <= `1e-12`;
3. diferencia máxima de `q_ref` y `v_ref` <= `1e-12`;
4. acciones crudas, efectivas y PWM idénticos;
5. diagnósticos de seguridad idénticos;
6. replay independiente de `R_t,L_t` con cero mismatches;
7. observaciones finitas y dentro de límites;
8. `R_0=L_0=1` y reinicio idéntico entre episodios;
9. cero fuga futura en una prueba con prefijo EMG común y futuros divergentes;
10. una prueba sintética donde `v_ref=0` y la geometría es cercana, pero
    `activeCountdownZero` produce `R=0,L=0`, diferenciándose del contrato
    puramente geométrico.

Las pruebas de regresión deben confirmar 44, 52, 60, 62 y 132 dimensiones.

## 7. Gates de salida

ETAPA 7M será `PASS` solo si:

- el manifiesto 7L conserva `PASS`, contrato soportado y 7J no reautorizado;
- configuración y layout fallan de forma cerrada ante fuente, decoder, longitud
  o umbral inválidos;
- todos los checks emparejados anteriores pasan;
- todas las pruebas específicas y la regresión `tests/no_glove` pasan;
- `checkcode` no reporta mensajes en archivos nuevos o modificados;
- Agent7250 conserva su SHA-256 canónico;
- no hay agente, entrenamiento, DTW, hardware o modificación conductual.

Clasificación de ingeniería prevista si todos pasan:

`intentDeclaredRestHoldMarkov62Implemented`

Si falla dimensión/configuración: `intentDeclaredRestHoldLayoutInvalid`; si
falla alineación o replay: `intentDeclaredRestHoldCausalityInvalid`; si cambia
el prefijo 60, reward, referencia o actuador:
`intentDeclaredRestHoldBehavioralRegression`.

## 8. Condición de parada

Aunque ETAPA 7M pase, termina sin entrenar. No se autoriza una política de 62
entradas, una ablación de reward, piloto, campaña, DTW, Myo real o hardware. La
siguiente decisión deberá basarse en los artefactos de esta etapa y requerirá
una orden nueva.
