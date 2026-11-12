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
$deviceFound = $false
foreach ($line in ($devicesRaw -split "`r`n")) {
    if ($line -match "\bdevice\b" -and $line -notmatch "List of") {
        $deviceFound = $true
        break
    }
}

if (-not $deviceFound) {
    Write-Host ""
    Write-Host "[!] NENHUM APARELHO DETECTADO COM DEPURACAO USB ATIVA!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Para conectar o seu telefone:" -ForegroundColor Yellow
    Write-Host "1. Conecte o cabo USB no notebook e no celular."
    Write-Host "2. No celular, va em: Configuracoes > Opcoes do Desenvolvedor."
    Write-Host "3. Ative a opcao: Depuracao USB (USB Debugging)."
    Write-Host "4. Desbloqueie a tela do celular e toque em PERMITIR quando perguntar sobre a conexao do computador."
    Write-Host ""
    Write-Host "Tentando detectar novamente em 4 segundos..."
    Start-Sleep -Seconds 4
    $devicesRaw = & $adbPath devices
    foreach ($line in ($devicesRaw -split "`r`n")) {
        if ($line -match "\bdevice\b" -and $line -notmatch "List of") {
            $deviceFound = $true
            break
        }
    }
}

if (-not $deviceFound) {
    Write-Host ""
    Write-Host "Aparelho ainda nao detectado via ADB." -ForegroundColor Yellow
    Write-Host "Certifique-se de que o cabo USB transmite dados e que a Depuracao USB foi autorizada."
    Write-Host "Voce tambem pode baixar diretamente o arquivo APK pelo link de Releases do GitHub:"
    Write-Host "https://github.com/tbilk27/up-tsi-telemetry/releases" -ForegroundColor Cyan
    exit 1
}

Write-Host ""
Write-Host "[OK] Telefone detectado com sucesso via ADB!" -ForegroundColor Green

# Locate or download the APK
$apkPath = Join-Path $PSScriptRoot "mobile\build\app\outputs\flutter-apk\app-release.apk"
$downloadedApk = Join-Path $PSScriptRoot "app-release.apk"

$targetApk = ""
if (Test-Path $apkPath) {
    $targetApk = $apkPath
} elseif (Test-Path $downloadedApk) {
    $targetApk = $downloadedApk
} else {
    Write-Host "Buscando APK compilado mais recente do GitHub..." -ForegroundColor Yellow
    $cred = "protocol=https`nhost=github.com`n`n" | git credential fill
    $token = ""
    foreach ($l in ($cred -split "`n")) {
        if ($l.Trim().StartsWith("password=")) {
            $token = $l.Trim().Substring(9)
        }
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
                if (Test-Path $downloadedApk) {
                    $targetApk = $downloadedApk
                }
            }
        }
    } catch {
        Write-Host "Release ainda em compilacao no GitHub Actions." -ForegroundColor Yellow
    }
}

if ($targetApk -ne "" -and (Test-Path $targetApk)) {
    Write-Host ""
    Write-Host "Instalando Up! TSI Telemetry no celular..." -ForegroundColor Cyan
    & $adbPath install -r $targetApk
    Write-Host ""
    Write-Host "[OK] APP INSTALADO COM SUCESSO NO CELULAR!" -ForegroundColor Green
    Write-Host "Iniciando o app na tela do seu telefone..."
    & $adbPath shell am start -n "com.antigravity.uptsi/.MainActivity"
} else {
    Write-Host "O APK ainda esta sendo gerado pelo GitHub Actions. Tente novamente em instantes." -ForegroundColor Yellow
}
