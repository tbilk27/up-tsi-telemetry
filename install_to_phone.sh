#!/bin/bash
set -e

APK_PATH="app-release.apk"
if [ ! -f "$APK_PATH" ]; then
  APK_PATH="mobile/build/app/outputs/flutter-apk/app-release.apk"
fi

if [ ! -f "$APK_PATH" ]; then
  echo "❌ APK não encontrado! Execute a compilação primeiro."
  exit 1
fi

echo "🔍 Verificando aparelhos conectados via ADB..."
DEVICE_COUNT=$(adb devices | grep -v "List of" | grep "device$" | wc -l | tr -d ' ')

if [ "$DEVICE_COUNT" -eq "0" ]; then
  echo "⚠️ Nenhum aparelho com Depuração USB autorizada foi detectado pelo ADB."
  echo ""
  echo "Para habilitar no seu Xiaomi/Android:"
  echo " 1. Acesse Configurações > Sobre o telefone > Toque repetidamente em 'Versão do MIUI / SO' até liberar o Modo Desenvolvedor."
  echo " 2. Vá em Configurações > Configurações Adicionais > Opções do Desenvolvedor."
  echo " 3. Ative: 'Depuração USB' e 'Instalar via USB'."
  echo " 4. Desbloqueie a tela e aceite o aviso 'Permitir a depuração USB?' no telefone."
  echo ""
  adb devices -l
  exit 1
fi

echo "📲 Instalando $APK_PATH no dispositivo..."
adb install -r "$APK_PATH"
echo "✅ Aplicativo instalado com sucesso!"
