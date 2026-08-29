# ETAPA 7J — Preinscripción del contrato causal de hold enclavado

Fecha: 2026-08-28  
Rama: `experiment/no-glove-intent-control`  
Base `main`: `6b213ba5c624fffb3f1094585c67d9c8ac43b737`  
Padre canónico 7I: `C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7i_artifacts\stage7i_final\2026-08-28_17-54-13-526`

Esta preinscripción se compromete antes de calcular cualquier salida nueva del
latch 7J. Se conocen y preservan los resultados publicados de 7I; no se conocen
aún cobertura, exposición ni clasificación del contrato enclavado.

## 1. Alcance

ETAPA 7J es exclusivamente offline. Reutiliza las 31 220 ventanas de los 548
episodios congelados de 7H que 7I ya validó y reconstruyó desde `state_t`.

No se permite:

- entrenar o crear una política;
- cargar Agent200 o Agent7250;
- crear `Env` o invocar el simulador;
- invocar una función de reward;
- cambiar estado, target, reward, cuantización, seguridad o simulador;
- calcular DTW;
- ejecutar piloto, campaña o hardware.

El latch es una transformación diagnóstica de logs. Aunque resulte soportado, no
se implementará en el entorno durante esta etapa.

## 2. Variables causales

De cada estado `intentMarkov60` validado por 7I se conservan:

\[
E_t=\operatorname{mean}_{m=1}^{4}(q_{m,t}-q_{ref,m,t})^2,
\qquad
V_t=\max_m |v_{ref,m,t}|.
\]

Constantes fijas:

- tolerancia de velocidad `epsilon_v = 1e-12`;
- tolerancia de entrada `epsilon_entry = 1e-4`;
- corrección lejana `epsilon_far = 2.5e-3`;
- `n_on = 1` ventana;
- liberación al primer paso móvil, `n_off = 1`.

No se barrerán estas constantes. Elegir `n_on=1` es necesario para comprobar la
hipótesis concreta de autoextinción observada en 7I: la condición debe poder
enclavarse en el primer estado válido antes del comando asociado.

## 3. Máquina de estados

Cada episodio y fuente se procesan por separado, en orden creciente de `step`.
El latch se reinicia a cero en su comienzo. Se define:

\[
S_t=\mathbb{1}[V_t\le\epsilon_v],
\qquad
N_t=\mathbb{1}[E_t\le\epsilon_{entry}].
\]

La actualización causal es:

\[
L_t=
\begin{cases}
0, & S_t=0,\\
1, & S_t=1\land N_t=1,\\
L_{t-1}, & S_t=1\land N_t=0.
\end{cases}
\]

Para el primer paso, `L_0=0`. La entrada ocurre solo con referencia detenida y
error pequeño. Una vez activo, el latch no usa el error posterior para
desactivarse; se libera exclusivamente cuando vuelve el movimiento de
referencia. No se lee ninguna muestra futura.

La condición instantánea publicada por 7H/7I es:

\[
H_t=S_tN_t.
\]

Las ventanas recuperadas por memoria son `L_t=1` y `H_t=0`.

## 4. Estratos congelados

Se preserva literalmente el estrato conservador de 7I:

- reposo: todas las ventanas `steadyRest`;
- corrección lejana: ventanas de `training` o `acceptance` con `S_t=1` y
  `E_t>=2.5e-3`.

No se reclasificará una ventana lejana como reposo por el hecho de que el latch
esté activo.

Como auditoría causal adicional, cada segmento detenido comienza en el primer
paso del episodio o tras un paso móvil. Un segmento es `farStarted` si su MSE
inicial es al menos `epsilon_far`. La convergencia ocurre en su primer paso con
`E_t<=epsilon_entry`. Se considera activación prematura cualquier `L_t=1` dentro
de un segmento `farStarted` antes de esa convergencia.

## 5. Métricas y gate

Para cada variante:

\[
C^{latch}_{rest}=\operatorname{mean}_{t\in rest}(L_t),
\]

\[
X^{latch}_{far}=\operatorname{mean}_{t\in far}(L_t).
\]

También se reportarán:

- cobertura instantánea de 7I y ganancia absoluta del latch;
- fracción y número de ventanas recuperadas por memoria;
- número de entradas y liberaciones;
- episodios de reposo con cobertura total y cobertura mínima por episodio;
- activaciones prematuras en segmentos `farStarted`;
- acción registrada expuesta al término de hold:

\[
A_L=\operatorname{mean}\left[L_t\operatorname{mean}_m(u_{eff,m,t}^2)\right],
\]

  usada solo como métrica contrafactual, sin invocar ni cambiar el reward;
- intervención de seguridad y PWM dentro de ventanas recuperadas.

Gate primario, evaluado en la candidata y reportado también para el control:

1. `C_rest_latch >= 0.90`;
2. `X_far_latch <= 0.05` usando el mismo estrato de 7I;
3. cero activaciones prematuras antes de converger en segmentos `farStarted`;
4. replay instantáneo exactamente consistente con 7I;
5. equivalencia por prefijos: modificar o truncar el futuro no cambia `L_t` en
   el prefijo;
6. inputs y hashes preservados;
7. cero NaN/Inf y cero uso de agente, `Env`, simulador, reward, DTW o hardware.

Clasificación, en este orden:

- si falla causalidad o integridad: `latchedHoldAuditInvalid`;
- si cobertura de reposo es menor a 90%:
  `latchedHoldCoverageInsufficient`;
- si exposición lejana excede 5%:
  `latchedHoldNotSeparableFromFarCorrection`;
- si existen activaciones prematuras:
  `latchedHoldPrematureCorrectionExposure`;
- si no se recupera ninguna ventana:
  `latchAddsNoSupport`;
- si todo pasa: `offlineLatchedHoldContractSupported`.

No se cambiará el orden después de observar resultados.

## 6. Markov y decisión posterior

Si existe cualquier ventana recuperada, `L_t` contiene memoria que no es igual a
la condición instantánea `H_t`. Una implementación futura deberá hacer explícito
el latch en la observación, por ejemplo:

\[
s_{61}=[s_{60},L_t],
\qquad \dim(s_{61})=61.
\]

ETAPA 7J solo registrará ese requisito. No creará `intentHoldMarkov61`, no
modificará el reward y no entrenará. Si el gate pasa, una etapa posterior deberá
preinscribir por separado la modificación de estado/contrato antes de cualquier
ablación conductual. Si falla, se cancela el latch propuesto en su forma actual.
