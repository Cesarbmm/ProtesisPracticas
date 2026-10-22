# Por qué adquirir nuevos datos

El [cierre científico](../paired_reference/FINAL_CAMPAIGN_CLOSURE.md) permanece **FINAL_SEALED_TEST_RESULT=FAIL**. FINAL E4 (PPO categórico feed-forward, 500k) obtuvo MSE .071575 frente a .038495 de Agent7250, un empeoramiento de 85,93% en los dos sujetos sellados. E4 no presentó ciclos, periodicidades ni reversiones M3, pero su estabilidad mecánica no bastó para generalizar y la máxima fracción de una categoría alcanzó 1.00.

Esto no demuestra que ninguna política feed-forward pueda generalizar ni que todo el fallo provenga de domain shift. Pueden contribuir identidad individual EMG, sesión/posición del Myo, WMoos, protocolo abrir/cerrar, falta de calibración del usuario y contrato teacher/planta. No se reabre el test consumido ni se escoge otro algoritmo para ajustarse a él.

La pregunta siguiente es cuánta calibración necesita un usuario nuevo y cuánto cambia esa necesidad al retirar y recolocar el Myo. Las sesiones P1 y P2 permiten distinguir cambios entre sujetos de cambios de colocación dentro de una persona, sin mezclarlos automáticamente.

Holds parciales, rampas en ambas direcciones y reposo describen una tarea instruida más rica que abrir/cerrar únicamente. La pantalla da un target continuo de intención, **no ground truth de movimiento físico**. En este proyecto no se implementarán visión/cámara ni measured aperture; quedan definitivamente fuera de alcance por separación ética/temática. La IMU sólo se conserva para análisis de estabilidad/postura.

Guardar los ocho canales tal como los proporciona MyoData, tiempos originales/reconstruidos, llegada host, IMU disponible, protocolo, calidad y colocación evita encerrar el dataset en WMoos o PPO. Más adelante podrá servir a distintos métodos de clasificación, regresión, control, memoria temporal y adaptación/calibración de usuario. En esta rama no se implementa ninguno ni se construye un calibrador.

La escala `/128`, la reconstrucción temporal y el posible relleno del proveedor quedan registrados como límites del RAW disponible; no se los confunde con una captura nativa de paquetes/hardware timestamps. La primera sesión real deberá comprobar esas dependencias antes de cualquier interpretación científica.

El piloto 2 amplía la pregunta a dirección + nivel instruido en P001/S04, con colocación fija y postura P0_NEUTRAL_90. El gradiente preliminar observado por el operador en S03 no demuestra separación robusta de cuatro niveles. Este piloto introduce seis repeticiones por condición, bloques aleatorios, velocidad nominal constante y RELEASE antes de REST; no entrena modelos ni modifica S01/S02/S03.

`REFERENCE_CONTRACT_VALIDATED=NO`, `HARDWARE_ACTUATION_AUTHORIZED=NO`, `TRAINING_STARTED=NO`. La autorización de adquisición manual del Myo corresponde exclusivamente a sensores y nuevos participantes; no habilita prótesis, sandbox ni otra evaluación sellada.
