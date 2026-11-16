#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================================="
echo " 🏎️ VW Up! TSI Telemetry — Build & Install Automatizado"
echo "=========================================================="

# 1. Incrementar código da build
echo "📦 Incrementando código da build (versionCode)..."
python3 scripts/bump_version.py

# 2. Configurar ambiente Java
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

# 3. Compilar APK Release
echo "🔨 Compilando release APK..."
cd mobile
flutter build apk --release
cd ..

# 4. Copiar APK para a raiz
echo "📂 Atualizando arquivo app-release.apk..."
cp mobile/build/app/outputs/flutter-apk/app-release.apk app-release.apk

# 5. Instalar diretamente no celular conectado (USB ou Wireless ADB)
# Tentar reconectar ao IP conhecido se não houver dispositivo ativo
if ! adb devices | grep -E "\bdevice\b" > /dev/null 2>&1; then
  adb connect 172.20.204.233:5555 > /dev/null 2>&1 || true
fi

TARGET_DEVICE=$(adb devices | grep -v "List of" | grep -E "\bdevice\b" | head -n 1 | awk '{print $1}')

if [ -n "$TARGET_DEVICE" ]; then
  echo "📱 Dispositivo detectado ($TARGET_DEVICE)! Enviando e instalando APK..."
  adb -s "$TARGET_DEVICE" install -r -d -t app-release.apk
  echo "🚀 Iniciando aplicativo no celular..."
  adb -s "$TARGET_DEVICE" shell am start -n com.antigravity.uptsi/.MainActivity
  echo "✅ Aplicativo instalado e iniciado com sucesso no dispositivo ($TARGET_DEVICE)!"
else
  echo "⚠️ Nenhum dispositivo com Depuração ADB ativo detectado. O APK atualizado está pronto em app-release.apk."
fi
