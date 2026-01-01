# Mejoras de Tipografía y Peso de Fuente

## Resumen de cambios

Se ha implementado un sistema completo de tipografía para la aplicación iOS **blackios** que proporciona una jerarquía visual clara mediante diferentes pesos de fuente y tamaños.

## Archivo principal: Typography.h y Typography.m

Se creó una clase `Typography` que centraliza toda la configuración de fuentes de la aplicación. Esta proporciona métodos de clase para obtener fuentes preconfigutadas en diferentes categorías:

### Categorías de Tipografía

#### Títulos (Titles)
- `titleLarge` - 28pt, Bold - Para títulos principales de pantalla
- `titleMedium` - 24pt, Semibold - Para títulos de navegación
- `titleSmall` - 20pt, Semibold - Para títulos secundarios

#### Encabezados (Headlines)
- `headlineLarge` - 20pt, Semibold - Para encabezados principales
- `headlineMedium` - 18pt, Semibold - Para encabezados de sección
- `headlineSmall` - 16pt, Medium - Para encabezados pequños

#### Cuerpo de Texto (Body Text)
- `bodyLarge` - 16pt, Regular - Para textos principales de lista
- `bodyMedium` - 14pt, Regular - Para textos secundarios
- `bodySmall` - 12pt, Regular - Para textos en código o monoespaciado

#### Etiquetas (Labels)
- `labelLarge` - 14pt, Medium - Para etiquetas de botones
- `labelMedium` - 12pt, Medium - Para etiquetas pequñas
- `labelSmall` - 11pt, Medium - Para etiquetas muy pequñas

## Controladores Actualizados

### 1. **AppListViewController.m**
- ✅ Importa `Typography.h`
- ✅ Aplica `titleMedium` al título de navegación
- ✅ Aplica `bodyLarge` al texto de las celdas de aplicación

### 2. **FileBrowserViewController.m**
- ✅ Importa `Typography.h`
- ✅ Aplica `bodyMedium` al texto de los archivos en la tabla
- ✅ Aplica `labelMedium` a los botones de ordenamiento (Nombre, Fecha, Tamaño)

### 3. **TextEditorViewController.m**
- ✅ Importa `Typography.h`
- ✅ Usa monoespaciado estándar (13pt) para el código

### 4. **HexViewerViewController.m**
- ✅ Importa `Typography.h`
- ✅ Aplica `bodySmall` para el texto hexadecimal

### 5. **ImageViewerViewController.m**
- ✅ Importa `Typography.h`

### 6. **FontViewerViewController.m**
- ✅ Importa `Typography.h`
- ✅ Aplica `labelMedium` a las etiquetas de tamaño de fuente

### 7. **SQLiteViewerViewController.m**
- ✅ Importa `Typography.h`
- ✅ Aplica `bodyMedium` a los nombres de filas/tablas
- ✅ Aplica `bodySmall` a los detalles de datos
- ✅ Aplica `labelSmall` a las etiquetas descriptivas

### 8. **blackRootViewController.m**
- ✅ Importa `Typography.h`

## Ventajas de esta Implementación

1. **Jerarquía Visual Clara**: Los diferentes tamaños y pesos de fuente crean una estructura visual evidente
2. **Consistencia Global**: Todos los controladores usan las mismas definiciones de fuente
3. **Mantenimiento Fácil**: Cambiar el tamaño o peso global de una categoría se hace en un solo lugar
4. **Escalabilidad**: Fácil de extender con nuevas categorías si es necesario
5. **Accesibilidad**: Los tamaños siguen las directrices de Apple para legibilidad

## Cómo Usar

Para usar las fuentes en nuevos código, simplemente incluye:

```objc
#import "Typography.h"

// Ejemplo: aplicar una fuente a una etiqueta
label.font = [Typography bodyLarge];
```

## Estilos de Peso de Fuente Utilizados

- **Bold**: 28pt (títulos principales)
- **Semibold**: 24pt y 20pt (títulos y encabezados)
- **Medium**: 18pt, 16pt, 14pt y 12pt (encabezados pequeños y etiquetas)
- **Regular**: 16pt y 14pt y 12pt (cuerpo de texto)

Esta estructura proporciona un sistema tipográfico escalable y profesional que mejora significativamente la legibilidad y la experiencia visual de la aplicación.
