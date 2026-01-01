#!/bin/bash

# Script para construir, firmar y empaquetar la aplicación blackios y su RootHelper.

set -e

cd "$(dirname "$0")"

# --- 1. CONFIGURACIÓN INICIAL ---
WORKING_LOCATION="$(pwd)"
APPLICATION_NAME=blackios
ROOT_HELPER_NAME=BlackHelper
CONFIGURATION=Debug

# Rutas de Entitlements
APP_ENTITLEMENTS="$WORKING_LOCATION/$APPLICATION_NAME.entitlements"
ROOT_HELPER_ENTITLEMENTS="$WORKING_LOCATION/RootHelper/entitlements.plist"

# --- 2. ASEGURAR LA VERSIÓN CORRECTA DE ldid ---
LDID_PATH="/tmp/ldid-procursus"
ARCH=$(uname -m)

echo "==> Verificando y descargando ldid de Procursus ($ARCH)..."

if [ "$ARCH" = "x86_64" ]; then
    URL="https://github.com/ProcursusTeam/ldid/releases/download/v2.1.5-procursus7/ldid_linux_x86_64"
elif [ "$ARCH" = "aarch64" ]; then
    URL="https://github.com/ProcursusTeam/ldid/releases/download/v2.1.5-procursus7/ldid_linux_arm64"
else
    echo "🚨 Error: Arquitectura no soportada: $ARCH"
    exit 1
fi

curl -L -o "$LDID_PATH" "$URL"
chmod +x "$LDID_PATH"
echo "✅ ldid Procursus descargado y listo para usar en: $LDID_PATH"

# --- 3. COMPILACIÓN Y ESTRUCTURA IPA ---
rm -rf build
mkdir -p build

cd "$WORKING_LOCATION"
echo "==> Compilando la aplicación principal..."
make clean
make

echo "==> Compilando RootHelper..."
cd "$WORKING_LOCATION/RootHelper"
make clean
make
cd "$WORKING_LOCATION"

# Definiciones de rutas
TARGET_APP="$WORKING_LOCATION/build/$APPLICATION_NAME.app"

# Copiar la aplicación principal
cp -r ".theos/obj/debug/$APPLICATION_NAME.app" "$TARGET_APP"

# Copiar el RootHelper
cp "$WORKING_LOCATION/RootHelper/.theos/obj/debug/$ROOT_HELPER_NAME" "$TARGET_APP/$ROOT_HELPER_NAME"

cd build

# Eliminar firmas existentes
if [ -e "$TARGET_APP/_CodeSignature" ]; then
    rm -rf "$TARGET_APP/_CodeSignature"
fi
if [ -e "$TARGET_APP/embedded.mobileprovision" ]; then
    rm -rf "$TARGET_APP/embedded.mobileprovision"
fi

# --- 4. FIRMA DE BINARIOS ---

echo "==> Firmando RootHelper con ldid Procursus..."
"$LDID_PATH" -S"$ROOT_HELPER_ENTITLEMENTS" "$TARGET_APP/$ROOT_HELPER_NAME"
if [ $? -ne 0 ]; then
    echo "❌ ERROR: ldid falló al firmar el RootHelper con $ROOT_HELPER_ENTITLEMENTS."
    exit 1
fi
echo "✅ RootHelper firmado con éxito."

echo "==> Firmando binario principal con ldid Procursus..."
"$LDID_PATH" -S"$APP_ENTITLEMENTS" "$TARGET_APP/$APPLICATION_NAME"
if [ $? -ne 0 ]; then
    echo "❌ ERROR: ldid falló al firmar la App principal con $APP_ENTITLEMENTS."
    exit 1
fi
echo "✅ Binario principal firmado con éxito."

# --- 5. EMPAQUETAR .IPA ---
echo "==> Empaquetando en $APPLICATION_NAME.tipa"
rm -rf Payload
mkdir Payload
cp -r "$APPLICATION_NAME.app" "Payload/$APPLICATION_NAME.app"
zip -qr "$APPLICATION_NAME.tipa" Payload
rm -rf "$APPLICATION_NAME.app"
rm -rf Payload

echo "✅ Construcción y empaquetamiento finalizados. Archivo generado: build/$APPLICATION_NAME.tipa"
echo "✅ El IPA ahora incluye el RootHelper."