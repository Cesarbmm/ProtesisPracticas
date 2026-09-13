# E2G — Alineación del soporte teacher–planta

2026-09-07. Preregistro anterior a distribuciones nuevas y contrafactuales E2G.
Worktree existente: `C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit`; la grafía
anidada de la solicitud no existe. Rama `experiment/no-glove-paired-reference-td3`,
HEAD `165be049eb41fc41254435181c9857fe0f22ed1c`. Se conservan cambios locales
E2C–E2F. Sin reparación Git, cambio de rama, commit, push, sandbox ni RL.

E2F ya encontró una política privilegiada estable mejor: H5 MSE .0159219916689477,
reward -.0176264005770042; cero ciclos finales, órbitas fijas e inversiones M3.
No se repite la pregunta de controlabilidad ni se rescatan los FAIL históricos.
E1–E1D cerradas; MATEO/SANDRA sellados. Históricos esperados:169/169 tests.

## Pregunta y evidencia estática anterior al contrafactual

¿Por qué el teacher sale de la envolvente de h(q)? La ruta disponible suma
sensores de guante y divide por [4092,2046,1023,2046]. No resta su reposo ni
calibra por sujeto. encoder2Flex toma abs(q), impone un suelo en la zona de
holgura, una recta hasta breakLimit y saturación superior; después divide por
los mismos números. Las constantes inferiores son [1800,900,300,900], gaps
[7500,3650,4000,3550] y breakLimit [26500,11500,8500,9000], en orden M1–M4.
definitions describe explícitamente un modelo simplificado; breakLimit coincide
con límites del firmware. No se ha encontrado calibración pareada que haga
equivalentes unidades ADC y postura mecánica. La búsqueda documental se cerrará
con evidencia y límites explícitos, sin deducir mediciones de comentarios.

La causa computacional candidata es la combinación de un mapa h(q) heredado
con un rango representado por la planta canónica menor que sus anclas de
saturación. El origen físico (recorrido mecánico real, offsets o calibración
del guante) sigue por demostrar. No se atribuirá causalidad exclusivamente al
PWM ni se llamará límite físico universal a una envolvente del grafo E2F.

## Muestra y estimandos

Exactamente los200 episodios y2938 pasos E2B/E2F, sin cargar datasets nuevos.
Teacher_before/after, q0, duración teacher, Ts=.2, muestreoAPI=.14, acciones15,
remapeo baselineQuantized, h(q), reward .01/.05, markov52 y runtime E2A intactos.
Se reutilizan grafos cerrados E2F y trazas originales P2/H5. H5 único oracle;
misma recurrencia exacta, desempate, horizonte truncado y acción previa0.

Distribuciones teacher_after y h(q_after) visitado P2/H5: min,p1,p5,mediana,p95,
p99,max por motor/sujeto/dirección y todas sus combinaciones. Cuantiles por pasos,
interpolación lineal entre estadísticos ordenados, sin toolbox opcional.
Envolvente y cuantiles del conjunto de estados únicos del grafo separados:
no son una distribución temporal ni se fingirá dependencia por sujeto.
Fracciones debajo/dentro/encima y cambios: media temporal por episodio-motor,
episodios por sujeto/lado/motor, media macro de grupos; también fracción bruta.

M2: scatter teacher vs h alcanzable más próximo sobre todo el grafo, error
firmado bestH-teacher y proyección continua sobre envolvente (objetos distintos).
Descomponer suelo del mapa incluso antes de planta, techo empírico vs breakLimit
y zona de holgura. Inventariar avg y límites de curvas sin editar/reajustar.

## Contrafactual único autorizado por evidencia disponible

A ORIGINAL, sin cambios. B PROJECTION por motor: clip(r,h_min,h_max), donde
extremos proceden del grafo E2F cerrado. Justificación: proyección euclídea
mínima en la envolvente escalar de soporte demostrado del simulador; responde
cuánto error solicita valores incompatibles con ESA representación. No es una
calibración física ni garantiza que cada punto interior sea alcanzable.
La proyección de teacher_before y teacher_after se hace sólo en copias locales.

C AFFINE ALIGNMENT sólo si aparece evidencia independiente de al menos dos
posturas emparejadas identificadas por motor en rango no saturado y una
justificación del modelo entre ellas. No usar cuantiles de rendimiento para
ajustar recta. Si falta evidencia, AFFINE_ALIGNMENT_TESTED=NO; no improvisar.

