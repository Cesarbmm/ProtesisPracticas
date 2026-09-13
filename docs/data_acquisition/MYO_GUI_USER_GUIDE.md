# Guía de adquisición Myo

La GUI captura RAW e instrucciones visuales. No controla motores ni ejecuta entrenamiento. Abrirla no conecta el Myo automáticamente.

## Dependencias físicas pendientes

La API MATLAB MyoMex/MyoData fue auditada. Este checkout **no incluye `myo_mex.mexw64`**. Además, varios archivos históricos con extensión `.cpp/.hpp` contienen documentos Word ZIP; no deben compilarse como si fueran texto C++ válido. No se modificaron ni sustituyeron silenciosamente.

Antes de una prueba real, instalar/proveer una compilación confiable de MyoMex compatible con Windows/MATLAB R2023b, Myo Connect, Myo SDK y sus DLL correspondientes. El binario esperado es:

`EMG_Prosthesis_TD3/matlab_code/lib/myo mex/MyoMex/myo_mex/myo_mex.mexw64`.

El wrapper espera un Myo emparejado. `build_myo_mex(sdk_path)` es el helper histórico, pero sólo es utilizable después de disponer de fuentes C++ válidas y del SDK. No se ejecutó una compilación contra los archivos Word ni se descargó un driver desconocido. El botón Conectar muestra un error explícito si falta el MEX. **La prueba física de conexión y captura continúa pendiente del usuario; el smoke mock no la sustituye.**

## Abrir GUI completa, manualmente

```matlab
cd('C:\Users\Cesarbmm\ProtesisPracticas_myo_calibration\EMG_Prosthesis_TD3\matlab_code');
addpath('acquisition');
app = MyoContinuousAcquisitionApp();
```

1. Introducir participante nuevo P001, sesión S01, brazo, placement P1 y nota de orientación. No incluir identificadores personales innecesarios.
2. Pulsar **Conectar Myo**, con el dispositivo emparejado en Myo Connect. No abrir otra instancia MyoMex que compita por el mismo MEX.
3. Pulsar **Test signal 30s**. Revisar ocho canales, ausencia de plano/clipping constante y avisos. Relajar y mover suavemente. RMS/MAV son diagnósticos, no medidas de intención ni de apertura.
4. Elegir repeticiones y tiempos antes de iniciar. La configuración avanzada se entrega como `Protocol=buildMyoContinuousProtocol(...)` al constructor. Cambiar colocación después del diagnóstico requiere una nueva prueba de señal.
5. Pulsar **Iniciar / Seguir**. Se congelan metadata y protocolo; aparece barra 0–100%, número, dirección, fase y progreso del trial. En REST sólo se pide relajar, sin asociarlo a mano abierta/cerrada.
6. **Pausa** guarda un prefijo parcial. **Iniciar / Seguir** reinicia la fila actual desde el principio con otro ID. **Repetir trial** también conserva el prefijo e inicia otra instancia de la fila actual; no reemplaza un MAT previo.
7. **Abortar seguro** conserva lo completado y el prefijo activo. **Finalizar** guarda lo disponible y desconecta. Cerrar la GUI intenta guardar el trial activo antes de desconectar.

El RAW se guarda sin los offsets verticales usados para separar CH1–CH8 en pantalla. El live view conserva sólo los últimos dos segundos; los archivos por trial conservan todos los samples recibidos dentro de la captura activa.

## Primera prueba real pequeña

Una sola persona, sesión y colocación; REST y cuatro niveles, una repetición, aproximadamente un minuto de protocolo más 30 segundos de diagnóstico:

```matlab
cd('C:\Users\Cesarbmm\ProtesisPracticas_myo_calibration\EMG_Prosthesis_TD3\matlab_code');
addpath('acquisition');
p = buildMyoContinuousProtocol(repetitions=1,includeRamps=false,holdSeconds=3,restSeconds=6);
app = MyoContinuousAcquisitionApp(Protocol=p);
```

Pulsar Conectar/Test signal/Iniciar únicamente cuando el hardware esté preparado. El propósito es verificar infraestructura, no entrenar ni validar generalización.

## Ubicación y recuperación

Por defecto: `matlab_code/data_acquisition/P001/S01/`. Puede elegirse otra raíz con `OutputRoot="D:\MyoDataset"`. Una sesión existente se rechaza; para P2 usar S02 y otra GUI. Las carpetas raw están ignoradas por Git.

Al terminar revisar `session_manifest.csv`, `session_status.json`, avisos por trial, tamaño y hash de los MAT. COMPLETED y *_PARTIAL son estados distintos. Después de una interrupción abrupta:

```matlab
report = recoverMyoSession('C:\ruta\al\dataset\P001\S01');
```

La ruta debe ser la de la sesión nueva adquirida. No invocar recuperación sobre datasets históricos. Se recupera el último prefijo disponible, sin reanudar artificialmente una contracción ni borrar trials. Los archivos temporales quedan para inspección si hubo fallo de disco/escritura.

## Tests y smoke sin hardware

```matlab
cd('C:\Users\Cesarbmm\ProtesisPracticas_myo_calibration\EMG_Prosthesis_TD3\matlab_code');
r = runtests('tests/acquisition/testMyoContinuousAcquisition.m');
assert(all([r.Passed]));
addpath('acquisition');
summary = runMyoAcquisitionSmoke();
```

El smoke identifica sus datos como MOCK/no científicos. Verifica GUI, cambio de target, 25 trials sintéticos cortos, RAW, manifiesto y hashes. No conecta MyoMex ni entrena modelos. El screenshot documenta una GUI probada, no una sesión humana.

La interfaz usa [uigridlayout](https://www.mathworks.com/help/matlab/ref/uigridlayout.html) y captura la evidencia con [exportapp](https://www.mathworks.com/help/matlab/ref/exportapp.html). Los gráficos están encapsulados en paneles propios para conservar su encuadre en el render/export de R2023b; se revisó visualmente la imagen, además de probar los callbacks.
