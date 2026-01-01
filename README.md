# blackios 🖤

**blackios** es una aplicación de utilidades para iOS que ofrece un conjunto de herramientas para explorar y editar archivo y datos en el dispositivo: navegador de archivos, editor de texto, visor de imágenes y fuentes, editor de PLIST, visor de SQLite, gestión de apps y más.

> Nota: Este repositorio incluye un `RootHelper` con licencia GNU GPLv3 (ver `RootHelper/LICENSE`). Asegúrate de revisar las licencias de los componentes incluidos antes de redistribuir.

---

## 🎯 Características principales

- Explorador de archivos (`FileBrowserViewController`) 🔍
- Editor de texto (`TextEditorViewController`) ✍️
- Visor de imágenes (`ImageViewerViewController`) 🖼️
- Visor de fuentes (`FontViewerViewController`) 🔤
- Visor de SQLite (`SQLiteViewerViewController`) 🗄️
- Editor de PLIST (`PlistEditorViewController`) 📋
- Lista de aplicaciones (`AppListViewController`) 📦
- Gestión de ajustes (`SettingsViewController`) ⚙️
- `RootHelper` para operaciones con privilegios cuando sea necesario

---

## 🛠️ Requisitos y construcción

### Requisitos

- Theos (para compilar) — https://theos.dev/
- make, clang (toolchain compatible con Theos)
- `curl` y `zip` (utilizados por el script de empaquetado)

### Construcción rápida

Puedes compilar y empaquetar la aplicación con el script incluido:

```bash
# Ejecutar desde la raíz del proyecto
./ipabuild.sh
```

El script compila la app y el `RootHelper`, firma binarios con `ldid` (se descarga automáticamente) y genera `build/blackios.tipa`.

También puedes compilar manualmente con:

```bash
make
# y (opcional) compilar RootHelper
cd RootHelper && make
```

---

## ⚠️ Instalación en dispositivo

- El método de instalación varía según tu entorno (jailbroken o no). El script `ipabuild.sh` genera `build/blackios.tipa`.
- Firma y distribución: asegúrate de usar métodos y certificados apropiados para instalar aplicaciones en tus dispositivos.

> Si no estás seguro de cómo instalar el paquete, describe tu entorno y te puedo guiar con pasos más concretos.

---

## 🧩 Estructura y recursos

- Localizaciones: `Resources/*.lproj`
- Iconos: `Resources/Icons` y `Resources/Icons/icon`
- Script de empaquetado: `ipabuild.sh`
- Makefile: configuración de Theos y listados de archivos fuente

---

## 🤝 Contribuciones

Las contribuciones son bienvenidas:

1. Abre un issue describiendo la característica o bug.
2. Crea un fork, realiza los cambios y envía un pull request.

Por favor respeta el estilo del código (Objective-C / Theos) y añade tests si aplica.

---

## 📜 Licencia

- El `RootHelper` incluye licencia **GNU GPL v3** (ver `RootHelper/LICENSE`).
- Otros componentes pueden tener licencias propias (revisa los archivos relevantes y `RootHelper/README.md` para créditos).

---

## � Donaciones

Si deseas apoyar el desarrollo del proyecto, puedes hacerlo a través de PayPal:

- [PayPal.me/BLACKIOS26](https://www.paypal.me/BLACKIOS26)

Gracias por cualquier aporte — cada donación ayuda a mantener y mejorar el proyecto. 🙏

---

## �📬 Contacto

Si necesitas que el README incluya capturas, badges, instrucciones de instalación más detalladas o una versión en inglés, dímelo y lo adapto. ✅
