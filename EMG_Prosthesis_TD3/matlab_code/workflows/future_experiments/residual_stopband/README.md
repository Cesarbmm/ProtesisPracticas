# Residual Stop-Band Pausado

Contiene los flujos de discovery/confirmation para seleccionar checkpoints
residuales dentro de una ventana alrededor del episodio 2000.

Motivo de pausa: stop-band queda como experimento util, pero la prioridad
actual es volver al TD3 base y diagnosticar el motor 2 sin mezclar la rama
residual.

Los archivos se preservan sin borrar resultados historicos. Para retomarlo,
cargar `matlab_code/` con `addpath(genpath(pwd))` y ejecutar los launchers
por nombre.
