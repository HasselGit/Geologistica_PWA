# Reglas de Comunicación (Vercel)
- NUNCA imprimas ni muestres al usuario la URL autogenerada de Vercel (e.g. https://geologistica-jrj...vercel.app).
- Muestra ÚNICAMENTE la URL limpia y principal del proyecto (https://geologistica-pwa.vercel.app).

# Actualización de Directrices
- Es vital mantener los archivos directrices (e.g. ARQUITECTURA_GEOLOGISTICA.md, design_tokens.dart) actualizados con cada decisión. El objetivo final es que cualquier agente pueda clonar el proyecto desde cero basándose únicamente en la documentación.

# REGLA CRITICA DE DESPLIEGUE A VERCEL (NUNCA CREAR 2 PROYECTOS)
- Cuando debas desplegar el proyecto compilado (por ejemplo, la carpeta uild/web), NUNCA ejecutes ercel deploy --cwd build/web a ciegas.
- Si lo haces sin precaucion, Vercel creara un nuevo proyecto basado en el nombre de la carpeta (ej: web) en lugar de actualizar el proyecto existente (geologistica-pwa).
- PARA EVITAR ESTE DESASTRE: SIEMPRE debes copiar la carpeta .vercel desde la raiz del proyecto hacia el directorio de compilacion ANTES de ejecutar el despliegue.
- Comando obligatorio: Copy-Item -Path .vercel -Destination build/web -Recurse -Force; npx vercel deploy --prod --cwd build/web.
