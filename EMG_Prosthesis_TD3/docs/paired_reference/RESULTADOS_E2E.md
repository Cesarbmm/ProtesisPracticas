# E2E — Confirmación de reversión con un paso neutro

**E2E_RESULT = REVERSAL_GUARD_NOT_SUFFICIENT. RL_AUTHORIZED = NO.**

La confirmación usa exclusivamente acciones y memoria interna; es definible sin
guante. Sin embargo, no cumple los gates de degradación por grupos, action_no_motion
y neutralización. Además, las **20/20 órbitas con referencia fija persisten**:
pasan de periodo 2 a periodo 4, con ceros intercalados. No basta con insertar una
pausa para eliminar el overshoot de estos mapas de planta.

E2D permanece DEADBAND_NOT_SUFFICIENT, E2C CHARACTERIZED, E2B FAIL. P2 sigue siendo
el baseline privilegiado de controlabilidad; no se cambió Kp ni se abrió RL.

## Auditoría, preregistro y alcance

Fecha: 2026-09-06. Worktree existente:
`C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit`; rama
`experiment/no-glove-paired-reference-td3`; HEAD conservado
`165be049eb41fc41254435181c9857fe0f22ed1c`. La grafía anidada de la solicitud no
corresponde a una carpeta existente. El árbol inicial contenía sólo los archivos
locales E2C/E2D conocidos; se auditaron y conservaron. Sin reparación Git, cambio
de rama, commit ni push; sin código, hipótesis o resultados del sandbox.

[PREREGISTRO_E2E.md](PREREGISTRO_E2E.md) se guardó antes de medir, SHA256
**`fec5dd1bbd1c700bfd2e482e14572c3017d0e7462e732585352191e503d0164a`**.
Una sola intervención ON/OFF, ningún parámetro seleccionado. El inventario inicial
protege **589 archivos históricos E0P–E2D**, incluidos los resultados locales.

Se reutilizaron los mismos 200 episodios DEVELOPMENT del MAT E2B: q0, teacher
antes/después y horizonte histórico idénticos. No se abrieron archivos originales
de sujetos para las nuevas comparaciones; los tests históricos conservan BLANCA
y fixtures. MATEO/SANDRA no se abrieron ni compararon. E1–E1D siguen cerradas.

## Qué se implementó y qué información consume

Sólo helpers experimentales E2E; no modificación de Env ni de runtime E2A.

```text
P2 privilegiado → raw deseado → baselineQuantized → desiredPWM
                                                        ↓
                        guard(desiredPWM, previousAppliedPWM, pendingSign, ON)
                                                        ↓
                                                  appliedPWM
                                                        ↓
                                             planta canónica
```

El helper `e2eReversalGuard` no recibe ni lee guante, teacher, referencia, error,
reward o encoder. En NORMAL copia desired, salvo petición de signo opuesto a la
última aplicación no cero: aplica cero y guarda el signo solicitado. La siguiente
decisión recalcula desired; mismo signo confirma, otro signo/cero cancela. Copia
el nuevo desired en ambos casos y borra pending. No fuerza magnitudes anteriores.
Cada motor mantiene su propio signo pendiente. Un pending al cierre se conserva
como no resuelto, sin extender teacher termination ni inventar cancelaciones.

La acción efectiva aplicada es appliedPWM/255. El raw sigue siendo el raw deseado
de P2: el guard actúa después del cuantizador. Reward usa la acción aplicada y la
aplicada anterior, incluyendo los pasos neutros. Teacher previo genera P2;
teacher posterior puntúa tracking/reward; ninguno entra al helper de confirmación.

**USES_GLOVE=NO, USES_REFERENCE=NO, USES_REWARD=NO** se refiere al guard.
**USES_PREVIOUS_ACTION=YES, USES_CURRENT_DESIRED_ACTION=YES.** El P2 que produce
desired sigue siendo privilegiado: no se presenta este ensayo como un P sin guante.

Su memoria pending debe tratarse explícitamente en una eventual integración.
No se afirma que markov52 ya represente esa memoria ni se modifica su contrato.
No se integra el helper en TD3 ni se autoriza entrenamiento.

Congelados: Kp=2, Ts=.2 s, muestreo API=.14, niveles
[0,64,96,128,160,192,224,255], velocidades, remapeo, h(q), reward/pesos,
teacher/reset/done, planta, WMoos, markov52, actor/críticos y E2A. No deadband,
histéresis, otro dwell, limitador general ni nuevas curvas.

## Basal exacto y métricas globales

