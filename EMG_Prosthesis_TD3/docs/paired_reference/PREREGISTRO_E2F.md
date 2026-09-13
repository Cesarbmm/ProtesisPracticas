# E2F — Oracle de controlabilidad y auditoría del espacio de acción

2026-09-06. Preregistro anterior a comparaciones oracle. Worktree existente
`C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit`, rama
`experiment/no-glove-paired-reference-td3`, HEAD
`165be049eb41fc41254435181c9857fe0f22ed1c`. La grafía anidada de la solicitud no
es el directorio existente. E2E recibido/cerrado: 144/144 tests, verificador
independiente PASS, 589 hashes intactos. E2E NOT_SUFFICIENT, E2D NOT_SUFFICIENT,
E2C CHARACTERIZED, E2B FAIL, E0P/E2A PASS permanecen congelados.

No reparación Git, cambio de rama, commit, push, sandbox ni RL. No perfeccionar
P2, otra heurística o decoder. MATEO/SANDRA sellados.

## Pregunta y auditoría estática previa

¿Existe una política con mejor tracking/reward y sin las órbitas conocidas bajo
la planta canónica, Ts=.2 y acciones históricas? El oracle conoce teacher futuro,
es diagnóstico offline privilegiado, no desplegable ni evidencia de información EMG.

La auditoría local previa distingue PWM entero fino aceptado por Controller/firmware
de niveles caracterizados de simulación. No se prueba hardware ni se inventa dinámica
para niveles intermedios. Se documentarán rutas y líneas exactas, limitaciones y
la diferencia entre capacidad del protocolo y movimiento físico útil.

Separabilidad verificada por código: prosthesis_simulator calcula cada columna
con initial_position(i), speeds(i), curva/límites de ese motor; encoder2Flex
transforma columnas por motor; remap cuantiza cada componente con escala255 fija.
Reward = media de -(error_i^2 + .01*u_i^2 + .05*(u_i-uPrevious_i)^2).
No penalización conjunta ni restricción de potencia compartida en este simulador.
Teacher termination fija el horizonte común, no depende de la acción. Por tanto
el óptimo determinista offline se separa en cuatro motores con memoria uPrevious_i.
Esto no prueba independencia mecánica/eléctrica del hardware real.

## Interfaz y parámetros congelados

Acciones por motor: [0,-64,+64,-96,+96,-128,+128,-160,+160,-192,+192,-224,+224,-255,+255].
Este orden es sólo desempate determinista: cero primero, menor magnitud después,
signo negativo antes del positivo en empate exacto. No es un nuevo remapeo.
Raw representativo=PWM/255, verificado a través de baselineQuantized original;
applied efectivo=PWM/255. Ninguna acción fuera de los 15 valores históricos.

Ts=.2, muestreoAPI=.14, Kp2 de comparador, planta patternCurveCanonical, curvas,
límites, h(q), pesos reward, teacher/done/reset, markov52, WMoos y runtime E2A
intactos. No guard E2E ni deadband E2D en el oracle. Actor/critics TD3 intactos.

## Oracle exacto y horizontes

Receding horizon sin descuento (gamma de planificación=1), coste acumulado:

J = suma_k [(h(q_next)-reference_after(k))^2 + .01*u(k)^2 + .05*(u(k)-u_previous)^2].

Cada decisión utiliza teacher posterior actual y futuro, que es exactamente el
target del reward evaluado después del paso. No confundir reference_before usado
por P2 con reference_after usado por su reward. Terminal de planificación V=0;
truncar H al número de pasos teacher restantes sin padding/extrapolación. Aplicar
sólo la primera acción y recalcular en el siguiente paso con acción aplicada previa.
Esta gamma1 finita es un oracle de coste histórico sin descuento, no entrenamiento
TD3 ni afirmación de equivalencia con targets TD3 de otro descuento.

Horizontes únicos **H=[1,2,3,5]**. H1: decisión miope con rate penalty; H2/H3:
valor de uno/dos pasos futuros; H5: un segundo nominal de teacher. **H5 es el
oracle primario para todos los gates**. H1–H3 son ablaciones descriptivas del
horizonte, no candidatos para escoger retrospectivamente otro ganador.

