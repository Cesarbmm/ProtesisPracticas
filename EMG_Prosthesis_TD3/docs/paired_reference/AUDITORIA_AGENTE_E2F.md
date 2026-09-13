# E2F — Familia de agente y espacio de acción

2026-09-06. Investigación de documentación primaria, sin entrenamiento ni cambios
en agentes. Se aplica exclusivamente a `experiment/no-glove-paired-reference-td3`.
La recomendación no constituye autorización de RL: esa decisión depende de los
gates medidos del [preregistro E2F](PREREGISTRO_E2F.md).

## Recomendación para la evidencia disponible

**Principal: TD3 histórico. Challenger conceptual: SAC continuo.** La auditoría
local confirma comandos enteros con magnitud 0–255 en el protocolo y firmware
disponibles; no impone los ocho niveles de magnitud del simulador. Sin embargo,
la implementación externa de `MotorControl` usada por el dispositivo no está
incluida, y no se ha medido aquí la resolución eléctrica ni el movimiento útil
de PWM intermedios. Véase [auditoría de interfaz](AUDITORIA_INTERFAZ_E2F.md).

Esta recomendación conserva el baseline histórico y permite una comparación
posterior interpretable. No convierte `patternCurveCanonical` en una planta de
resolución fina: E2F mantiene `baselineQuantized`, Ts=.2 y los 15 comandos con
signo por motor. Aceptar un entero en firmware no demuestra que exista una
transición empírica fiable para ese entero en la planta caracterizada.

| Situación | Principal | Challenger | Alcance |
|---|---|---|---|
| Evidencia actual: protocolo entero fino; niveles elegidos en simulación | TD3 histórico | SAC continuo | Mantener el MDP auditado para comparar; no inventar dinámica intermedia. |
| Si una auditoría futura demostrara que sólo los niveles históricos son físicamente ejecutables | PPO categórico factorizado 4×15 | Actor-critic categórico factorizado | Alternativa conceptual; exigiría nueva autorización e implementación personalizada. |

No se escoge SAC por novedad ni se atribuye a un algoritmo la solución de los
ciclos que todavía debe demostrar el oracle.

## Qué aportan TD3 y SAC

