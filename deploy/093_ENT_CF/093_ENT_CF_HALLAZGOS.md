# Hallazgos — 093_ENT_CF (Layout CF_V3_CF_I)

| # | Hallazgo | Corrección aplicada |
|---|----------|---------------------|
| 1 | Nombre con espacio: objetos existentes se llaman `093_ ENT_CF` (espacio después del guion bajo) | Renombrado a `093_ENT_CF`; objetos con nombre incorrecto eliminados explícitamente |
| 2 | Patrón incorrecto: SP SILVER era self-select (`INSERT…SELECT` sobre la misma tabla `RR`) | Cambiado a origen LMDA: `INSERT…SELECT FROM BRONZE.[LMDA].[CF_I]` |
| 3 | `FECHA_INFO` faltante en tabla y SPs | Agregada como columna estándar (NOT NULL en SILVER, NULL en LMDA) |
| 4 | SP ION exponía `ID` y `FECHA_EXTRACCION` (campos internos de auditoría) | Eliminados de la salida; solo se exponen los 9 campos del layout + `FECHA_INFO` |
| 5 | Filtro de ventana semanal en SP SILVER usaba `FECHA_INICIO` (campo regulatorio) | Cambiado a `FECHA_INFO` (campo de control de carga), consistente con patrón LMDA |
