# ETAPA 7L — Preinscripción del contrato offline de reposo declarado

Fecha: 2026-08-28  
Rama: `experiment/no-glove-intent-control`  
Base `main`: `6b213ba5c624fffb3f1094585c67d9c8ac43b737`  
Padre canónico 7K: `C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7k_artifacts\stage7k_final\2026-08-28_21-25-50-214`

Esta preinscripción se congela antes de calcular el nuevo latch semántico. ETAPA
7L no reinterpreta ni cambia el resultado de 7J: el contrato geométrico 7J
continúa con `contractSupported=false`. La nueva pregunta es más estrecha: si una
memoria causal condicionada por reposo declarado puede conservar una referencia
cercana sin activarse durante una corrección que empezó lejos.

## 1. Alcance y entradas congeladas

La evaluación es estrictamente offline sobre los 548 episodios y 31 220 estados
de decisión congelados de 7H que ya validaron 7I, 7J y 7K. Se combinarán por una
clave exacta:

`variant, source, episode, repetitionId, step, windowIndex`.

7K aporta `provenance`, la etiqueta causal de cada estado de decisión. 7I aporta
el error de posición de referencia:

\[
E_t = \operatorname{mean}\left((q_t-q_{ref,t})^2\right).
\]

Los hashes de manifiestos, resultados, CSV fuente y 548 episodios se comprobarán
antes y después del análisis. No se carga ningún agente, no se simula la planta,
no se entrena, no se calcula DTW y no se usa hardware.

## 2. Reposo declarado y cercanía

El estado semántico de reposo declarado es:

\[
R_t = [p_t \in \{\texttt{episodeInitialization},
                    \texttt{decoderRest}\}],
\]

donde `p_t` es la procedencia causal reconstruida y validada en 7K.
`activeCountdownZero` queda excluido explícitamente, aunque `v_ref=0`, porque el
gate de intención todavía está activo.

La condición geométrica de entrada es:

\[
N_t = [E_t \leq \theta_{near}], \qquad \theta_{near}=10^{-4}.
\]

El umbral se hereda sin ajuste posterior de 7J. `farCorrection` se conserva solo
como diagnóstico con `E_t >= 2.5e-3`; ya no es un gate de aceptación del nuevo
contrato semántico.

## 3. Máquina causal preinscrita

El bit de memoria `L_t` se reinicia a cero en cada episodio y se actualiza, en
orden temporal, mediante:

\[
L_t =
\begin{cases}
0, & \neg R_t,\\
1, & R_t \land N_t,\\
L_{t-1}, & R_t \land \neg N_t.
\end{cases}
\]

Consecuencias del contrato:

- la inicialización de episodio puede activar el latch si ya está cerca;
- dentro de reposo declarado, una entrada cercana se conserva aunque después el
  error crezca;
- la primera ventana no-rest libera el latch sin latencia, incluida
  `activeCountdownZero` aunque su `v_ref` continúe en cero;
- una corrección que comienza lejos no puede activar el latch hasta observar una
  ventana cercana dentro de reposo declarado;
- episodios, variantes y fuentes no comparten memoria.

La salida instantánea sin memoria es `I_t = R_t AND N_t`. Se denomina
`recoveredByMemory` a `L_t AND NOT I_t`.

## 4. Segmentos `farStarted` y activación prematura

Se conserva la segmentación detenida validada por 7K. Para cada segmento marcado
`farStarted`, la fase previa a convergencia comprende las filas desde el inicio
del segmento hasta, pero sin incluir, la primera fila con `N_t=true`. Si nunca
alcanza cercanía, toda la fase permanece previa a convergencia.

Se define activación prematura como:

\[
P_t = L_t \land \texttt{farStarted}_t
            \land \neg\left(\bigvee_{j\leq t}N_j\right).
\]

El conteo de `P_t` debe ser cero. Esta condición no prohíbe que un segmento
iniciado lejos active el latch después de alcanzar causalmente la región cercana.

## 5. Auditoría de causalidad

La implementación debe satisfacer:

1. ordenación estable por episodio y `step`;
2. reinicio explícito de memoria en cada episodio;
3. cero claves duplicadas o sin pareja entre 7I y 7K;
4. equivalencia prefijo-completo: analizar cualquier prefijo de un episodio
   produce los mismos `L_t` que el análisis completo para ese prefijo;
5. ninguna función usa filas futuras para decidir `L_t`;
6. liberación inmediata: `L_t=false` para toda fila con `R_t=false`;
7. salida finita y etiquetas semánticas completas.

Se reportará también la diferencia contra el latch 7J como diagnóstico. Una
coincidencia en este corpus no convertiría ambos contratos en equivalentes:
7J se definió solo con velocidad cero y geometría; 7L usa la causa del estado de
reposo y excluye de forma contractual el countdown activo.

## 6. Gates preinscritos

El nuevo contrato se considera soportado offline solo si todos pasan:

1. exactamente 548 episodios y 31 220 ventanas emparejadas;
2. cobertura semántica de las ventanas detenidas igual a 1;
3. cobertura del latch en `steadyRest` >= 0.90;
4. fuga no-rest `mean(L_t AND NOT R_t)` igual a 0;
5. activaciones prematuras en fases preconvergencia `farStarted` igual a 0;
6. al menos una ventana `recoveredByMemory`, para demostrar que el estado añade
   soporte respecto a `I_t`;
7. cero mismatches prefijo-completo;
8. inputs y hashes de episodios preservados;
9. cero NaN/Inf, agente, entrenamiento, DTW, simulación científica o hardware.

La exposición geométrica lejana observada después de entrar cerca se reportará,
pero no puede fallar ni aprobar este gate: mide retención dentro de reposo, no
activación durante una corrección que comenzó lejos.

## 7. Clasificación científica

Se aplicará este orden, sin elegir la etiqueta después de observar métricas:

- fallo de integridad, orden o causalidad:
  `declaredRestEligibilityAuditInvalid`;
- cobertura `steadyRest` insuficiente:
  `declaredRestCoverageInsufficient`;
- fuga durante un estado no-rest:
  `declaredRestNonRestLeakage`;
- latch activo antes de converger en un segmento `farStarted`:
  `declaredRestPrematureFarStartedExposure`;
- cero soporte adicional por memoria:
  `declaredRestLatchAddsNoSupport`;
- todos los gates pasan:
  `offlineDeclaredRestEligibilitySupported`.

La última clasificación solo respalda el contrato offline en este corpus. No
demuestra mejora de control, seguridad, reducción de saturación ni validez en
otras semillas o Myo real.

## 8. Límite de la etapa

ETAPA 7L termina con análisis, pruebas, corrida canónica, reproducción y
documentación. Incluso si el contrato queda soportado:

- no se añade el bit a `intentMarkov60`;
- no se implementa un estado de 61 o 62 dimensiones;
- no se modifica reward, target, decoder, referencia, política, cuantización,
  seguridad o simulador;
- no se autoriza entrenamiento, piloto, campaña, DTW ni hardware.

Una etapa futura separada tendría que preinscribir cómo hacer observables tanto
`R_t` como `L_t`; una opción explícita sería una variante de 62 dimensiones
`[intentMarkov60, R_t, L_t]`, pero esa variante no se implementa aquí.