OFF reproduce los 200 episodios: **q/raw/effective/PWM exactamente iguales**, y
error máximo reward **0** (tolerancia requerida 1e-12). Conserva los dos ciclos
E2B y cero retrocesos M3. Son 2938 pasos/11752 comandos motor-paso por modo,
400 episodios y 23504 filas motor-paso en el CSV principal.

Agregación E2B: tiempo por episodio, episodios por sujeto/lado y media de los
20 grupos. Cambio MSE=100*(ON−OFF)/OFF; deterioro reward=
100*(R_OFF−R_ON)/abs(R_OFF). Valores negativos de deterioro significan mejora.

| Métrica | P2 OFF | Guard ON |
|---|---:|---:|
| trackingMSE | .025400336373607925 | .0264844369987998 |
| MAE | .1191157075 | .1221683412 |
| Correlación q normalizado/reference | .8185883777 | .8058837717 |
| Reward medio macro | -.03272837710980499 | -.0307238542121452 |
| Reward total por episodio, macro | -.4654854157 | -.4296477100 |
| tracking term | -.0254003364 | -.0264844370 |
| action penalty | .0011885135 | .0010597483 |
| delta-action penalty | .0061395272 | .0031796689 |
| actionL2 | .1188513548 | .1059748288 |
| deltaActionL2 | .1227905438 | .0635933785 |
| Saturación % | .7692102 | .5151230 |
| Fracción PWM alto, macro % | 18.0085282 | 16.5667978 |
| responseRange en h(q) | .3128724 | .3094513 |
| flat_response % | 1.625 | 1.875 |
| action_no_motion % | 45.6241807 | 51.0516234 |
| Ciclos finales, detector histórico | 2 | 0 |
| Ventanas alternantes, todos los prefijos | 48 | 0 |
| Retrocesos M3 / movimiento con PWM0 | 0 / 0 | 0 / 0 |

El MSE empeora **4.2680562 %** y reward mejora **6.1247244 %**. La mejoría de reward
procede de menores penalizaciones de acción, especialmente delta-action; el
tracking empeora. Las tres contribuciones se mantienen separadas en CSV.

flat_response conserva rango h(q)<=1e-9, incluyendo q0; no necesariamente implica
encoder inmóvil por los gaps históricos de h. action_no_motion conserva comandos
activos con |delta_q|<=1e-9 dividido por activos. No incluye PWM0. Su proporción
aumenta aunque el conteo medio de comandos activos sin movimiento baja ligeramente
de 22.71 a 22.445 por episodio: el denominador activo baja de 47.83 a 42.735.
No se cambia esta métrica ni su gate después de observarlo. No quedan combinaciones
episodio-motor sin comandos activos en OFF u ON.

## Gates medidos

| Gate preregistrado | Evidencia | Resultado |
|---|---|---|
| A: cero ciclos finales históricos | 0 | PASS |
| B: cero nuevos ciclos finales | 0 | PASS |
| C: MSE deterioro <=5 % | +4.2681 % | PASS |
| D: reward deterioro <=5 % | −6.1247 % | PASS |
| E: máximo 2 sujetos/1 motor/0 direcciones degradados | **4/10, 2/4, 1/2** | **FAIL** |
| F: aumento flat <=2 pp, global y motor/dirección | global +.25 pp; máximo +.5 pp | PASS |
| G: aumento no-motion <=5 pp, global y motor/dirección | global **+5.4274 pp**, apertura **+8.5918 pp** | **FAIL** |
| H: neutralización <=10 % de activos basales | **1133/9566 = 11.8440 %** | **FAIL** |
| I: cero retrocesos M3 | 0 | PASS |
| J: cero movimiento con PWM0 | 0 | PASS |
| K: tests e integridad | 107 anteriores +37 nuevos; 589 hashes | PASS |

Los sujetos con deterioro MSE >5 % son EMILIA (+11.5355 %), IVANNA (+7.3764 %),
JOE (+11.6585 %) y JONATHAN (+6.4393 %). Motores: M3 (+8.5585 %) y M4 (+5.9122 %).
Dirección: apertura (+8.3011 %). Sus rewards no exceden el límite de deterioro;
se cuenta como degradado si cualquiera de MSE/reward lo hace.

No-motion también excede el gate por motor: M3 +6.4185 pp y M4 +5.5805 pp.
Todos los grupos, incluidos los que no fallan, están en `subgroup_degradations.csv`.

## Cuánto neutraliza y cómo resuelve peticiones

