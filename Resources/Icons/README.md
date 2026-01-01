# Iconos para Formatos de Archivo

Esta carpeta contiene iconos personalizados para diferentes formatos de archivo utilizados en el navegador de archivos.

## Formatos Soportados

- folder.png - Icono para carpetas
- file.png - Icono genérico para archivos sin extensión
- txt.png - Archivos de texto
- zip.png - Archivos ZIP
- plist.png - Archivos PLIST
- pdf.png - Archivos PDF
- ... (agregar más según sea necesario)

## Notas

- Los iconos deben ser imágenes PNG con resolución adecuada para iOS (ej. 29x29, 40x40, etc.).
- El código en FileBrowserViewController.m buscará iconos en esta carpeta basándose en la extensión del archivo.
- Si no se encuentra un icono específico, se usará el icono genérico o el de sistema.
