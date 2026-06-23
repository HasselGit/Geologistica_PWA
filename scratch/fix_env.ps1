# Configuration script for Android SDK Environment Variables
[System.Environment]::SetEnvironmentVariable("ANDROID_HOME", "C:\Users\Parque-Apicola\AppData\Local\Android\Sdk", "User")
[System.Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", "C:\Users\Parque-Apicola\AppData\Local\Android\Sdk", "User")

$currentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")

$platformToolsPath = "C:\Users\Parque-Apicola\AppData\Local\Android\Sdk\platform-tools"
$emulatorPath = "C:\Users\Parque-Apicola\AppData\Local\Android\Sdk\emulator"

if ($currentPath -notlike "*platform-tools*") {
    $currentPath = $currentPath + ";" + $platformToolsPath
    Write-Host "Adding platform-tools to Path"
}

if ($currentPath -notlike "*Sdk\emulator*") {
    $currentPath = $currentPath + ";" + $emulatorPath
    Write-Host "Adding emulator to Path"
}

[System.Environment]::SetEnvironmentVariable("Path", $currentPath, "User")
Write-Host "Android Environment variables updated successfully!"