Construir grafo finito exacto de q alcanzable por motor con todas las 15 acciones,
partiendo de q0 y estados de comparadores E2B zero/P2/Agent7250 y los pares fijos
E2C. Cierre iterativo hasta no encontrar nuevos doubles q; claves bit-exactas.
Cada arista se obtiene con la API canónica real, sin suavización/interpolación.
Algunos comandos son HOLD y distintas acciones pueden compartir destino. Mantener
todos: difieren en action/delta penalty. Máximo técnico10000 estados por motor;
si no cierra, registrar límite y no afirmar optimalidad ni cambiar a aproximación
sin dejar inconclusa esa prueba. Guardar tabla completa y hashes, verificar cierre.

Programación dinámica exacta sobre (índice_q, índice_acción_previa), coste
independiente por motor. Aplicar Bellman con las 15 acciones; factor1/4 común no
cambia argmin. No enumerar 15^4 acciones conjuntas ni usar beam search mientras
la separabilidad verificada permita DP. Contrastar H1/H2/H3 en ejemplos con
enumeración exhaustiva independiente y comprobar suma de óptimos por motor.

## Muestra y métricas

Mismos 200 episodios DEVELOPMENT de E2B, q0/teacher_before/after, duración teacher
y uPrevious0. Reutilizar trazas E2B de zero/P2/Agent7250 como comparadores y verificar
sus transiciones/reward con planta canónica; Agent7250 sigue sólo diagnóstico.
No cargar nuevamente checkpoint, EMG/guante original ni abrir sujetos sellados.
P2 esperado MSE .025400336373607925, reward -.03272837710980499, ciclos2, M3rev0;
zero MSE .09270421488254463. No comparar checkpoint con su historia de training.

Guardar por H y comparador: trackingMSE, MAE, reward media/total y contribuciones,
actionL2, deltaActionL2, saturación, PWM, correlación, responseRange, flat_response,
action_no_motion, ciclos finales y ventanas, trayectorias periódicas, inversiones
M3 y movimiento con PWM0. Por episodio/motor, sujeto, dirección y macro como E2B:
media temporal, episodios por sujeto/lado, media de20grupos. Métricas indefinidas
se conservan/contabilizan, no se reemplazan por cero. Un grupo degradado si MSE
o reward empeora>5%; deterioros relativos con denominadores absolutos y tolerancia1e-12.

## Alcanzabilidad: estimandos definidos antes de medir

Para cada paso teacher, motor y estado q_before visitado, evaluar las15 acciones
al MISMO reference_after, independiente de su coste de acción. Exportar q_before,
PWM, q_next, h(q_next), error firmado/absoluto/cuadrado, error del estado actual
y flags de mejora. Guardar todos los endpoints; no usar [0,1] como encoder.

BEST_ONE_STEP_ERROR = mínimo error absoluto entre15 destinos, incluido HOLD0.
MINIMUM_REACHABLE_ERROR = media macro de BEST_ONE_STEP_ERROR, acompañada por su
MSE, percentiles/máximo y mínimos globales para evitar confundir media con mínimo.
REACHABLE_TARGET_FRACTION principal = fracción de pasos con algún destino que
mejora estrictamente error absoluto actual en>1e-12. Reportar por separado
WITHIN_005_REACHABLE_FRACTION = fracción con BEST_ONE_STEP_ERROR<=.05; .05 es
sólo banda diagnóstica de cinco puntos de h/teacher, no nueva deadband/control.

Estos estimandos se calculan en estados de cada controlador, no sólo de H5.
Menor fracción de mejora puede significar que el controlador ya está cerca del
target, no necesariamente mala resolución. Distinguir estados ya en banda.
El error mínimo de un paso es un límite local desde ese estado; no demuestra
imposibilidad global en varios pasos. Además describir fracción de todos los
comandos activos que produce HOLD y número de endpoints únicos.

## Órbitas y casos fijos

Exportar ambos episodios BLANCA1cierreM3 e IVANNA104aperturaM4, todos los H.
Repetir los20replays E2C de referencia fija, 100 pasos, mismos q0/referencias;
OFF/P2 fijo histórico es comparador. Oracle sólo consulta la referencia fija
replicada hasta el horizonte restante, sin otras intervenciones.

