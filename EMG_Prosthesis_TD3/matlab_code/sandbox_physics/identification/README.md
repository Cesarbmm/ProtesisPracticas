# identification/ — S4, NO ABIERTA

Esta carpeta está vacía a propósito. La identificación de una planta dinámica reducida no
empieza hasta que S1 y S2 estén aprobados y se muestren resultados.

Cuando se abra, estas restricciones ya están decididas y no se renegocian:

1. **Se ajusta contra `pattern_curve.mat`**, no con parámetros J/B/Kt inventados. Un modelo
   con parámetros heurísticos no es "la física real" por muy suave que se vea.
2. **Partición honesta**: cada curva guarda entre 3 y 6 repeticiones crudas en `data`
   (medido en la auditoría S0, hallazgo F8). Se ajusta con un subconjunto de repeticiones y
   se valida con el resto. No se valida con exactamente los mismos puntos del ajuste.
3. **Se ajusta por motor y, si los datos lo exigen, por dirección.** Antes de dar un
   parámetro independiente a cada nivel PWM hay que comprobar si una relación compartida
   PWM → ganancia/velocidad explica los niveles.
4. **Expectativa escrita antes de ver el error**: 38 de las 56 curvas promedio **no** son
   monótonas (hallazgo F9). Un modelo de primer o segundo orden no podrá reproducir esas
   ondulaciones. Si el ajuste sale "limpio", hay que preguntarse si el modelo suaviza ruido
   o si simplemente no representa el dato.
5. **Métricas mínimas**: RMSE/MAE de trayectoria, error de posición final, tiempo de subida
   y establecimiento cuando sean interpretables, error de dirección/monotonicidad,
   respuesta al cambio de signo de PWM, y desglose por motor, dirección y nivel PWM.
6. **Soporte de los datos**: el recorrido alcanzable por motor está en
   `sandboxPlantReachableRange`. Fuera de él el modelo extrapola y hay que decirlo.
7. **Preregistro propio** antes de ajustar el primer parámetro.

Modelos candidatos, de menor a mayor complejidad: M1 primer orden con `q∞(u)` y constante
de tiempo; M2 segundo orden fenomenológico con estado `[q, dq]`; M3 identificación discreta
en espacio de estados. Empezar por el más simple y subir sólo si el dato lo exige.
