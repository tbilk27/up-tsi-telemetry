$adbPath = "$env:LOCALAPPDATA\Android\platform-tools\adb.exe"

if (-not (Test-Path $adbPath)) {
    Write-Host "Instalando Android Platform-Tools..." -ForegroundColor Yellow
    curl.exe -L "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -o "$env:TEMP\platform-tools.zip"
    Expand-Archive -Path "$env:TEMP\platform-tools.zip" -DestinationPath "$env:LOCALAPPDATA\Android" -Force
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " INSTALADOR DO APP VW UP! TSI NO TELEFONE ANDROID" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Check connected device
$devicesRaw = & $adbPath devices
$deviceLines = ($devicesRaw -split "`n") | Where-Object { $_ -match "\bdevice\b" -and $_ -notmatch "List of" }

if (-not $deviceLines) {
    Write-Host "`n[!] NENHUM APARELHO DETECTADO COM DEPURACAO USB ATIVA!" -ForegroundColor Red
    Write-Host "`nPara conectar o seu telefone:" -ForegroundColor Yellow
    Write-Host "1. Conecte o cabo USB no notebook e no celular."
    Write-Host "2. No celular, va em: Configuracoes > Opcoes do Desenvolvedor."
    Write-Host "3. Ative a opcao: Depuracao USB (USB Debugging)."
    Write-Host "4. Desbloqueie a tela do celular e toque em 'PERMITIR' quando perguntar sobre a conexao do computador."
    Write-Host "`nTentando detectar novamente em 5 segundos..."
    Start-Sleep -Seconds 5
    $devicesRaw = & $adbPath devices
    $deviceLines = ($devicesRaw -split "`n") | Where-Object { $_ -match "\bdevice\b" -and $_ -notmatch "List of" }
}

if (-not $deviceLines) {
    Write-Host "`nAparelho ainda nao detectado via ADB." -ForegroundColor Yellow
    Write-Host "Voce tambem pode baixar diretamente o arquivo APK pelo link de Releases do GitHub:"
    Write-Host "https://github.com/tbilk27/up-tsi-telemetry/releases" -ForegroundColor Cyan
    pause
    exit 1
}

Write-Host "`n[✓] Telefone detectado com sucesso via ADB!" -ForegroundColor Green

# Locate or download the APK
$apkPath = "$PSScriptRoot\mobile\build\app\outputs\flutter-apk\app-release.apk"
$downloadedApk = "$PSScriptRoot\app-release.apk"

if (-not (Test-Path $apkPath) -and -not (Test-Path $downloadedApk)) {
    Write-Host "Obtendo APK compilado mais recente do GitHub..." -ForegroundColor Yellow
    $p = @"
protocol=https
host=github.com

"@
    $cred = $p | git credential fill
    $token = ""
    foreach ($line in ($cred -split "`n")) {
        if ($line -match "^password=(.*)") { $token = $matches[1].Trim() }
    }

    $headers = @{
        "Authorization" = "Bearer $token"
        "Accept" = "application/vnd.github+json"
        "User-Agent" = "PowerShell"
    }

    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/tbilk27/up-tsi-telemetry/releases/latest" -Headers $headers -Method Get
        if ($release.assets.Count -gt 0) {
            $apkAsset = $release.assets | Where-Object { $_.name -like "*.apk" } | Select-Object -First 1
            if ($apkAsset) {
                Write-Host "Baixando $($apkAsset.name)..."
                curl.exe -L -H "Authorization: Bearer $token" -H "Accept: application/octet-stream" $apkAsset.url -o $downloadedApk
            }
        }
    } catch {
        Write-Host "Release ainda em compilacao no GitHub Actions." -ForegroundColor Yellow
    }
}

$targetApk = if (Test-Path $downloadedApk) { $downloadedApk } else { $apkPath }

if (Test-Path $targetApk) {
    Write-Host "`nInstalando Up! TSI Telemetry no celular..." -ForegroundColor Cyan
    & $adbPath install -r $targetApk
    Write-Host "`n[✓] APP INSTALADO COM SUCESSO!" -ForegroundColor Green
    Write-Host "Iniciando o app na tela do seu telefone..."
    & $adbPath shell am start -n "com.antigravity.uptsi/.MainActivity"
} else {
    Write-Host "Aguarde a finalizacao da compilacao do APK no GitHub Actions." -ForegroundColor Yellow
}
