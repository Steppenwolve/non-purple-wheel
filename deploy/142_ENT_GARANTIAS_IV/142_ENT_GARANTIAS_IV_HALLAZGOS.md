# Hallazgos — 142_ENT_GARANTIAS_IV (Layout_Garantias_V2_FILE_GARANTIAS_IV)

| # | Hallazgo | Corrección aplicada |
|---|----------|---------------------|
| 1 | Columna `FECHA_REPORTE` en tabla y SPs; layout la nombra `FECHAINFO` | `sp_rename FECHA_REPORTE → FECHAINFO` (preserva datos existentes) |
| 2 | SP SILVER era self-select (`INSERT…SELECT` sobre la misma tabla `RR`) | Cambiado a origen LMDA: `INSERT…SELECT FROM BRONZE.[LMDA].[GARANTIAS_IV]` |
| 3 | SP SILVER filtraba e insertaba inyectando `@FechaIni` como valor de `FECHA_REPORTE` en lugar de leer de LMDA | Filtro e INSERT corregidos a `FECHAINFO` (columna de control LMDA leída del origen) |
| 4 | SP ION exponía `ID` y `FECHA_EXTRACCION` (campos internos de auditoría) | Eliminados de la salida; 7 cols del layout únicamente |
| 5 | SP ION no aplicaba formato a `FECHAINFO`; filtraba por `FECHA_REPORTE` | `FORMAT([FECHAINFO],'yyyy/MM/dd')` — AAAA/MM/DD (layout y consideración 12); filtro corregido a `FECHAINFO` |
| 6 | Sin DEFAULT constraints en `ID` ni `FECHA_EXTRACCION` (tabla importada del DDL) | `ALTER TABLE ADD CONSTRAINT DF_142_GARANTIAS_IV_ID/FEXT` (consideración 15) |

## Catálogos aplicados

Catálogos leídos de `layout/CATALOGOS/`. Los datos dummy usan valores válidos según cada catálogo:

| Campo | Catálogo | Valores válidos | Notas |
|-------|----------|-----------------|-------|
| `OFICINA` | ANEXO A | `'A'`, `'R'`, `'F'` | A=Agencias exterior, R=Rep. Mexicana, F=Filiales extranjero |
| `CONT` | ANEXO B | `'111'`, `'750'`, `'760'`, `'770'`, `'775'`, `'780'`, `'790'` | Códigos numéricos almacenados como varchar(6) |
| `NETEO_POS` | ANEXO M | `1`–`6`, `9` | 9=No aplica (sin acuerdo de compensación) |
| `TIP_CONTRAT` | ANEXO N | `1`–`8` | Tipos de contrato marco (ISDA 1992, 2002, IFEMA, etc.) |
