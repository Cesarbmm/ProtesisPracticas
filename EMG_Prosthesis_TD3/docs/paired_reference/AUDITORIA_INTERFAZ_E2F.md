# E2F — Interfaz PWM y separabilidad del oracle

2026-09-06. Auditoría estática de la línea principal. No se conectó hardware,
no se compiló ni modificó firmware y no se cambió la planta. Las rutas citadas
son relativas a `EMG_Prosthesis_TD3`; los números de línea corresponden al estado
local de recepción de E2F.

## Interfaz real: qué está demostrado

Los niveles `[0,64,96,128,160,192,224,255]` son una elección explícita de la
interfaz de simulación, no una restricción impuesta por el protocolo de firmware
disponible. El protocolo representa enteros de magnitud 0–255 y dirección por
letra mayúscula/minúscula. Eso no demuestra que cada entero produzca un movimiento
físico distinguible.

| Evidencia local | Observación verificable | Conclusión permitida |
|---|---|---|
| [Controller.m](../../matlab_code/src/@Controller/Controller.m), líneas 119–122, 133–156 | `sendAllSpeed` acepta ±255, redondea y serializa magnitudes con dos dígitos hexadecimales. | La API no restringe el envío a los niveles históricos. |
| [Controller.m](../../matlab_code/src/@Controller/Controller.m), líneas 174–183 | `sendSpeed` acepta ±255 y serializa magnitud/dirección. | Los enteros intermedios son representables también para un motor. |
| [communications.h](../../prosthesis_code/include/communications.h), líneas 223–231 | `decodeSpeed` convierte hexadecimal genérico; el comentario incluye `B04` como PWM 4. | El parser admite explícitamente valores menores que 64. |
| [communications.h](../../prosthesis_code/include/communications.h), líneas 249–266 y 366–402 | La expresión acepta uno o dos dígitos hexadecimales por motor y conserva su signo. | No existe una lista de los ocho niveles en ese parser. |
| [Motors.cpp](../../prosthesis_code/lib/Motors/Motors.cpp), líneas 88–125 | `move` pasa magnitud a `setSpeed`, selecciona sentido y aplica `brake` para cero. | No se observa cuantización a ocho niveles en esta capa. |
| [remapActionForActuator.m](../../matlab_code/src/@Env/remapActionForActuator.m), líneas 8–11 y 14–33 | Fuera de simulación cuantizada hace `round(action*maxPwm)`; sólo la otra ruta usa niveles y umbral. | El conjunto grueso pertenece al contrato experimental de simulación. |
| [configurables.m](../../matlab_code/config/configurables.m), líneas 218–235 | Cuatro acciones independientes, escala 255, cuantización activada, umbral .05 y niveles explícitos. | E2F debe conservar esta elección para auditar el MDP actual. |

La documentación de firmware identifica Wemos D1 R32 y Adafruit Motor Shield V1
y señala una dependencia modificada de MotorControlShield. La implementación
`MotorControl.h` incluida desde [Motors.h](../../prosthesis_code/lib/Motors/Motors.h),
línea 16, no está presente en este checkout. El
[readme de firmware](../../prosthesis_code/readme.md), líneas 11–17 y 25–30,
no fija una revisión verificable de esa implementación modificada.

Por ello, esta auditoría no identifica el PWM eléctrico exacto generado por la
versión instalada, su resolución útil, fricción, umbral de arranque ni la
diferenciación mecánica de comandos vecinos. Esos puntos quedan `UNKNOWN`, no
se completan suponiendo que el dispositivo instalado equivale a una biblioteca
externa actual. No se propone probar hardware durante E2F.

```text
PWM_HARDWARE_SUPPORT = PROTOCOLO/FIRMWARE DISPONIBLE: ENTERO 0..255 CON SIGNO;
                       RESOLUCION ELECTRICA Y MECANICA INSTALADA: UNKNOWN
HISTORICAL_LEVELS_PHYSICAL_REQUIREMENT = NO SEGUN CODIGO DISPONIBLE
CONTINUOUS_OR_INTEGER_PWM_AVAILABLE = INTEGER YES EN PROTOCOLO;
                                     CONTINUOUS NO DEMOSTRADO;
                                     FINE_MOTION UNKNOWN
```

## Convención de la caracterización histórica

La tabla interna del simulador usa `[0 64 96 128 160 192 224 256]` y nombres
`sp_zeroF`, `sp_3F` hasta `sp_FF`. PWM 255 de la API se asigna al campo `sp_FF`
mediante `snapSpeed`; 256 es una etiqueta interna, no un comando autorizado.
Véase [prosthesis_simulator.m](../../matlab_code/src/@SimController/prosthesis_simulator.m),
líneas 106–107 y 194–212.

