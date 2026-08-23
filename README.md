# InkVault Reader

Lector ligero y rápido con anotaciones para stylus, pensado para tablets Android con pantallas tipo papel (TCL NXTPAPER). Tema oscuro exclusivo, sin cuentas, sin telemetría y **100% local**.

## Formatos soportados (una sola biblioteca)

| Formato | Motor | Notas |
|---------|-------|-------|
| PDF | `pdfx` (PdfRenderer nativo) | Render de páginas a alta resolución |
| ePub | `epub_view` | Posición guardada con CFI |
| CBZ / CBR | `archive` | Extracción de imágenes, lectura página a página |

Sobre CBR: muchos `.cbr` son ZIP renombrados y abren sin problema. Los CBR con compresión RAR real requieren conversión a CBZ; la app lo detecta y avisa.

## Anotaciones con stylus

- El dedo siempre pasa página; el stylus anota (distinguido con `PointerDeviceKind.stylus`).
- Herramienta lápiz: dibujo y subrayado a mano alzada.
- Herramienta recorte: selección rectangular de la página, guardada como PNG en alta calidad.
- Cada anotación admite una nota de texto.
- Panel lateral con todas las anotaciones del libro: miniatura, nota y salto a la página.

## Exportación a Obsidian

Botón "Exportar a Obsidian" por libro. Se elige la carpeta del vault con el selector del sistema (SAV vía `file_picker`) y se genera:

```
<vault>/
└── Mi Libro/
    ├── Mi Libro.md
    └── attachments/
        ├── mi-libro_pag12_1a2b3c.png
        └── ...
```

El Markdown incluye frontmatter YAML:

```yaml
---
titulo: Mi Libro
autor: Autor
formato: pdf
fecha_exportacion: 2026-08-23T15:00:00
---
```

y cada anotación como callout:

```markdown
> [!note] Recorte · pág 12
> Idea clave del capítulo
> ![[attachments/mi-libro_pag12_1a2b3c.png]]
```

## Compilar

```bash
flutter pub get
flutter build apk --release --split-per-abi
```

Las APKs se generan automáticamente en cada push a `main` (y manualmente con *workflow_dispatch*) mediante GitHub Actions y quedan como artefactos descargables.

## Privacidad

Sin permisos de almacenamiento (usa SAF), sin INTERNET, sin analítica. Todo vive en el almacenamiento local de la app y en el vault que tú elijas.