| Grupo ON | Requests = neutros | Confirmados | Cancelados | Pendientes al cierre | Neutros/todos % | Neutros/activos OFF % |
|---|---:|---:|---:|---:|---:|---:|
| Total | 1133 | 973 | 96 | 64 | 9.6409 | 11.8440 |
| M1 | 221 | 180 | 28 | 13 | 7.5221 | 9.6338 |
| M2 | 105 | 85 | 2 | 18 | 3.5739 | 3.9355 |
| M3 | 450 | 403 | 29 | 18 | 15.3165 | 19.1734 |
| M4 | 357 | 305 | 37 | 15 | 12.1511 | 15.8175 |
| Cierre | 287 | 227 | 43 | 17 | 4.8810 | 5.8824 |
| Apertura | 846 | 746 | 53 | 47 | 14.4074 | 18.0499 |

Se cumple 1133=973+96+64. OFF tiene 1722 solicitudes de reversión inmediata pero
no neutraliza ninguna. Este conteo difiere del ON porque sus trayectorias divergen.
No se compara un desired congelado de otro estado como si fuese el actual.

Máximo de flags neutralized consecutivos: **1**, global y cada motor/dirección.
La racha de PWM0, incluyendo ceros naturales, alcanza 18 en OFF y ON; es otra métrica.
El CSV incluye motor×dirección, numeradores y denominadores.

El gate H cuenta todas las neutralizaciones sobre 9566 activos OFF, incluido el
caso en que OFF era cero en ese paso. La intersección literal de neutralizaciones
con OFF activo es **1057/9566**, que también excede el 10 %. La comparación pareada
de toda la trayectoria da **1283/9566 = 13.4121 %** de activos OFF que terminan en
cero, incluyendo cambios indirectos de q/desired. Son estimandos distintos.
Ninguno representa por sí solo porcentaje de desplazamiento útil perdido.

## Los dos casos conocidos, paso a paso

OFF reproduce BLANCA M3 +224,−64,+224,−64 y IVANNA M4 −64,+96,−64,+96.
Las referencias before/after y todos los términos de reward se guardan para
ambos modos. El siguiente detalle ON muestra el guard sin consultar teacher:

| Caso/paso | Desired PWM | Previous applied | Evento | Pending después | Applied PWM | q antes → después |
|---|---:|---:|---|---:|---:|---|
| BLANCA M3 /4 | −64 | +128 | neutralizar | −1 | 0 | 7286.3333 → 7286.3333 |
| /5 | −64 | 0 | confirmar | 0 | −64 | 7286.3333 → 1541.6667 |
| /6 | +224 | −64 | neutralizar | +1 | 0 | 1541.6667 → 1541.6667 |
| /7 | +224 | 0 | confirmar | 0 | +224 | 1541.6667 → 7532.5 |
| /8 | −64 | +224 | neutralizar | −1 | 0 | 7532.5 → 7532.5 |
| IVANNA M4 /18 | +96 | −64 | neutralizar | +1 | 0 | 2976.3333 → 2976.3333 |
| /19 | +96 | 0 | confirmar | 0 | +96 | 2976.3333 → 6049.75 |
| /20 | −64 | +96 | neutralizar | −1 | 0 | 6049.75 → 6049.75 |
| /21 | −64 | 0 | confirmar | 0 | −64 | 6049.75 → 2976.3333 |
| /22 | +96 | −64 | neutralizar | +1 | 0 | 2976.3333 → 2976.3333 |

La neutralización cambia el tiempo de aplicación, pero los saltos activos siguen
siendo grandes. Los pasos finales pending no cuentan como cancelaciones.

## Referencia fija: las órbitas persisten

Se reprodujeron exactamente los 20 OFF E2C y sus 20 ON, 100 pasos cada uno. El
detector adicional de periodicidad del estado (q_before,previousApplied,pending)
se definió antes de medir: últimas 32 decisiones, periodo mínimo 1..8, amplitud
h>.05 y movimiento en ambos sentidos; excluye HOLD/puntos fijos.

| Diagnóstico fijo | OFF | ON |
|---|---:|---:|
| Ciclos del detector histórico | 20/20 | 0/20 |
| Órbitas del estado aumentado | 20/20 | **20/20** |
| Periodo mínimo | 2 decisiones (.4 s) | **4 decisiones (.8 s)** |
| Reversiones persistentes al excluir ceros de la cola | 20/20 | 20/20 |
| Neutros por replay | 0 | 50/100 |
| Confirmaciones / cancelaciones / pending final por replay | 0 / 0 / 0 | 49 / 0 / 1 |

Para los pares primarios, el patrón se convierte en +224,0,−64,0 en M3 y
−64,0,+96,0 en M4, según fase inicial. La referencia fija y PWM0 dejan q igual;
por eso el signo opuesto se vuelve a pedir, se confirma y ejecuta el mismo salto.
La pausa alarga el periodo sin eliminar la órbita. El cuarto teacher M3 conserva
el otro destino alto ya documentado E2C, 7584.5; no se corrige la curva.