Se autoriza B como diagnóstico aunque la equivalencia física no pueda validarse;
tal limitación hará fallar gateA. No escoger transformación por MSE reducido.

## Comparaciones congeladas

Oracle H5 ORIGINAL reutilizado y verificado; PROJECTED recalculado en200episodios.
Reportar MSE/MAE/reward/componentes, ciclos finales y todos los prefijos,
periodicidad2..8 con pausas, M3reversals, PWM0 movimiento, flat/no-motion y PWM,
por sujeto/motor/dirección usando helpers históricos. Repetir20fijos E2C con
referencia proyectada para comprobar estabilidad bajo target fijo.

Dos comparaciones de suelo: (1) ORIGINAL vs PROJECTED desde EXACTAMENTE los
estados P2 originales, para aislar referencia sin cambiar visitación; (2) suelo
desde estados visitados por cada oracle, descriptivo. Guardar15destinos por paso.
Floor = media macro de min_a|h(q_next)-r|²; no se reutiliza gate50% de E2F.
Evaluar ambas trayectorias oracle contra ambas referencias (tabla2×2); los MSE
propios corresponden a tareas diferentes y no prueban mejora del control original.

Conservación: mean/p95/max|nuevo-original|, fracción modificada, rango por episodio,
ratio rango nuevo/original para rango>1e-12, colapso a constante, diferencia
final-inicial firmada. Cuantiles de cambio son por pasos; medias macro separadas.

## Gates E2G antes de medir

A. Contrato de coordenadas defendible: evidencia independiente de equivalencia
teacher/h(q) en la misma postura o magnitud funcional por motor, con origen de
anclas y correspondencia de canales. Una fórmula heredada y divisores comunes
no cumplen este gate. UNKNOWN de calibración implica FAIL; clipping no lo suple.
B. Target imposible no domina: cero targets fuera de la envolvente tras
transformación (tolerancia1e-12) y bound MSE por fuera <=10% del suelo local en
estados P2. Si ambos cero, ratio=0. Este gate de soporte no basta por sí solo.
C. Oracle estable: cero ciclos finales y órbitas periódicas en200episodios,
cero inversiones M3 y movimiento PWM0;20fijos sin órbitas y q constante en las
últimas20transiciones. No se exige perfección a P2 ni se cambia detector.
D. Variación útil: mediana del ratio de rango temporal conservado >=50% en cada
motor/dirección; aumento de referencias constantes <=5 puntos porcentuales
por motor/dirección; al menos95% de episodios con |r_fin-r_inicio|>.02 conservan
signo no nulo del cambio. Son límites mínimos de no colapso, no calibración.
E.13 tests causales E2A pasan, runtime/state/actor/teacher availability intactos.
F.169 tests históricos y nuevos pasan, hashes y sellados intactos.

Sólo TODOS los gates autorizan REFERENCE_CONTRACT_VALIDATED y preparar
especificación E3A (no ejecutarla). Si alguno falla: REFERENCE_CONTRACT_NOT_VALIDATED,
RL_PILOT_AUTHORIZED=NO y especificar evidencia/calibración faltante. No añadir
transformaciones, redefinir umbrales ni ejecutar training para rescatar resultado.

## Etapas posteriores y entrega

Si PASS, preparar únicamente TD3 histórico, máximo600episodios, split de sujetos
DEVELOPMENT TRAIN/VALIDATION fijado antes de training, checkpoints frecuentes y
comparadoreszero/Agent7250diagnóstico/P2privilegiado/oracleprivilegiado/TD3EMG-only.
Challenger futuro estructural: cuatro cabezas categóricas de15acciones. SAC queda
para una caracterización futura de PWM intermedio/fino. Ninguno se implementa.

EMG no ha demostrado trayectoria continua individual más allá de gesto/fase;
objetivo eventual es apertura/cierre estable condicionado por EMG y estado
mecánico, con glove sólo como teacher durante training. No decoder.
Viewer pasivo de trazas canónicas diferido hasta después de E3A; no sandbox/S4.

Inventario histórico y SHA de este preregistro antes de mediciones; archivos
nuevos exclusivamente E2G. Artefactos CSV/MAT/JSON, scatter exportable, auditoría
de procedencia, tests y verificación independiente. Sin modificar Env, teacher
original, h(q), reward, planta, constantes ni documentación histórica.
