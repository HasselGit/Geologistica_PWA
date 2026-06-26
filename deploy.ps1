# Script de Despliegue a Vercel Seguro

Write-Host "Compilando Flutter Web en modo Release..."
flutter build web --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error en compilacion. Abortando despliegue." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "Forzando enlace seguro del proyecto de Vercel a la carpeta web..."
if (-not (Test-Path "build\web\.vercel")) {
    New-Item -ItemType Directory -Force -Path "build\web\.vercel" | Out-Null
}
Copy-Item ".vercel\project.json" "build\web\.vercel\project.json" -Force

Write-Host "Desplegando acotadamente solo build\web a Produccion..."
Set-Location "build\web"
npx.cmd vercel --prod --yes
Set-Location "..\.."

Write-Host "Despliegue Finalizado." -ForegroundColor Green