Con ON no hay ventanas del detector histórico en ninguno de los prefijos de los
200 episodios. Esto se explica también por su definición: requiere cuatro PWM
consecutivos alternos y no cero; el guard impide la reversión inmediata no cero.
**Cero ciclos finales/transitorios de ese detector no demuestra ausencia de
oscilaciones con pausas.** No se declara estabilidad universal ni se cambia el
gate retrospectivamente; E2E ya falla E/G/H de forma independiente.

## Comparación descriptiva con E2D .08

| Magnitud | E2D .08 cerrado | E2E ON |
|---|---:|---:|
| MSE | .0242843741 | .0264844370 |
| Reward | −.0295803726 | −.0307238542 |
| flat_response % | 4.5 | 1.875 |
| action_no_motion % | 48.0878 | 51.0516 |
| Inhibición directa / todos los comandos % | 29.9609 | 9.6409 |
| OFF activo → PWM0 pareado / activos OFF % | 35.5948 | 13.4121 |
| Ciclos finales históricos | 0 | 0 |

La intervención dirigida a reversión neutraliza menos comandos que la zona muerta
.08 y conserva mejor el rango de respuesta, pero incumple sus propios límites y
mantiene las órbitas fijas. No reabre la selección E2D ni justifica otro dwell.

## Artefactos, reproducción y tests

Carpeta `matlab_code/analysis/paired_reference/e2e_results/`:

- `trajectories.mat`: 200×2 trazas, 200 basales y gates; referencias y memoria.
- `step_traces.csv`: 23504 filas motor-paso con desired/applied, eventos, pending,
  q antes/después, teacher antes/después, raw y reward descompuesto.
- `known_cases_all_motors.csv`, `known_cycle_case_traces.csv`: casos E2C completos.
- `diagnostic_artifacts.mat`, `fixed_reference_traces.csv`, `fixed_reference_summary.csv`:
  40 replays fijos y periodos del estado aumentado.
- Métricas por episodio/motor, global, sujeto, dirección, motor y sujeto/lado;
  `event_summary.csv`, distribución PWM, ciclos y degradaciones.
- `candidate_gates.csv`, comparación E2D, manifiesto planta E0P, preregistro/hash,
  inventario de integridad, tests y manifiesto SHA256 de artefactos.
- `e2e_results.png`/`.svg`: figura exportable de órbitas y comparación descriptiva.

![Resultados E2E](../../matlab_code/analysis/paired_reference/e2e_results/e2e_results.png)

Desde `EMG_Prosthesis_TD3/matlab_code`, proceso MATLAB nuevo:

```powershell
matlab -batch "addpath(genpath('src'));addpath('config');addpath(genpath('lib'));addpath('analysis/paired_reference');summary=runPairedReferenceE2E();"
python analysis/paired_reference/verifyE2EArtifacts.py
```

El inventario inicial ya existe y no se recaptura. El runner sólo regenera E2E
y escribe las regresiones bajo E2E. No entrena, cambia históricos ni opera Git.
La prueba E2D se ejecuta directamente sobre sus artefactos intactos; no se llama
a su runner de comparaciones. El verificador Python reconstruye las métricas y
el autómata de forma independiente, y separa un FAIL científico de una verificación
de integridad correcta.

Los tests cubren OFF exacto en 200, request/confirmación/cancelación, memoria por
motor, invariancia del guard a información privilegiada ajena a su interfaz,
remapeo/planta/reward, ambos casos, detector histórico y órbitas con pausas,
conteos/gates, determinismo e integridad. Sin cambiar expectativas históricas.

Resultado **144/144 tests**, ninguno fallido o incompleto: 107 anteriores y 37
E2E. Los **589/589 hashes históricos** permanecen idénticos. El verificador
independiente confirma 23504 filas motor-paso, 1600 métricas episodio-motor,
20/20 órbitas ON, fallos E/G/H y 35 hashes de artefactos. Error máximo de
reconstrucción del reward desde CSV: **1.02e-15**.

## Cierre

La intervención es causalmente compatible con entradas disponibles sin guante,
pero el ensayo no respalda su suficiencia como solución a estos bloqueadores.
El resultado se limita a un paso neutro, esta planta y los episodios preregistrados.
No se prueba otro dwell, histéresis, limitador, Kp, PWM ni modificación de planta.

**E2E_RESULT=REVERSAL_GUARD_NOT_SUFFICIENT. RL_AUTHORIZED=NO.**
**E3_PREPARED=NO. E3_EXECUTED=NO. MATEO_SANDRA_SEALED=YES.**
**GIT_REPAIR_ATTEMPTED=NO. COMMIT=NO. PUSH=NO.**
