---
name: guarda_todo
description: Ejecuta el protocolo de guardado seguro del proyecto. Se activa automáticamente cuando el usuario dice explícitamente "guarda todo". Realiza un chequeo de código, fetch de colisiones, documentación y push autónomo a GitHub.
---

# Protocolo "Guarda Todo"

**OBJETIVO**: Salvaguardar el progreso del proyecto de forma autónoma sin romper producción ni causar colisiones de código.

Cuando el usuario invoque esta skill mediante el comando verbal "guarda todo" (o si fue disparada por un trigger programado), debes ejecutar los siguientes pasos en estricto orden secuencial utilizando tus herramientas de terminal (`run_command`):

## 1. Candado de Sintaxis (El más crítico)
- Ejecuta `dart analyze` en la terminal.
- Analiza la salida. **Si existen ERRORES de sintaxis críticos** (ej. getters no definidos, variables sin cerrar, errores de compilación), **DEBES ABORTAR INMEDIATAMENTE**.
- Si abortas, deja un reporte en consola (o un archivo `sync_log.txt`) avisando: "Se detectó código incompleto. Abortando auto-push para proteger el repositorio".
- *Nota:* Si solo hay *warnings* (advertencias) o *infos*, puedes continuar.

## 2. Candado de Colisión (Git Fetch)
- Ejecuta `git fetch origin`.
- Compara el estado local con la rama remota usando `git status`.
- Si tu rama local está atrasada respecto a origin, o si hay riesgo de conflictos de Merge, **ABORTE EL PROCESO** y notifica al usuario. No intentes resolver el merge tú solo sin supervisión.

## 3. Auto-Actualización de Directrices
- Revisa superficialmente usando `git status` y `git diff` qué archivos se han modificado.
- Agrega un comentario en `.agents/AGENTS.md` resumiendo las modificaciones realizadas.
- Actualiza obligatoriamente `sesion_actual.md` (ubicado en la raíz) añadiendo una sección detallada sobre las tareas realizadas en la sesión actual.
- Actualiza `ARQUITECTURA_GEOLOGISTICA.md` (ubicado en la raíz) si hubo algún cambio o decisión estructural, de diseño, base de datos o lógica relevante que deba ser documentado permanentemente.

## 4. Subida a Producción (Commit y Push Autónomo)
- Ejecuta `git add .`
- Ejecuta `git commit -m "chore(sync): Autoguardado del agente - Actualización de fin de jornada"`
- Ejecuta `git push origin HEAD` (o a la rama en la que se encuentre).
- Al finalizar, notifica al usuario que el proyecto ha sido guardado exitosamente en GitHub.

**IMPORTANTE**: Debes ejecutar esto de manera autónoma, resolviendo los pasos por ti mismo a menos que salte algún candado de seguridad, en cuyo caso te detienes de inmediato.
