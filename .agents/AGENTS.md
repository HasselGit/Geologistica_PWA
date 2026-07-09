# Reglas de ComunicaciÃ³n (Vercel)
- NUNCA imprimas ni muestres al usuario la URL autogenerada de Vercel (e.g. https://geologistica-jrj...vercel.app).
- Muestra ÃšNICAMENTE la URL limpia y principal del proyecto (https://geologistica-pwa.vercel.app).

# ActualizaciÃ³n de Directrices
- Es vital mantener los archivos directrices (e.g. ARQUITECTURA_GEOLOGISTICA.md, design_tokens.dart) actualizados con cada decisiÃ³n. El objetivo final es que cualquier agente pueda clonar el proyecto desde cero basÃ¡ndose Ãºnicamente en la documentaciÃ³n.

# REGLA CRITICA DE DESPLIEGUE A VERCEL (NUNCA CREAR 2 PROYECTOS)
- Cuando debas desplegar el proyecto compilado (por ejemplo, la carpeta uild/web), NUNCA ejecutes ercel deploy --cwd build/web a ciegas.
- Si lo haces sin precaucion, Vercel creara un nuevo proyecto basado en el nombre de la carpeta (ej: web) en lugar de actualizar el proyecto existente (geologistica-pwa).
- PARA EVITAR ESTE DESASTRE: SIEMPRE debes copiar la carpeta .vercel desde la raiz del proyecto hacia el directorio de compilacion ANTES de ejecutar el despliegue.
- Comando obligatorio: Copy-Item -Path .vercel -Destination build/web -Recurse -Force; npx vercel deploy --prod --cwd build/web.

- El 02/07/2026, se modificaron lib/pages/viajes_page.dart y lib/widgets/geo_sidebar.dart para reestructurar la vista de Control de Viajes y eliminar textos residuales.

- El 03/07/2026, se modificaron lib/pages/homepage.dart y lib/pages/gerentehome.dart para corregir simetría de módulos y unificar colores en matriz de operaciones eliminando gráfica residual en Tambores.

- El 03/07/2026, se corrigieron los colores de fondo y texto de las tarjetas de Home y los contadores en la Matriz de Operaciones (escritorio y mvil).

- El 03/07/2026, se rediseñó el detalle de viaje a estándar Premium/Bento, se implementó _GlassCard y se ajustaron componentes.
El 2026-07-09, se modificaron los archivos lib/pages/paradadetalle.dart, vercel.json, generate_sw.py y deploy.ps1 para arreglar el conteo de tambores, insignias en la UI de la parada y resolver problemas de cacheado estricto en el CDN de Vercel.

- El 09/07/2026, se modificó paradadetalle.dart para remover el fallback por nombre y se usaron scripts en scratch/ para actualizar la tabla remitos y establecer la relación estricta por apicultor_id.

