---
name: sincroniza_entorno
description: Repasa automáticamente el estado del proyecto, arquitecturas, directrices, skills locales y último walkthrough para que el agente recupere el contexto tras un reinicio o periodo de inactividad.
---

# Instrucciones de la Skill: Sincronizar Entorno

**Objetivo:** Permitir al agente cargar rápidamente todo el contexto del proyecto (reglas, herramientas disponibles y último código modificado) cuando el usuario diga algo como "sincroniza", "retoma el proyecto", o "empieza la jornada".

Cuando el usuario active esta skill, debes ejecutar de forma proactiva y silenciosa los siguientes pasos en este orden EXACTO:

1. **Leer las Directrices y Reglas del Proyecto:**
   - Usa `view_file` o la herramienta equivalente para leer el archivo `.agents/AGENTS.md` (ahí están las reglas críticas, ej. los comandos obligatorios de Vercel).
   - Lee `sesion_actual.md` para entender los hitos de negocio más recientes y las restricciones operativas.
   - Revisa `RECURSOS_SINCRO.md` para obtener el panorama general del estado del sistema.
   - Verifica `ARQUITECTURA_GEOLOGISTICA.md` en la raíz y léelo si lo consideras necesario para repasar el diseño de componentes.

2. **Revisar las Skills Locales:**
   - Usa `list_dir` para explorar el directorio `.agents/skills` y saber qué otras herramientas o reglas personalizadas hay (por ejemplo, `guarda_todo`, `premium_ui`).

3. **Leer el Último Progreso:**
   - Lee el archivo `walkthrough.md` o cualquier bitácora de progreso reciente si tienes acceso a ella en el historial o carpeta de artefactos. Esto te dará el hito exacto en el que el usuario detuvo el trabajo anterior.

4. **Elaborar y Presentar el Informe de Sincronización:**
   Al terminar de recopilar la información, escribe UN ÚNICO mensaje claro al usuario informando que la sincronización fue un éxito, estructurado de la siguiente manera:
   - **Estado Exacto del Proyecto:** Resumen rápido (3-4 viñetas) con el último trabajo realizado (basado en el walkthrough y las charlas anteriores).
   - **Reglas Principales:** Breve confirmación de que tienes claras las reglas de despliegue o directrices de arquitectura más críticas.
   - **Skills Reconocidas:** Lista de las skills de este espacio de trabajo de las cuales ahora tienes pleno conocimiento.
   - **Siguiente paso:** Termina preguntando "¿Por dónde continuamos hoy?".
