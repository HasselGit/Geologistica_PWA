Add-Type -AssemblyName System.Drawing
$path = 'c:\Users\Parque-Apicola\Desktop\Geologistica\assets\images\logo_Geologistica_Verde.png'
$img = [System.Drawing.Image]::FromFile($path)
$bmp = New-Object System.Drawing.Bitmap($img)
$p = $bmp.GetPixel(0,0)
Write-Host "TopLeft: $($p.R), $($p.G), $($p.B), $($p.A)"
$p = $bmp.GetPixel(10,10)
Write-Host "10x10: $($p.R), $($p.G), $($p.B), $($p.A)"
$p = $bmp.GetPixel($bmp.Width/2, $bmp.Height/2)
Write-Host "Center: $($p.R), $($p.G), $($p.B), $($p.A)"
