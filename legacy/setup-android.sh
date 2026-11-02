#!/bin/bash
set -e

SDK_DIR="$HOME/android-sdk"
JAVA_DIR="/usr/lib/jvm/java-21-openjdk-amd64"

echo "=================================================="
echo "🚀 Aplicando parche definitivo para Zsh..."
echo "=================================================="

# Limpiar funciones anteriores en ~/.zshrc si existen
if grep -q "crear_apk()" "$HOME/.zshrc"; then
    sed -i '/# --- Automatización de Capacitor/,/^}/d' "$HOME/.zshrc"
    sed -i '/compila_apk()/,/^}/d' "$HOME/.zshrc"
fi

# Inyectar funciones limpias usando printf (sin conflictos de heredoc en Zsh)
cat << 'FUNCS' >> "$HOME/.zshrc"

# --- Automatización de Capacitor (crear y compilar) ---
crear_apk() {
    local nombre="$1"
    if [ -z "$nombre" ]; then
        echo "❌ Error: Debes indicar un nombre para el proyecto."
        echo "Uso: crear_apk mi-proyecto"
        return 1
    fi
    echo "==> [1/4] Creando directorio y estructura web..."
    mkdir -p "$nombre/www"
    cd "$nombre"
    
    echo "==> [2/4] Inicializando proyecto Node y Capacitor..."
    npm init -y > /dev/null
    npm install @capacitor/core @capacitor/cli @capacitor/android
    
    echo "==> [3/4] Creando capacitor.config.json..."
    printf '{\n  "appId": "com.ejemplo.%s",\n  "appName": "%s",\n  "webDir": "www",\n  "bundledWebRuntime": false\n}\n' "$nombre" "$nombre" > capacitor.config.json

    echo "==> Creando index.html de prueba en la carpeta www..."
    cat << 'HTML' > www/index.html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mi App</title>
    <style>
        body { font-family: sans-serif; text-align: center; margin-top: 50px; background: #121212; color: #fff; }
        h1 { color: #00f0ff; }
    </style>
</head>
<body>
    <h1>¡Hola desde Capacitor!</h1>
    <p>Edita los archivos en la carpeta 'www' para empezar.</p>
</body>
</html>
HTML

    echo "==> [4/4] Añadiendo plataforma nativa de Android..."
    npx cap add android
    
    echo ""
    echo "¡Proyecto '$nombre' creado con éxito en $(pwd)!"
}

compila_apk() {
    if [ ! -d "android" ]; then
        echo "❌ Error: No estás en la raíz de un proyecto Capacitor válido (falta la carpeta 'android')."
        return 1
    fi
    
    echo "==> [1/4] Sincronizando assets web y Capacitor..."
    npx cap sync android

    cd android
    
    echo "==> [2/4] Forzando configuración de Java 21 en gradle.properties..."
    if grep -q "org.gradle.java.home" gradle.properties; then
        sed -i 's|org.gradle.java.home=.*|org.gradle.java.home=/usr/lib/jvm/java-21-openjdk-amd64|g' gradle.properties
    else
        echo "org.gradle.java.home=/usr/lib/jvm/java-21-openjdk-amd64" >> gradle.properties
    fi

    echo "==> [3/4] Compilando con Gradle..."
    ./gradlew assembleDebug

    local apk_path="app/build/outputs/apk/debug/app-debug.apk"
    if [ -f "$apk_path" ]; then
        local nombre_proyecto=$(basename "$(dirname "$PWD")" | tr '[:upper:]' '[:lower:]')
        cp "$apk_path" ~/Escritorio/"${nombre_proyecto}-debug.apk"
        echo "==> [4/4] ¡ÉXITO! APK guardado en tu Escritorio como '${nombre_proyecto}-debug.apk'."
    else
        echo "❌ Error: La compilación terminó pero no se encontró el APK."
    fi
    
    cd ..
}
FUNCS

echo "✅ ¡Listo! Comandos actualizados sin errores de sintaxis."