Hay una diferencia histórica de convención visible en los datos crudos:
`development/archive/simulator_creation_assets/raw data Cx2/3F/Prueba1_2024_02_09.csv`,
línea 2, registra `A3FB3FC3FD3F` (63 decimal); la carpeta 5F registra 95 decimal.
Los nombres de campo y niveles del simulador corresponden a esa caracterización,
pero sus números no deben presentarse como prueba de mediciones independientes
en cada entero. E0P congeló esta planta; E2F no corrige esa convención ni vuelve a
ajustar o interpolar curvas.

Aunque se retirara el remapeo externo, la selección interna seguiría usando
curvas discretas. El oracle debe emplear exactamente los 15 PWM con signo
permitidos actualmente. La disponibilidad de protocolo fino no autoriza crear
transiciones intermedias sin datos.

## Separabilidad de planta, acción y reward

Para una duración y muestreo comunes, la planta calcula cada columna con
`initial_position(i)` y `speeds(i)` y sólo las curvas/límites de ese motor.
No lee los otros tres estados o PWM para calcular `q_i_next`.
Véase [prosthesis_simulator.m](../../matlab_code/src/@SimController/prosthesis_simulator.m),
líneas 61–68 y 124–170. Los estados fuera del recorrido y PWM0 mantienen la
posición de ese mismo motor; no existe una restricción conjunta de potencia en
esta implementación.

El remapeo recorre componentes y utiliza una escala constante de 255. No hay
presupuesto de PWM compartido ni normalización por la suma de las acciones.
`unifyActions=false` es necesario para esta conclusión: está fijado en
[configurables.m](../../matlab_code/config/configurables.m), línea 218.

`h(q)` también es separable: [encoder2Flex.m](../../matlab_code/src/preprocess/encoder2Flex.m),
líneas 65–87, transforma cada columna mediante sus constantes, valor absoluto,
zona muerta mecánica y saturación. La división posterior es componente a
componente por `[4092 2046 1023 2046]`, en
[configurables.m](../../matlab_code/config/configurables.m), línea 284. El flag
`finishEpisode` combina saturaciones dentro de `encoder2Flex`, pero `Env.step`
sólo consume su primera salida, por lo que ese flag no acopla el horizonte actual.

En [step.m](../../matlab_code/src/@Env/step.m), líneas 75 y 123–125, el teacher
se actualiza antes de evaluar reward. La función recibe acción efectiva, y
`prevAction` se actualiza después, en la línea 146. Por motor, el coste es:

```text
c_i(t) = (h_i(q_i(t+1)) - reference_after_i(t))^2
         + 0.01*u_i(t)^2
         + 0.05*(u_i(t) - u_i(t-1))^2

reward(t) = -(1/4) * sum_i c_i(t)
u_i(t) = PWM_i(t)/255
```

Esto sale directamente de
[trackingMseActionRateReward.m](../../matlab_code/src/reward_functions/trackingMseActionRateReward.m),
líneas 13–26, y los pesos de configuración en líneas 204 y 207. No hay términos
cruzados entre motores. La penalización de cambio es temporal, pero sigue siendo
independiente por motor: el estado de planificación debe incluir `u_i(t-1)`.

La terminación prerecorded es `myo.exhausted || glove.exhausted`, en
[checkEndEpisode.m](../../matlab_code/src/@Env/checkEndEpisode.m), líneas 12–16.
Con los episodios y disponibilidad teacher congelados, el horizonte es exógeno a
las acciones. El reset inicial y las referencias se fijan desde las trazas E2B;
no se modifica esta semántica.

## Consecuencia matemática para el oracle

Con `z_i=(q_i,u_i_previous)` y el tiempo teacher `t` conocido, cada motor tiene
transición propia y conjunto de 15 acciones independiente. Para horizonte H y
coste terminal cero, la recurrencia es:

```text
V_i(t,z_i,H) = min_{u_i en A_i} [c_i(t,z_i,u_i)
                               + V_i(t+1,z_i_next,H-1)]
V_i(t,z_i,0) = 0
```

La minimización del coste conjunto equivale a la suma de los cuatro mínimos,
con el factor común 1/4. Se justifica programación dinámica por motor conservando
la memoria de acción, en lugar de una búsqueda conjunta de 15^4 comandos por
decisión. Dos acciones con el mismo destino no se pueden fusionar sin conservar
su coste y acción anterior: pueden tener penalizaciones presentes y futuras
distintas.

`ORACLE_SEPARABLE = YES` se refiere al **oracle offline y a esta planta/coste**.
No afirma independencia física de los motores reales, factorización automática
de cualquier política aprendida desde EMG, ni acceso del futuro actor al teacher.
Las pruebas dinámicas de separabilidad y de Bellman quedan en los tests E2F;
esta auditoría estática no sustituye sus resultados.

El oracle optimiza el target posterior que consume el reward. P2 usa la
referencia disponible antes del paso para decidir; mantener esa diferencia
explícita evita presentar el oracle con teacher futuro como política desplegable.
La decisión de preparar E3A se toma únicamente después de los gates E2F.
