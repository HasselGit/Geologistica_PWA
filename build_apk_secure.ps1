# ==============================================================================
# Script de Compilación Segura de APK - GeoLogística
# ==============================================================================
# Este script automatiza la limpieza, obtención de dependencias y compilación
# del APK de GeoLogística aplicando técnicas premium de seguridad:
#   1. Ofuscación completa de código Dart/Flutter.
#   2. Separación de mapas de símbolos de depuración.
#   3. Minimización y ofuscación nativa (ProGuard/R8).
# ==============================================================================

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " Iniciando compilación segura del APK para GeoLogística  " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# 1. Limpieza de compilaciones anteriores
Write-Host "`n[1/4] Limpiando compilaciones anteriores..." -ForegroundColor Yellow
flutter clean

# 2. Obtención de dependencias actualizadas
Write-Host "`n[2/4] Resolviendo y descargando dependencias..." -ForegroundColor Yellow
flutter pub get

# 3. Compilación con Ofuscación y Protección de Código
Write-Host "`n[3/4] Compilando APK con Ofuscación y Protección..." -ForegroundColor Yellow
$debugDir = "build/app/outputs/symbols"
flutter build apk --release --obfuscate --split-debug-info=$debugDir

# 4. Verificación del resultado
$apkPath = "build/app/outputs/flutter-apk/app-release.apk"
if (Test-Path $apkPath) {
    $apkSize = (Get-Item $apkPath).Length / 1MB
    Write-Host "`n========================================================" -ForegroundColor Green
    Write-Host " ¡Compilación Segura Completada con Éxito!              " -ForegroundColor Green
    Write-Host "========================================================" -ForegroundColor Green
    Write-Host "APK Generado en: $apkPath" -ForegroundColor White
    Write-Host "Tamaño del APK: $('{0:N2}' -f $apkSize) MB" -ForegroundColor White
    Write-Host "Símbolos de Depuración guardados en: $debugDir" -ForegroundColor White
    Write-Host "El código nativo y Dart ha sido ofuscado correctamente." -ForegroundColor White
    Write-Host "========================================================" -ForegroundColor Green
} else {
    Write-Host "`n========================================================" -ForegroundColor Red
    Write-Host " Error: La compilación del APK ha fallado.              " -ForegroundColor Red
    Write-Host "========================================================" -ForegroundColor Red
    Exit 1
}