TD3 combina dos críticos, actualización retrasada del actor y suavizado de la
política objetivo para reducir errores de aproximación del valor. Su actor
determinista facilita comparar ejecuciones congeladas. Mantenerlo aprovecha el
contrato ya auditado del proyecto, sin confundir cambios de agente y entorno.
El artículo no garantiza estabilidad mecánica para esta prótesis.
[Fujimoto et al., artículo original TD3](https://proceedings.mlr.press/v80/fujimoto18a.html).

SAC utiliza una política estocástica y un objetivo que incorpora entropía además
del reward. Es un challenger para estudiar otra forma de exploración con
reutilización de experiencias. Añade decisiones sobre distribución y entropía;
la variabilidad exploratoria debe evaluarse frente a la penalización histórica
de cambio de acción. No se afirma que requiera menos episodios o que supere TD3
en este proyecto: esos resultados no se han medido.
[Haarnoja et al., artículo original SAC](https://proceedings.mlr.press/v80/haarnoja18b.html).

En R2023b, SAC continuo utiliza actor gaussiano y críticos Q. Su evaluación puede
ser determinista con `UseExplorationPolicy=false`; el entrenamiento sigue
utilizando exploración. TD3 y SAC continuo están documentados en esa versión.
La existencia de estos componentes no autoriza ejecutarlos ahora.
[Guía oficial R2023b, secciones 3-52 y 3-57](https://www.mathworks.com/help/releases/r2023b/pdf_doc/reinforcement-learning/rl_ug.pdf).

## Consecuencia de los intervalos del cuantizador

Esta sección es una inferencia matemática del código local. En la ruta auditada,
dos acciones raw que producen el mismo PWM y acción efectiva provocan la misma
transición y reward, dado el mismo estado y acción efectiva anterior. El entorno
registra raw, pero la planta recibe PWM y el reward recibe acción efectiva.
Los miembros de cada intervalo de cuantización son, por tanto, equivalentes para
esa transición del MDP. El valor respecto a raw contiene mesetas y fronteras.

Un crítico neuronal continuo aproxima esa función. Los gradientes que usa TD3
para mover el actor entre intervalos dependen de esa aproximación. Esto es una
dificultad de aprendizaje que merece medirse; no demuestra que TD3 sea inválido
ni que el MDP no admita una buena política. SAC continuo conserva la misma
interfaz: una distribución raw más dispersa puede consumir entropía dentro de un
mismo intervalo sin aumentar la diversidad de PWM aplicados.

En una comparación futura deben distinguirse distribución raw, distribución PWM
efectiva y comportamiento mecánico. No se modifica el cuantizador, sus umbrales,
el reward ni el actor para producir esa comparación en E2F.

## Qué requeriría una alternativa categórica

Si las acciones realmente disponibles fueran las 15 categorías con signo por
motor, la representación natural sería:

`pi(a|s) = producto_i pi_i(a_i|s)`, con cuatro cabezas de 15 probabilidades.

Son 60 logits, no una salida con 15^4 combinaciones. Un tronco compartido puede
recibir el mismo `markov52`; un crítico escalar estima el retorno total histórico.
La log-probabilidad conjunta es la suma de las cuatro log-probabilidades. Para
PPO se formaría el cociente conjunto entre política nueva y anterior; cuatro
recortes independientes no son automáticamente el mismo objetivo PPO.
[Schulman et al., artículo original PPO](https://arxiv.org/abs/1707.06347).

Esta es una propuesta de representación, no una implementación validada. PPO
utiliza experiencias de la política reciente: la comparación con el replay de
TD3/SAC debe considerar el presupuesto de datos. El clipping de PPO limita la
actualización de política; no garantiza ausencia de oscilación mecánica.

En R2023b, `rlPPOAgent` acepta `rlDiscreteCategoricalActor`, pero documenta un
único canal de acción y una distribución sobre las acciones del conjunto
finito. No está documentado un reemplazo directo con cuatro distribuciones
independientes de 15 elementos. Enumerar vectores completos en `rlFiniteSetSpec`
sería una distribución sobre combinaciones, no la factorización solicitada.
[Referencia oficial R2023b, páginas internas 3-304 y 3-310](https://www.mathworks.com/help/releases/r2023b/pdf_doc/reinforcement-learning/rl_ref.pdf).

Un agente o bucle personalizado es una vía técnicamente viable en MATLAB: la
guía R2023b documenta ambos mecanismos. La distribución factorizada y su pérdida
necesitarían implementación y tests propios; no se promete que el constructor
`rlPPOAgent` pueda utilizarlos sin adaptación. Un actor-critic factorizado más
simple sería otra comparación conceptual, no una segunda familia implementada
en esta etapa. [Guía oficial R2023b, secciones 3-68 y 5-77](https://www.mathworks.com/help/releases/r2023b/pdf_doc/reinforcement-learning/rl_ug.pdf).

La documentación actual de SAC ya incluye acciones discretas e híbridas, pero
mantiene un canal para el caso no híbrido. Ese soporte actual no debe atribuirse
a R2023b ni interpretarse como soporte automático de cuatro cabezas categóricas.
[Documentación actual de rlSACAgent](https://www.mathworks.com/help/reinforcement-learning/ref/rl.agent.rlsacagent.html).

## Expectativa científica y límites

El objetivo realista es **aprender una política estable de apertura/cierre
condicionada por EMG y estado mecánico, supervisada mediante reward de glove
durante training**. El guante no se añade a `markov52`, al actor ni a inferencia.
E1–E1D permanecen cerradas: no se ha demostrado información EMG continua
específica suficiente para reproducir cada trayectoria individual de guante.

El oracle privilegiado evalúa posibilidades de control de la planta; no
demuestra que la observación EMG permita aprender su comportamiento. Tampoco
demuestra transferencia al hardware físico ni independencia mecánica real de
los motores. No se entrenó TD3/SAC/PPO, no se creó otra heurística ni se integró
código externo o de otra línea experimental.

```text
RECOMMENDED_AGENT_PRIMARY = TD3_HISTORICO
RECOMMENDED_AGENT_CHALLENGER = SAC_CONTINUO
RATIONALE = continuidad experimental y protocolo entero fino disponible;
            resolución física útil no demostrada; MDP canónico aún cuantizado.
TRAINING_EXECUTED = NO
```
