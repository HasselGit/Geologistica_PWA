---
name: guarda_todo
description: Ejecuta el protocolo de guardado seguro del proyecto. Se activa automÃ¡ticamente cuando el usuario dice explÃ­citamente "guarda todo". Realiza un chequeo de cÃ³digo, fetch de colisiones, documentaciÃ³n y push autÃ³nomo a GitHub.
---

# Protocolo "Guarda Todo"

**OBJETIVO**: Salvaguardar el progreso del proyecto de forma autÃ³noma sin romper producciÃ³n ni causar colisiones de cÃ³digo.

Cuando el usuario invoque esta skill mediante el comando verbal "guarda todo" (o si fue disparada por un trigger programado), debes ejecutar los siguientes pasos en estricto orden secuencial utilizando tus herramientas de terminal (`run_command`):

## 1. Candado de Sintaxis (El mÃ¡s crÃ­tico)
- Ejecuta `dart analyze` en la terminal.
- Analiza la salida. **Si existen ERRORES de sintaxis crÃ­ticos** (ej. getters no definidos, variables sin cerrar, errores de compilaciÃ³n), **DEBES ABORTAR INMEDIATAMENTE**.
- Si abortas, deja un reporte en consola (o un archivo `sync_log.txt`) avisando: "Se detectÃ³ cÃ³digo incompleto. Abortando auto-push para proteger el repositorio".
- *Nota:* Si solo hay *warnings* (advertencias) o *infos*, puedes continuar.

## 2. Candado de ColisiÃ³n (Git Fetch)
- Ejecuta `git fetch origin`.
- Compara el estado local con la rama remota usando `git status`.
- Si tu rama local estÃ¡ atrasada respecto a origin, o si hay riesgo de conflictos de Merge, **ABORTE EL PROCESO** y notifica al usuario. No intentes resolver el merge tÃº solo sin supervisiÃ³n.

## 3. Auto-ActualizaciÃ³n de Directrices
- Revisa superficialmente usando `git status` y `git diff` quÃ© archivos se han modificado.
- Agrega un comentario en `.agents/AGENTS.md` resumiendo las modificaciones realizadas.
- Actualiza obligatoriamente `sesion_actual.md` (ubicado en la raÃ­z) aÃ±adiendo una secciÃ³n detallada sobre las tareas realizadas en la sesiÃ³n actual.
- Actualiza `ARQUITECTURA_GEOLOGISTICA.md` (ubicado en la raÃ­z) si hubo algÃºn cambio o decisiÃ³n estructural, de diseÃ±o, base de datos o lÃ³gica relevante que deba ser documentado permanentemente.

## 4. Subida a ProducciÃ³n (Commit y Push AutÃ³nomo)
- Ejecuta `git add .`
- Ejecuta `git commit -m "chore(sync): Autoguardado del agente - ActualizaciÃ³n de fin de jornada"`
- Ejecuta `git push origin HEAD` (o a la rama en la que se encuentre).
- Al finalizar, notifica al usuario que el proyecto ha sido guardado exitosamente en GitHub.

**IMPORTANTE**: Debes ejecutar esto de manera autÃ³noma, resolviendo los pasos por ti mismo a menos que salte algÃºn candado de seguridad, en cuyo caso te detienes de inmediato.
