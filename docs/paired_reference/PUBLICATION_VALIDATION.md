# Validación de la publicación

La publicación contiene código, tests con sus aserciones intactas, preregistros y resúmenes. No contiene los modelos ni las colecciones extensas de figuras usadas por algunas regresiones históricas. No equivale a distribuir nuevamente el dataset o todas las corridas.

## Procedimiento local

Desde la raíz del worktree de publicación:

```powershell
python tools/publication/prepare_local_fixtures.py
python tools/publication/audit_fixture_paths.py
python tools/publication/bind_test_fixtures.py prepare
```

Los fixtures se copian desde el archivo científico autorizado a rutas ignoradas por Git. Son copias independientes, nunca hardlinks: las pruebas no pueden sobrescribir el archivo original a través de un enlace. No se copian datos originales ni trayectorias del test final sellado. Los punteros a smokes previamente válidos se usan únicamente como fixtures; no se ejecuta otro training.

En MATLAB, desde `EMG_Prosthesis_TD3/matlab_code`:

```matlab
summary = runPublicationRegressions();
```

La suite se descubre a partir de los archivos `test*.m`, sin fijar artificialmente el total. Se guardan inventario y resultados por prueba en `analysis/paired_reference/publication_results/`. No se invoca `runFinalSealedTest` ni `sealedLoadData`. Los tests finales existentes comprueban preregistro, existencia de archivos y hash del agente congelado; la comprobación de existencia no abre el contenido raw.

Restaurar los manifiestos originales **antes de publicar**:

```powershell
python tools/publication/bind_test_fixtures.py restore
python tools/publication/verify_publication.py
git diff --check
```

## Adaptación de ubicación, sin cambiar los tests

Los tests históricos E3C/E3D excluyen explícitamente el exportador de viewer de sus hashes antiguos porque su extensión fue autorizada en etapas posteriores. Esa excepción compara una ruta absoluta con el root actual. Al copiar el worktree, el root cambia pero los manifiestos siguen apuntando al archivo original.

El binding temporal cambia **sólo el path de esa excepción ya existente**, en dos copias de manifiestos. No cambia SHA esperados, no elimina filas y no altera ninguna aserción. Los manifiestos originales se respaldan byte a byte y se restauran antes de commit. Otros paths absolutos permanecen como anclas al archivo histórico, tal como exigen los tests originales. El registro local `fixture_binding_audit.json` identifica ambos hashes y cambios.

La primera pasada fallida se conserva localmente. Sirvió para identificar fixtures omitidos y esa dependencia de ubicación. No debe confundirse con una nueva comparación científica o con una reapertura del test final.

Esta batería verifica la publicación en el entorno local con su archivo de regresión disponible. En una máquina nueva se necesitan los fixtures autorizados; no se presenta como una CI autosuficiente sin modelos o artefactos externos.

## Formato de la copia publicada

`git diff --check` detectó espacios heredados en líneas de código vacías. Se retiraron únicamente esos espacios en 27 archivos de la copia (incluido un test), sin cambiar instrucciones, aserciones, constantes ni comentarios. El archivo científico original permanece intacto. `PUBLICATION_MANIFEST.csv` conserva el SHA256 original en `sha256` y el de publicación en `publication_sha256`; las filas afectadas explican el ajuste. `verify_publication.py` comprueba esa equivalencia exacta tras normalizar sólo líneas vacías. Las regresiones se ejecutaron nuevamente sobre la copia con este formato.

Los preregistros Markdown conservan sus bytes originales, incluidos los dos espacios de salto de línea Markdown. `.gitattributes` documenta esa regla de formato.

Las reglas históricas E0P/E2A/E2B de `.gitattributes` se conservan y se amplían al archivo publicado. Esto impide que `core.autocrlf` cambie los bytes al añadir CSV, JSON, preregistros o código a Git. La verificación compara también los blobs del índice con `publication_sha256`; conservar el hash en disco por sí solo no bastaría.
