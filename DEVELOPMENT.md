# Baker Reader — continuidad del trabajo

Aplicación Android en Flutter 3.47.2 / Dart 3.13.2. El identificador Android y la carpeta interna `inkvault` se mantienen para conservar bibliotecas existentes. Nombre visible: Baker Reader.

## Cambios de esta versión

- Selección persistente con ajuste de esquinas y movimiento; Guardar abre la vista previa y la nota, Cancelar no crea ninguna anotación.
- Varios trazos antes de guardar; entrada con dedo activada por defecto en móviles, con botón para alternarla en tablets.
- Guardado serializado y copia de recuperación de anotaciones. Los dibujos guardados se muestran sin activar la edición. Los documentos originales no se sobrescriben.
- CBR/RAR4 y RAR5 mediante `rar`/libarchive; CBZ mediante ZIP. Archivos dañados, cifrados sin contraseña o incompatibles muestran errores.
- Ajustes para vincular una carpeta de Obsidian mediante Android SAF con permiso persistente, elegir una subcarpeta y exportar notas individuales con imágenes. Cada nota usa un nombre estable, evitando sobreescribir otras notas del libro.
- Marca de panadería, panel adaptable y controles con salto de línea en pantallas pequeñas.

## Comprobación

`flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --release --split-per-abi`.

GitHub Actions publica `baker-reader-apks` para ramas `codex/**`, pull requests y main. Desde una tablet Android se puede revisar esta rama en Codex cloud y descargar el artefacto de la ejecución correspondiente.

## Comprobaciones en dispositivo

Probar PDF, EPUB, CBZ y CBR4/5 reales; seleccionar, ajustar, cancelar y guardar; cerrar el proceso y reabrir; girar dispositivo; comprobar zoom y posición de trazos; vincular una carpeta local de Obsidian, exportar imagen y nota, revocar permiso y volver a vincular. La alineación de tinta sobre EPUB depende del ancla y del diseño del texto; la imagen de la anotación conserva su aspecto en el panel y en Obsidian.

La APK de desarrollo sigue usando firma debug como el proyecto original. Si una instalación anterior tiene otra firma, Android rechazará la actualización: no desinstalar sin exportar primero los datos.
