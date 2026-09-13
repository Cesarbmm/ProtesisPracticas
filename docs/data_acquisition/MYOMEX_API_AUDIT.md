# Auditoría de la API local MyoMex

Auditoría por lectura de código del checkout, sin conectar hardware ni cargar dataset alguno. No se inventa un constructor o método distinto del proveedor existente.

| Evidencia local | Contrato observado |
|---|---|
| [MyoMex.m](../../EMG_Prosthesis_TD3/matlab_code/lib/myo%20mex/MyoMex/MyoMex.m) | `MyoMex(1)` conecta un dispositivo, expone `myoData`, consulta FIFO con timer .040 s y expone `currTime`. `delete` libera timer/MEX. Un fallo del dispositivo puede invalidar el objeto. |
| [MyoData.m](../../EMG_Prosthesis_TD3/matlab_code/lib/myo%20mex/MyoMex/MyoData.m) | Propiedades públicas de lectura: emg_log/timeEMG_log; timeIMU_log, quat_log, gyro_log, accel_log y pose_log. SetAccess private no impide leerlas. |
| Constantes MyoData | EMG_SAMPLE_TIME=.005, IMU_SAMPLE_TIME=.020, EMG_SCALE=128, NUM_INIT_SAMPLES=4. |
| addDataEMG | `e=data.emg./128`; genera tiempo por índice, enlaza con prevTimeEMG y ancla el primer lote a currTime. Retira cuatro muestras iniciales del proveedor. |
| addDataIMU | Tiempo nominal por índice; quat normalizado a [w x y z]; gyro grados/s; accel g, marco del sensor. |
| [Ejemplo de continuidad](../../EMG_Prosthesis_TD3/matlab_code/lib/myo%20mex/MyoMex/example/MyoMexExample_DataContinuity.m) | Advierte de relleno mediante zero-order hold y usa filas idénticas como diagnóstico. No son timestamps nativos capaces de certificar cada pérdida. |
| clearLogs | Documenta no invocarlo mientras streaming está activo. El adaptador nuevo usa cursores crecientes y no lo llama. |
| @Myo histórico | Lee emg_log y llama clearLogs; esa estrategia no se reutiliza en captura nueva. |
| RecordedMyo | Proveedor de datos pregrabados, 200 Hz asumidos; no sirve para adquisición física ni se usa como fuente científica nueva. |

`RAW_EMG_CHANNELS=8`, `EXPECTED_EMG_HZ=200`, `EXPECTED_IMU_HZ=50`, `IMU_API_AVAILABLE=YES`. Las poses internas son auxiliares discretas, no apertura medida.

## Dependencia de despliegue encontrada

En este checkout no existe `myo_mex.mexw64`. Los archivos `myo_class.hpp`, `myo_mex.cpp` y `myo_sfun.cpp` tienen firma ZIP/Word y contienen `word/document.xml`, pese a su extensión. Se comprobó su contenido sin modificar los archivos; la sección EMG del documento fuente describe entrega por pares y relleno con la última muestra. No se intentó compilar ese contenedor ni reconstruir a ciegas un binario.

El nuevo adaptador falla antes de conectar si no se provee el MEX esperado. La API MATLAB queda auditada y la infraestructura probada con mock; **la compatibilidad binaria y la captura física no están verificadas**. Se requiere una distribución/compilación confiable de MyoMex, SDK/DLL y Myo Connect para la prueba manual.
