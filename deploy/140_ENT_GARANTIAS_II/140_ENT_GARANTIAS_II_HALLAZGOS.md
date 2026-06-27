# Hallazgos — 140_ENT_GARANTIAS_II (Layout_Garantias_V2_FILE_GARANTIAS_II)

| # | Hallazgo | Corrección aplicada |
|---|----------|---------------------|
| 1 | Columna `FECHA_REPORTE` en tabla y SPs; layout la nombra `FECHAINFO` | `sp_rename FECHA_REPORTE → FECHAINFO` (preserva datos existentes) |
| 2 | SP SILVER era self-select (`INSERT…SELECT` sobre la misma tabla `RR`) | Cambiado a origen LMDA: `INSERT…SELECT FROM BRONZE.[LMDA].[GARANTIAS_II]` |
| 3 | SP SILVER filtraba la ventana semanal por `FECHA_REPORTE` | Cambio de filtro a `FECHAINFO` (columna de control LMDA) |
| 4 | SP ION exponía `ID` y `FECHA_EXTRACCION` (campos internos de auditoría) | Eliminados de la salida; 14 cols del layout únicamente |
| 5 | SP ION no aplicaba formato a fechas | `FE_AV_BI`: `AAAA/MM/DD`; `FECHAINFO`: `DD/MM/AAAA` (formato explícito del layout) |
