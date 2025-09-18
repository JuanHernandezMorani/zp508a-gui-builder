# ZP Builder UI (ZP 5.0 aligned) — con compilación One-Click

## Uso rápido
1) Node 18+
2) `npm install`
3) Opcional: copia tu pack (como NewZombie/) dentro de `input/`.
4) En la UI, usa **Detectar en input/** (setea `includeDirs` y, si existe, `amxxpcPath`).
   - Si no detecta, seteá manualmente en la barra lateral:
     - `amxxpcPath`: ruta a `amxxpc.exe` (Windows) o `amxxpc` (Linux)
     - `includeDirs`: ruta a `.../scripting/include` que contiene `zp50_core.inc` (podés poner varias separadas por `;`).
5) Cargá/creá clases, modos, armas, etc.
6) **Guardar / Compilar**: genera `.sma` en `build/scripting/**` y, si configuraste `amxxpc`, produce `.amxx` en `build/plugins/`. 
   También crea `build/configs/classes.ini`, `modes.ini`, `zp_humanclasses.ini`, `zp_zombieclasses.ini`, `zp_extraitems.ini`.
7) Copiá los `.amxx` y `configs/` a tu `cstrike/addons/amxmodx/` o empaquetá el `build/` como zip plug-and-play.

> Nota: No se puede redistribuir `amxxpc` aquí. Usá el de tu AMXX o pack de ZP 5.0. El botón **Detectar** intenta configurarlo automáticamente si lo encuentra dentro de `input/`.