Conservar detector histórico de cuatro transiciones/PWM alternos no0, tolerancia
encoder1e-9 y amplitudh>.05, sobre final y todos los prefijos. Adicionalmente,
periodicidad del estado (q_before,previousAppliedPWM) de periodo mínimo2..8,
al menos cuatro repeticiones, rangoh>.05 y movimientos en ambos sentidos.
Para episodios cortos evaluar cola4p si hay longitud suficiente; para fijos,
últimas32decisiones como E2E. No llamar limit cycle autónomo a un patrón con
teacher móvil. Reportar órbitas con pausas para evitar falsa estabilidad.

Estrategia fija estable: en últimas20transiciones, q constante en1e-9 (se aceptan
HOLD con comando no0 pero se reportan), sin órbita y MSE medio no peor que P2
fijo correspondiente. El signo y amplitud no se deducen sólo del detector binario.

## Gates E2F y autorización limitada

No exigir perfección de P2. Operacionalizar la propuesta conceptual antes de medir
con el oracle primario H5, sin elegir H después:

1. Los20fijos muestran estrategia estable definida arriba; cero órbitas finales
   fijas (incluidas pausas), y cero ciclos finales históricos en200episodios.
2. Mejora MSE macro >=10% respecto P2 y reward macro no peor. Como máximo2sujetos,
   1motor y0direcciones degradados>5%, para evitar éxito sólo agregado.
3. Resolución no dominante operacionalmente: MSE mínimo alcanzable de un paso
   desde estados P2 <=50% del MSE real P2. Esto mide posibilidad local de corrección,
   no atribuye causalidad exclusiva a PWM ni demuestra realizabilidad simultánea.
   H5 debe realizar la mejora del punto2; no basta el bound optimista.
4. Cero nuevas órbitas finales periódicas por clave/par respecto P2; cero
   inversiones M3 H5 y cero movimiento PWM0. No cambiar datos para cumplirlo.
   Flat/no-motion, saturación y PWM siguen diagnósticos, sin gates nuevos de
   inactividad E2D/E2E: aquí se busca viabilidad de política, no esa intervención.
5. 144 tests históricos y nuevos pasan, hashes intactos, acciones legales,
   separabilidad y exactitud Bellman comprobadas, MATEO/SANDRA sellados.

Todos: CURRENT_MDP_CONTROL_FEASIBLE=YES, RL_PILOT_AUTHORIZED=YES; preparar sólo
especificación E3A, máximo600episodios, sin ejecutar. Si falla algún punto:
CURRENT_MDP_CONTROL_FEASIBLE=NO bajo estos gates, RL_PILOT_AUTHORIZED=NO;
documentar el bloqueo concreto y límites del oracle corto, sin afirmar por ello
imposibilidad matemática global. No rescatar cambiando acción/planta/reward/H.

## Familia de agente y expectativas

Consultar documentación primaria y distinguir MATLABR2023b del soporte actual.
Si firmware admite entero fino: TD3 histórico como principal, SAC challenger
conceptual; documentar que la planta caracterizada aquí sigue cuantizada y el
critic continuo enfrenta transiciones planas/discontinuas. No inventar dinámica
continua ni cambiar actor/critic. Si sólo hubiera discreción física, estudiar
factorización cuatro categóricas de15 sin producto ingenuo15^4, soporte real de
MATLAB y necesidad de bucle personalizado. Selección justificada, no por novedad.

Objetivo eventual: aprender política estable de apertura/cierre condicionada por
EMG y estado mecánico, supervisada mediante reward de glove durante training.
E1–E1D no demostraron información continua EMG específica; no prometer replay
exacto de cada guante individual ni reabrir decoder. Un oracle privilegiado sólo
evalúa oportunidades del MDP, no si EMG permite aprenderlo.

Sólo recomendación futura: HandKinematicViewer pasivo con trazas canónicas de P2,
oracle, Agent7250 y futuroagente; integración diferida. No abrir/importar código
sandbox ni plantaS4, no alterar training.

## Integridad y entrega

Inventario SHA256 único de históricos hasta E2E antes de mediciones. Nuevos
CSV/MAT/JSON/figuras exclusivamente e2f_results; scripts/tests/docs E2F nuevos.
No sobrescribir resultados anteriores; salida de regresiones inyectada bajoE2F.
Entregar resultados por todos losH yprimaryH5 explícito, protocolo hardware y
fuentes, grafo/DP/reachability/replays, límites, tests y decisión sin entrenar.
