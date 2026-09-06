# results/

Salidas de las corridas del sandbox. Se rellena al ejecutar; el repositorio no necesita
versionar los artefactos pesados (GIF, frames PNG, `.mat` de trazas) salvo que se decida
explícitamente al cerrar una fase.

```
results/
├── s1_canonical_replay/    s1_summary.json, s1_replay_traces.csv,
│                           s1_replay_trajectories.mat, plant_manifest.json
└── s2_viewer/              replay_<sujeto>_side<n>.gif, frames_*/, pose_sequence_*.csv
```

Lo que **sí** conviene versionar al cerrar S1/S2: `s1_summary.json` y el
`PREREGISTRO_SANDBOX.md` relleno. Son los dos archivos que permiten reproducir el veredicto
sin volver a correr nada.
