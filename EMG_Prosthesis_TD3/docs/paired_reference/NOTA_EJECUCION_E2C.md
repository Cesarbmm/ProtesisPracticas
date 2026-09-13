# E2C — precisiones de ejecución y procedencia

2026-09-06. El preregistro permanece intacto (SHA256
`bddb7f8f45b6e6e9cbceb45f3c082c2d1a1694b60ed2de3bb1ec3ca1a46d4013`).

La frase «no se cargan archivos originales de sujetos» del preregistro fue
demasiado amplia: describe el análisis causal nuevo, que usa exclusivamente las
trayectorias guardadas E2B. La batería histórica exigida sí carga BLANCA fila 1
mediante su loader DEVELOPMENT, como ya hacía en E2A/E2B, además de fixtures
temporales. Se declara esta desviación literal; no se cambian tests históricos
para evitarla ni se presentan esas regresiones como nuevas comparaciones E2C.
Los tests que mencionan sujetos sellados verifican rechazo mediante un espía
antes de I/O. MATEO/SANDRA no se abren, cargan ni comparan.

Dos tests históricos llaman genpath sobre toda la raíz MATLAB. Como esa raíz
contiene archivos ajenos, e2cRunTests interpone una fixture TEMP con lista explícita
src/config/lib/analysis/paired_reference/tests/paired_reference/agents. No enumera
ni añade sandbox_physics. El cuerpo original de genpath se conserva para las
demás rutas. Los tests originales no cambian, y se verifica ausencia de sandbox
en el path antes y después. Esta adaptación de infraestructura no cambia la
planta, el actor ni las condiciones de las pruebas científicas.

La evidencia individual M3 usa dos denominadores: todas las columnas para el
delta en índices comunes, y sólo columnas con cruce del mismo q para el mapa
individual. No se convierte una repetición sin cruce en un HOLD que cuente como
ausencia de reversión. Cinco celdas PWM255 llegan al final del vector promedio
antes de completar 200 índices; los CSV conservan ese indicador y la disponibilidad
de un horizonte completo en el registro original. No se extrapolan esos datos.

No se cambiaron gates ni parámetros tras medir. Las pequeñas correcciones durante
implementación afectaron sólo archivos nuevos E2C: ruta del oráculo para cobertura,
orden de una columna en una expectativa de test y tratamiento de un intervalo
unitario en un dominio sintético. No cambiaron los tres intervalos reales ni
las clasificaciones medidas. E2B sigue FAIL y RL no está autorizado.
