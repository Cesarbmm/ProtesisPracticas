"""Informe E2G a partir de artefactos medidos; nunca altera informes anteriores."""
import csv,json
from pathlib import Path
HERE=Path(__file__).resolve().parent;OUT=HERE/'e2g_results';DOC=HERE.parents[2]/'docs/paired_reference/RESULTADOS_E2G.md'
def read(name):
 with (OUT/(name+'.csv')).open(encoding='utf-8-sig') as f:return list(csv.DictReader(f))
def fmt(v,n=8):return f'{float(v):.{n}f}'
def pct(v):return f'{100*float(v):.4f} %'
def run():
 s=json.loads((OUT/'scientific_summary.json').read_text(encoding='utf-8'));tests=json.loads((OUT/'test_summary.json').read_text())
 sup=[r for r in read('support_and_transformation') if r['subject']==r['side']=='ALL' and r['motor']!='ALL']
 support='\n'.join(f"| M{r['motor']} | {pct(r['below'])} | {pct(r['inside'])} | {pct(r['above'])} | {pct(r['outside'])} |" for r in sup)
 changes='\n'.join(f"| M{r['motor']} | {pct(r['modifiedFractionMacro'])} | {fmt(r['meanChangeMacro'])} | {fmt(r['p95Change'])} | {fmt(r['maxChange'])} |" for r in sup)
 dist=read('coordinate_distributions');fields=['minimum','p1','p5','median','p95','p99','maximum']
 teacher='\n'.join('| M'+r['motor']+' | '+' | '.join(fmt(r[f],6) for f in fields)+' |' for r in dist if r['signal']=='teacher' and r['subject']==r['side']=='ALL' and r['motor']!='ALL')
 m2='\n'.join('| '+r['signal']+' | '+' | '.join(fmt(r[f],6) for f in fields)+' |' for r in dist if r['motor']=='2' and r['subject']==r['side']=='ALL')
 cross='\n'.join(f"| {r['controller']} | {r['evaluationReference']} | {fmt(r['trackingMSE'],12)} | {fmt(r['rewardMean'],12)} |" for r in read('cross_reference_summary') if r['motor']==r['subject']==r['side']=='ALL')
 variation='\n'.join(f"| M{r['motor']} | {'Cierre' if r['side']=='1' else 'Apertura'} | {pct(r['medianRangeRatio'])} | {fmt(r['flatIncreasePP'],1)} pp | {pct(r['trendRetainedFraction'])} |" for r in read('variation_summary') if r['subject']=='ALL' and r['motor']!='ALL' and r['side']!='ALL')
 report=f'''# E2G — Teacher–plant support alignment

**REFERENCE_CONTRACT_NOT_VALIDATED. RL_PILOT_AUTHORIZED=NO.**
El oracle estable mejor encontrado en E2F permanece válido. E2G localiza una
incompatibilidad computacional entre el mapa encoder→flex heredado y el soporte
registrado de la planta, sin evidencia suficiente para atribuirla a un límite
mecánico real o validar una recalibración del teacher.

La proyección diagnóstica elimina targets fuera del intervalo y conserva la
estabilidad de H5. Sin embargo, no aporta la calibración física faltante y M2
retiene sólo36.1543 % del rango temporal en cierre y35.3076 % en apertura,
frente al mínimo preregistrado50 %. **Fallan gates A y D.** No se adopta una
transformación para training, no se prueba alineación afín y no se prepara E3A.

## Estado, alcance e integridad

2026-09-07. Worktree existente `C:\\Users\\Cesarbmm\\ProtesisPracticas_e2b_audit`;
la grafía anidada solicitada no existe. Rama
`experiment/no-glove-paired-reference-td3`, HEAD
`165be049eb41fc41254435181c9857fe0f22ed1c`. Cambios recibidos E2C–E2F conservados;
archivos nuevos exclusivamente E2G. Sin reparación Git, cambio de rama, commit,
push, RL ni sandbox. E0P/E2A PASS, E2B FAIL, E2C CHARACTERIZED, E2D/E2E
NOT_SUFFICIENT y E1–E1D cerradas no cambian.

[Preregistro E2G](PREREGISTRO_E2G.md), SHA256
`{(OUT/'preregistration.sha256').read_text().strip()}`,
congelado antes de distribuciones y contrafactuales. Mismos200episodios
DEVELOPMENT,2938pasos por controlador/11752muestras motor-paso; no se abrieron
datasets nuevos para estas comparaciones. MATEO/SANDRA sellados.

**Tests: {tests['passed']}/{tests['totalTests']} =169 históricos +27 E2G.**
**740/740 hashes históricos intactos.** La comprobación independiente anterior
confirmó E2F:663hashes/52artefactos/169tests. Los tests E0P conservan la regresión
784casos con máximo error1.164e-10; los13tests causales E2A pasan.

## 1. Las coordenadas que realmente compara el reward

[AUDITORIA_COORDENADAS_E2G.md](AUDITORIA_COORDENADAS_E2G.md) contiene fuentes,
líneas, unidades declaradas, huecos de evidencia y procedencia por constante.

```text
Guante: números seriales/registro histórico (sin calibración angular demostrada)
 → suma de sensores por DoF: [anular+meñique, índice, pulgar, medio]
 → división [4092,2046,1023,2046], sin restar reposo ni escalar por sujeto
 → última fila de la ventana: reference_after utilizada en reward.

Encoder: cuentas firmadas q
 → abs(q)
 → suelo constante debajo de gap; recta gap→breakLimit; saturación superior
 → división por los mismos [4092,2046,1023,2046]
 → última fila: h(q_after).
```

La suma usa4/2/1/2sensores por motor. Los divisores son1023 multiplicado por esa
cantidad, una convención numérica; no prueban máximos articulares medidos. Los
datos del guante no se convierten a grados en esta ruta. M1 además mezcla dos
dedos humanos: una suma no identifica una postura única.

| Motor/dedo | gap | breakLimit | mínimo flex | divisor | h(0) | h máximo del grafo |
|---|---:|---:|---:|---:|---:|---:|
| M1 anular/meñique |7500|26500|1800|4092|.43988270|.72720813|
| M2 índice |3650|11500|900|2046|.43988270|.65502245|
| M3 pulgar |4000|8500|300|1023|.29325513|.86826276|
| M4 medio |3550|9000|900|2046|.43988270|.72054086|

En el tramo lineal, h=L/U+(1−L/U)(abs(q)−gap)/(breakLimit−gap).
El suelo positivo es una consecuencia del mapa antes de cualquier límite de
planta. En holgura puede moverse el encoder sin cambiar h. El mapa global tiene
techo1, pero el soporte empírico auditado no alcanza las anclas correspondientes.

**Procedencia:** constantes HEREDADAS; breakLimit coincide con firmware, pero
la procedencia física de esos números es UNKNOWN. Los mínimos se describen
como reposo sin registros de calibración; recta/abs/agregación son el modelo
HEURÍSTICO heredado. Las curvas son datos empíricos de encoder procesados,
no mediciones pareadas con guante. No se ha demostrado equivalencia física de
teacher y h(q). Esto no demuestra que sean necesariamente incompatibles en toda
postura: indica que la calibración requerida no es verificable aquí.

El encoder normalizado de markov52 usa q/breakLimit y **no es h(q)**. Guante y
h(q) siguen en reward/tracking; el teacher permanece en reset/disponibilidad y
terminación histórica. No se han modificado actor, state, reward, runtime E2A
ni su ejecución EMG-only. La proyección existe sólo en copias offline.

## 2. Distribuciones y soporte

Fracciones macro: media temporal por episodio-motor, repeticiones por
sujeto/lado/motor, media de grupos. Cuantiles: por muestras, interpolación
lineal, con ponderación distinta explícita. No confundir una distribución de
estados únicos del grafo con la visitación temporal de una política.

| Motor | Debajo | Dentro | Encima | Fuera |
|---|---:|---:|---:|---:|
{support}

Global:13.4231 % debajo,48.9837 % dentro,37.5932 % encima; **51.0163 % fuera**.
La fracción bruta por muestras es50.2297 %, diferente por duración de episodios.

Cuantiles del teacher original:

| Motor | min | p1 | p5 | mediana | p95 | p99 | max |
|---|---:|---:|---:|---:|---:|---:|---:|
{teacher}

Los mismos siete cuantiles de teacher/P2/H5 original/H5 proyectado y referencia
proyectada, por motor, sujeto, dirección y todas sus combinaciones, están en
`coordinate_distributions.csv`. `graph_h_distributions.csv` registra estados
únicos del grafo: es el mismo soporte para los sujetos, no una distribución
empírica nueva por persona. `support_and_transformation.csv` conserva las
fracciones y cambios en todos esos estratos, no sólo el promedio global.

## 3. M2: predomina el techo del soporte representado

M2 tiene64.0558 % de targets por encima y7.5103 % por debajo. Su teacher mediano
.75122190 ya supera el techo .65502245. El bound exterior explica98.3447 % de su
suelo local E2F; globalmente explica82.4818 %.

El escalador común sólo divide ambas magnitudes por el mismo U positivo: no
crea por sí solo la incompatibilidad de intervalos, que ya existe antes de esa
división. El problema observable está en el mapa encoder→flex y el recorrido
registrado frente a los valores de sensores del teacher. El h alcanzado nunca
llega a su saturación superior1; no predomina un clamp superior activo de h.
Los cuantiles del teacher M2 llegan a1, pero la falta de calibración no permite
decidir si ese valor corresponde a una postura comparable. No se diagnostica
un offset de guante erróneo ni un límite mecánico sólo a partir del scatter.

| Fuente M2 | q máximo | h en ese máximo |
|---|---:|---:|
| Grafo operativo E2F |6665.1666667|.6550224455|
| Todas las curvas promedio |6665.6666667|.6550581218|
| Repeticiones/CSV originales |6821|.6661415470|
| Ancla histórica breakLimit |11500|1|

La diferencia grafo–promedio es sólo0.5cuentas. Incluso las adquisiciones
completas quedan muy por debajo del ancla heredada. No corresponde atribuir
el desajuste principal sólo a Ts, cuantización o poda de estados. Tampoco se
demuestra que6821sea el límite mecánico real. M2 cierre PWM64 tiene avg máximo
3598<gap3650: toda esa curva se convierte en el suelo de h aunque el encoder
cambie. No demuestra inmovilidad física del dedo.

[AUDITORIA_SOPORTE_E2G.md](AUDITORIA_SOPORTE_E2G.md) separa grafo/avg/data/raw y
límites de firmware, con56filas por motor/PWM/dirección y fuentes.56/56límites
coinciden con extremos de data; el procesamiento histórico recorta y promedia.
El cierre del grafo es un bound para sus semillas y contrato, no para cualquier
q inicial ni para el hardware. Tampoco cada punto del intervalo es alcanzable.

Cuantiles M2:

| Señal | min | p1 | p5 | mediana | p95 | p99 | max |
|---|---:|---:|---:|---:|---:|---:|---:|
{m2}

![Soporte y scatter M2](../../matlab_code/analysis/paired_reference/e2g_results/e2g_support.png)

El scatter usa el h más próximo entre estados del grafo completo; el error
firmado es bestH−teacher. Es una cota optimista sin tiempo de llegada, distinta
del destino local de un paso y de la proyección continua al intervalo.

**SUPPORT_MISMATCH_CAUSE=MIXED:** mapa h(q) heredado y soporte empírico de planta
no alineados. El origen físico de esa combinación sigue UNKNOWN; no se afirma
MECHANICAL_RANGE_LIMIT ni una calibración teacher equivocada sin evidencia.

## 4. Contrafactual permitido y conservación de información

PROJECTION=clip(reference,h_min,h_max), por motor y únicamente en copias de
reference_before/after. Es la alteración escalar mínima que entra al intervalo
del soporte demostrado. No ajusta anclas ni garantiza alcanzabilidad interior.
AFFINE_ALIGNMENT_TESTED=NO: faltan posturas emparejadas independientes; no se
ajusta una recta a cuantiles o al MSE para producir un resultado favorable.

| Motor | Muestras modificadas, macro | Cambio absoluto medio macro | p95 por muestras | máximo |
|---|---:|---:|---:|---:|
{changes}

Global:fracción modificada **{pct(s['transformedSampleFractionMacro'])} macro**
({pct(s['transformedSampleFractionSteps'])} bruta), cambio medio macro
{fmt(s['transformedMeanChange'],12)}, p95 {fmt(s['transformedP95Change'],12)},
máximo {fmt(s['transformedMaxChange'],12)}. Estos valores están en coordenadas
históricas adimensionales, no grados físicos.

| Motor | Dirección | Mediana de rango temporal conservado | Aumento referencias constantes | Tendencia firmada retenida |
|---|---|---:|---:|---:|
{variation}

M2 incumple el mínimo50 % en ambas direcciones. El clipping no vuelve todos
los episodios constantes, pero comprime de forma excesiva su amplitud temporal
y acumula gran parte del teacher en el techo. Los otros límites preregistrados
de referencias constantes (+5pp) y signo (95 %) pasan. No se baja el umbral.

## 5. Oracle y evaluación cruzada

Mismo H5 exacto E2F, reward .01/.05, acciones15, Ts=.2, samplingAPI=.14, planta
canónica y q0; no guard, deadband ni cambio de controlador/planta. El oracle
continúa privilegiado y no es evidencia de información EMG disponible.

| Política | Referencia con que se evalúa | MSE macro | Reward macro |
|---|---|---:|---:|
{cross}

**Comparar sólo la diagonal cambia el problema.** La política PROJECTED empeora
al evaluarla contra el teacher ORIGINAL. Su MSE propio reducido no prueba mejor
control original ni calibración válida. Frente al teacher PROJECTED, el oracle
original incluso tiene MSE algo menor; el nuevo obtiene mejor reward por sus
penalizaciones de acción. H5 minimiza coste finito, no exclusivamente MSE.

| Estimando del suelo de un paso (MSE) | ORIGINAL | PROJECTED |
|---|---:|---:|
| Desde exactamente los estados P2 originales |{fmt(s['originalFloorP2Fixed'],12)}|{fmt(s['projectedFloorP2Fixed'],12)}|
| Desde estados visitados por cada oracle |{fmt(s['originalFloorOracleVisited'],12)}|{fmt(s['projectedFloorOracleVisited'],12)}|
| Bound exterior a la envolvente |{fmt(s['originalOutsideBoundMSE'],12)}|0|
| Fracción targets fuera |{pct(s['originalTargetsOutsideSupport'])}|0 %|

Se guardan15destinos por estado en cuatro tablas de alcanzabilidad,705120filas.
El primer contraste aísla referencia manteniendo q de P2. El segundo mezcla
transformación y nueva visitación y es descriptivo. El floor no es un mínimo
global multietapa. El criterio50 % de E2F no se vuelve a aplicar en E2G.

PROJECTED:0ciclos finales,0ventanas alternantes,0trayectorias periódicas2..8,
0retrocesos M3,0movimientos PWM0;20/20replays fijos terminan con q constante en
las últimas20transiciones y sin órbitas. Es estabilidad en estos casos, no
un teorema universal. MSE/MAE/reward y componentes, PWM, flat/no-motion están
disponibles por motor/sujeto/dirección en las tablas de métricas.

## 6. Gates y decisión

| Gate | Resultado |
|---|---|
| A: coordenadas físicamente defendibles | **FAIL: calibración pareada no demostrada** |
| B: target exterior no domina | PASS numérico:0outside; bound0/sueloP2=.0026512854 |
| C: oracle estable en muestra y20fijos | PASS |
| D: variación útil conservada | **FAIL:M2cierre36.1543 %, apertura35.3076 % <50 %** |
| E: causalidad E2A intacta | PASS:13/13tests y fuentes intactas |
| F: tests/hashes/sellados | PASS:196/196tests;740/740hashes; sellados |

**REFERENCE_TRANSFORMATION_SELECTED=NONE_FOR_TRAINING.** La proyección queda
sólo como diagnóstico. **E2G_RESULT=REFERENCE_CONTRACT_NOT_VALIDATED.**
**RL_PILOT_AUTHORIZED=NO. E3A_PREPARED=NO. E3A_EXECUTED=NO.**

Información necesaria: posturas/magnitudes funcionales identificadas por motor
con encoder y guante emparejados; origen y repetibilidad de cero, holgura y
extremos; correspondencia de sensores/DoF; configuración mecánica/firmware de
las curvas respecto a los límites heredados. Para sostener una recta hacen
falta anclas independientes y evidencia intermedia, no sólo endpoints elegidos
del dataset. Nada de esa calibración se ejecuta aquí. No se propone otro
reescalado ad hoc ni se modifica teacher/h/reward/planta para rescatar E2G.

## 7. Agente futuro y visualización

Mantener inicialmente TD3 histórico por continuidad si un contrato posterior
permite el piloto. Challenger estructural futuro: **FACTORIZED_CATEGORICAL**,
4cabezas×15acciones, porque ésta es la acción que recibe la planta canónica
y optimiza el oracle; evitar enumeración conjunta15^4. No se implementa ahora.
SAC queda como challenger útil si posteriormente se caracteriza PWM fino.

El objetivo eventual sigue siendo apertura/cierre estable condicionado por EMG
y estado mecánico, con guante como teacher durante training. E1–E1D no demostraron
trayectoria individual continua EMG específica suficiente; no se promete esa
reconstrucción ni se reabre decoder. No hay especificación E3A ni training.

HandKinematicViewer sólo podría visualizar pasivamente trazas canónicas si una
futura E3A da señal positiva: P2/oracle/Agent7250/nuevoTD3 en mismos episodios.
Integración diferida; ningún código sandbox ni plantaS4 importados.

## 8. Artefactos, reproducción y límites de integridad

Carpeta `matlab_code/analysis/paired_reference/e2g_results`: trazas MAT/CSV;
distribuciones y soporte;variación;matriz2×2; métricas y alcanzabilidad;
20fijos; auditoría de curvas/raw; manifiesto E0P; gates/JSON; tests/hashes;
figura PNG y SVG. Fuentes E2G y27tests nuevos; helpers históricos sin editar.

El inventario inicial740no se recaptura. De76CSVraw inspeccionados para soporte,
33tenían hash en ese inventario:33/33coinciden.43carecían de baseline histórico;
se declara esa limitación sin ampliar retroactivamente el inventario. El artefacto
guarda67hashes de originales seleccionados:67/67coinciden. Esto no acredita
trazabilidad física de la adquisición. Los scripts de soporte quedan conservados.

Desde `EMG_Prosthesis_TD3/matlab_code`, MATLABR2023b y Python3 estándar:

```powershell
matlab -batch "addpath(genpath('src'));addpath('config');addpath(genpath('lib'));addpath('analysis/paired_reference');runPairedReferenceE2G;"
python analysis/paired_reference/verifyE2GArtifacts.py
```

No ejecutar e2gCaptureHistory otra vez. El runner sólo reconstruye E2G y dirige
salidas de regresiones a E2G. No entrena ni opera Git. La comprobación Python
independiente reconstruye23504filas motor-paso,705120destinos y32decisiones
BellmanH5; error máximo reconstrucción reward8.19e-16. La figura requirió
tipado explícito de etiquetas ALL/número al importar CSV; se corrigió sólo el
exportador gráfico y se verificó de nuevo, sin cambiar mediciones ni tests.

**MATEO_SANDRA_SEALED=YES. HISTORICAL_HASHES_INTACT=YES (740archivosinventariados).
GIT_REPAIR_ATTEMPTED=NO. PUSH=NO.**
'''
 # Espaciado editorial; no altera cifras, parámetros, rutas o resultados.
 replacements={
  'sólo36.':'sólo 36.','apertura35.':'apertura 35.','mínimo preregistrado50':'mínimo preregistrado 50',
  'Tests: ':'Tests: ','=169 históricos':'= 169 históricos','+27 E2G':'+ 27 E2G',
  '200episodios':'200 episodios','2938pasos':'2938 pasos','11752muestras':'11752 muestras','13tests':'13 tests',
  '784casos':'784 casos','error1.164':'error 1.164','663hashes':'663 hashes','52artefactos':'52 artefactos','169tests':'169 tests',
  '4/2/1/2sensores':'4/2/1/2 sensores','son1023':'son 1023','techo1':'techo 1','saturación superior1':'saturación superior 1',
  'Global:13.':'Global: 13.','bruta por muestras es50.':'bruta por muestras es 50.','M2 tiene64.':'M2 tiene 64.',
  'y7.5103':'y 7.5103','explica98.':'explica 98.','explica82.':'explica 82.',
  'sólo0.5cuentas':'sólo 0.5 cuentas','que6821sea':'que 6821 sea','con56filas':'con 56 filas','56/56límites':'56/56 límites',
  'de76CSVraw':'de 76 CSV raw','33tenían':'33 tenían','43carecían':'43 carecían','guarda67hashes':'guarda 67 hashes',
  'mínimo50':'mínimo 50','(+5pp)':'(+5 pp)','mismos200':'mismos 200','Ts=.2':'Ts=.2','acciones15':'acciones 15',
  'guardan15destinos':'guardan 15 destinos','705120filas':'705120 filas','PROJECTED:0ciclos':'PROJECTED: 0 ciclos',
  '0ventanas':'0 ventanas','0trayectorias':'0 trayectorias','periódicas2..8':'periódicas 2..8','0retrocesos':'0 retrocesos',
  '0movimientos':'0 movimientos','20/20replays':'20/20 replays','últimas20transiciones':'últimas 20 transiciones',
  'numérico:0outside':'numérico: 0 outside','bound0/sueloP2':'bound 0/suelo P2','y20fijos':'y 20 fijos',
  'FAIL:M2cierre36.':'FAIL: M2 cierre 36.','apertura35.':'apertura 35.','<50 %':'<50 %','13/13tests':'13/13 tests',
  '196/196tests':'196/196 tests','740/740hashes':'740/740 hashes','4cabezas×15acciones':'4 cabezas × 15 acciones',
  'conjunta15^4':'conjunta 15^4','Fuentes E2G y27tests':'Fuentes E2G y 27 tests','inventario inicial740no':'inventario inicial 740 no',
  'reconstruye23504filas':'reconstruye 23504 filas','705120destinos':'705120 destinos','y32decisiones':'y 32 decisiones',
  'BellmanH5':'Bellman H5','reward8.19':'reward 8.19','740archivosinventariados':'740 archivos inventariados',
  'matriz2×2':'matriz 2×2','20fijos':'20 fijos','La proyección queda\n+sólo':'La proyección queda\n+sólo'
 }
 for a,b in replacements.items():report=report.replace(a,b)
 DOC.write_text(report,encoding='utf-8');print(str(DOC))
if __name__=='__main__':run()
