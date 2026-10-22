# Protocolo Myo continuo v1

El objetivo es obtener RAW reutilizable para estudiar calibración de usuario y recolocación del brazalete. Esta rama no entrena modelos ni mueve una prótesis.

**El target es intención instruida mediante una pantalla. No mide cuánto se abrió la mano.** Sin sensor externo, `measured_aperture=[]` y `measured_aperture_available=false` en todos los trials.

## Condiciones y tiempos congelados antes de adquirir datos reales

`buildMyoContinuousProtocol` devuelve la tabla completa antes de iniciar. La configuración predeterminada es:

| Elemento | Valor v1 |
|---|---|
| Repeticiones | 5 por condición activa |
| HOLD | 25, 50, 75 y 100% de apertura instruida |
| Rampas de apertura | 0→25, 25→50, 50→75, 75→100% |
| Rampas de cierre | 100→75, 75→50, 50→25, 25→0% |
| Velocidad slow / normal | 4 / 2 segundos por rampa |
| Fast | 1 segundo, disponible en configuración pero desactivada por defecto |
| Preparación | 2 segundos mostrando el punto inicial |
| Hold al alcanzar target | 4 segundos (GUI: 3–5 s) |
| REST | 6 segundos antes del primer activo y después de cada activo (GUI: 5–10 s) |

Un HOLD incluye preparación a 0%, rampa normal al nivel solicitado y hold. Una rampa parcial incluye preparación a su inicio, rampa al final y hold. El default produce 201 trials contando los descansos, unos 24,8 minutos nominales. No se infiere posición mecánica inicial; la preparación también es una instrucción visual.

### Semántica de `includeRamps=false` (aclaración V1, sin cambiar matemática)

Este flag omite las filas **RAMP adicionales**; no suprime la transición de las filas HOLD. El piloto reducido de una repetición contiene nueve filas: REST, HOLD25, REST, HOLD50, REST, HOLD75, REST, HOLD100, REST. Cada HOLD conserva **PREPARE 2 s + transición 2 s + HOLD 3 s**. Cada REST dura 6 s: 58 s nominales de protocolo, además del precheck.

La GUI V1 muestra `CIERRA LA MANO / Posición inicial 0 %`, después `ABRE PROGRESIVAMENTE HASTA XX %`, y finalmente `MANTÉN XX %` con tiempo restante de esa fase. En cierre, la preparación usa `target_start` y la transición dice `CIERRA PROGRESIVAMENTE HASTA XX %`. No se cambió `myoProtocolTarget` ni la tabla matemática. REST muestra `RELAJA LA MANO / REST no equivale a 0 %`.

Las imágenes de `acquisition/references` son guías orientativas; no son mediciones ni prescriben la postura de REST. La imagen de transición aportada tiene una flecha de apertura: para cierre se usa el fallback textual para evitar una instrucción contradictoria. La práctica usa estas mismas instrucciones sin crear sesión ni archivos.

La tabla incluye `condition_id`, dirección, velocidad, repetición, target inicial/final y duración de cada fase. Se guarda `protocol.csv` al crear la sesión. No se cambia el protocolo después de ver la señal. La duración observada puede exceder ligeramente la nominal por la planificación de callbacks y el guardado; se registra aparte.

## REST y descansos

REST significa **relajar**, sin prescribir mano abierta ni cerrada. `rest_intent=true`, `target_start/end=NaN` y `target_aperture=NaN`. La barra se vuelve gris y la pantalla indica reposo. El descanso no es una categoría de apertura cero.

No solicitar contracción máxima prolongada. Ajustar los tiempos y repeticiones antes de la sesión; pausar o abortar ante fatiga/molestia. El operador puede ampliar descansos con Pausa. El prefijo queda guardado y el trial se reinicia con otro ID al continuar; no se concatena una contracción interrumpida como si fuera continua.

## Participante, sesión y colocación

Usar IDs seudónimos nuevos (`P001`, `S01`) sin nombres personales en archivos. Registrar brazo y nota de orientación. Para estudiar recolocación: terminar S01/P1, retirar y recolocar Myo, abrir otra GUI y registrar S02/P2. La aplicación rechaza una sesión que ya existe y nunca mezcla colocaciones automáticamente. Registrar si cambió el día, postura, orientación o brazo en metadata.

## Calidad previa y durante captura

Antes de iniciar: 30 s con ocho canales visibles, reposo y movimiento suave según el operador. La prueba no determina apertura ni sirve para elegir retrospectivamente señales bonitas. Se conserva RAW y el informe previo.

Umbrales de aviso v1: 8 canales; datos finitos; timestamps finitos y estrictamente crecientes; frecuencia por timestamps entre 180–220 Hz; rango de canal >1e-12; clipping en los extremos de la escala SDK >1% por canal; filas consecutivas idénticas >5% como diagnóstico de repetición, **no prueba de dropout**. También se registra muestras/tiempo de llegada host. Los avisos quedan guardados, no filtran ni corrigen datos ni excluyen automáticamente trials.

MyoData reconstruye los tiempos y el proveedor puede rellenar muestras faltantes. Un Fs nominal de 200 Hz y cero gaps en esos timestamps no certifican ausencia de pérdidas. Ver [auditoría API](MYOMEX_API_AUDIT.md).

## Primera prueba física, exclusivamente manual

Una persona, una colocación, una sesión, una repetición: REST y HOLD25/50/75/100, con descansos; sin rampas parciales adicionales. El comando exacto está en la [guía de GUI](MYO_GUI_USER_GUIDE.md). Su objetivo es validar conexión, unidades, tiempo, señal y escritura. No se entrenan algoritmos con esta prueba.
