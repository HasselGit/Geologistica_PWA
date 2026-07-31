---
name: sincroniza_entorno
description: Repasa automÃ¡ticamente el estado del proyecto, arquitecturas, directrices, skills locales y Ãºltimo walkthrough para que el agente recupere el contexto tras un reinicio o periodo de inactividad.
---

# Instrucciones de la Skill: Sincronizar Entorno

**Objetivo:** Permitir al agente cargar rÃ¡pidamente todo el contexto del proyecto (reglas, herramientas disponibles y Ãºltimo cÃ³digo modificado) cuando el usuario diga algo como "sincroniza", "retoma el proyecto", o "empieza la jornada".

Cuando el usuario active esta skill, debes ejecutar de forma proactiva y silenciosa los siguientes pasos en este orden EXACTO:

1. **Leer y Actualizar las Directrices y Reglas del Proyecto:**
   - Usa `view_file` o la herramienta equivalente para leer el archivo `.agents/AGENTS.md` (ahÃ­ estÃ¡n las reglas crÃ­ticas, ej. los comandos obligatorios de Vercel).
   - **IMPORTANTE:** AdemÃ¡s de leerlo, si durante tu sincronizaciÃ³n detectas que la bitÃ¡cora o las reglas en `.agents/AGENTS.md` estÃ¡n desactualizadas respecto al progreso reciente (o el archivo `walkthrough.md`), debes **ACTUALIZAR** `.agents/AGENTS.md` para reflejar el estado correcto y las Ãºltimas decisiones.
   - Lee `sesion_actual.md` para entender los hitos de negocio mÃ¡s recientes y las restricciones operativas.
   - Revisa `RECURSOS_SINCRO.md` para obtener el panorama general del estado del sistema.
   - Verifica `ARQUITECTURA_GEOLOGISTICA.md` en la raÃ­z y lÃ©elo si lo consideras necesario para repasar el diseÃ±o de componentes.

2. **Revisar las Skills Locales:**
   - Usa `list_dir` para explorar el directorio `.agents/skills` y saber quÃ© otras herramientas o reglas personalizadas hay (por ejemplo, `guarda_todo`, `premium_ui`).

3. **Leer el Ãltimo Progreso:**
   - Lee el archivo `walkthrough.md` o cualquier bitÃ¡cora de progreso reciente si tienes acceso a ella en el historial o carpeta de artefactos. Esto te darÃ¡ el hito exacto en el que el usuario detuvo el trabajo anterior.

4. **Elaborar y Presentar el Informe de SincronizaciÃ³n:**
   Al terminar de recopilar la informaciÃ³n, escribe UN ÃNICO mensaje claro al usuario informando que la sincronizaciÃ³n fue un Ã©xito, estructurado de la siguiente manera:
   - **Estado Exacto del Proyecto:** Resumen rÃ¡pido (3-4 viÃ±etas) con el Ãºltimo trabajo realizado (basado en el walkthrough y las charlas anteriores).
   - **Reglas Principales:** Breve confirmaciÃ³n de que tienes claras las reglas de despliegue o directrices de arquitectura mÃ¡s crÃ­ticas.
   - **Skills Reconocidas:** Lista de las skills de este espacio de trabajo de las cuales ahora tienes pleno conocimiento.
   - **Siguiente paso:** Termina preguntando "Â¿Por dÃ³nde continuamos hoy?".
