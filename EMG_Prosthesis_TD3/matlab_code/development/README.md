# Development Archive

`development/` deja de ser una carpeta de trabajo ambigua y pasa a ser archivo historico formal.

## Regla

- no usar nada de aqui como punto de entrada operativo
- no agregar nuevos experimentos aqui
- si una utilidad vuelve a ser relevante, migrarla a `src/`, `workflows/` o `analysis/`

## Estado actual

- `archive/check_dataset_legacy/`: inspeccion temprana del dataset previo a la linea actual
- `archive/parallel_computing_trials/`: pruebas antiguas de ejecucion en paralelo
- `archive/adapt_dataset_denis_raw/`: scripts y datos fuente usados para convertir el dataset Denis
- `archive/simulator_creation_assets/`: scripts y artefactos de identificacion del simulador

## Valor de procedencia

- `adapt_dataset_denis_raw/` se conserva porque documenta como se genero `data/datasets/Denis RAW 0/`
- `simulator_creation_assets/` se conserva porque es la procedencia de los artefactos que luego alimentaron `src/@SimController/`

## Que no se migra por ahora

- `check_dataset_legacy/` y `parallel_computing_trials/` quedan solo como referencia historica
- `examples/` queda como coleccion de snippets legacy
- `episodes/FINAL/` queda como muestra pequena de episodios guardados para inspeccion manual
