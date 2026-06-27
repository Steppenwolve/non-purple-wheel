# Hallazgos — 021_ENT_SWAPS_CONVO
# Layout: Layout_SWAPS_V10_FILE_SWAP_CONVO

| # | Hallazgo | Corrección aplicada |
|---|----------|---------------------|
| 1 | `INDICE_REPORTES.frecuencia = 'Diaria'` — periodicidad semanal | `UPDATE` a `'Semanal'` en Section 04 |
| 2 | **SP SILVER — self-select bug**: leía de `SILVER.RR.021_ENT_SWAPs_CONVO` (se auto-referenciaba). Código con comentario `--Debe cambiar por la consulta de extraccion` | Reemplazado por origen `BRONZE.LMDA.SWAP_CONVO` (origen LMDA) |
| 3 | **SP SILVER — filtro mensual por FE_CON_OPE**: usaba `DATEFROMPARTS(YEAR,MONTH,1)` sobre `FE_CON_OPE`. El reporte es semanal y el campo de control es `FECHAINFO` | Reemplazado por ventana semanal `(DATEPART(WEEKDAY,...)+5)%7` sobre `FECHAINFO` |
| 4 | **SP SILVER — columnas obsoletas en INSERT**: incluía `OBJ_OPE`, `SEC_SWAP`, `FE_CORTE`, `ACT_OPE_VAL`, `ACT_OPE_ME_VAL`, `PAS_OPE_VAL`, `PAS_OPE_MR_VAL`; ninguna en layout V10. No incluía `NOCIONAL`, `MON_NOCIONAL`, `FECHAINFO` | Columnas alineadas al layout V10 |
| 5 | **SP ION — filtro imposible**: `WHERE FE_CON_OPE >= @FECHA AND FE_CON_OPE < @FECHA` (devolvía siempre 0 filas) | Reemplazado por ventana semanal sobre `FECHAINFO` |
| 6 | **SP ION — exposición de ID y FECHA_EXTRACCION** (violación consideración 9) | Eliminados del SELECT |
| 7 | **SP ION — columnas obsoletas expuestas**: `OBJ_OPE`, `SEC_SWAP`, `FE_CORTE`, `ACT_OPE_VAL`, etc. No exponía `NOCIONAL`, `MON_NOCIONAL`, `FECHAINFO` | SELECT alineado a ORDEN 1-18 del layout V10 |
| 8 | **SP ION — fechas sin FORMAT**: `FE_CON_OPE`, `FE_VEN_FLU_R`, `FE_VEN_FLU_E`, `FECHAINFO` | `FORMAT(...,'yyyy/MM/dd')` aplicado a las 4 fechas |
| 9 | **SILVER — `FECHAINFO` inexistente**: campo ORDEN 18 no existía en `SILVER.RR.021_ENT_SWAPS_CONVO` | `ALTER TABLE ADD FECHAINFO date NOT NULL` (Section 01b) |
| 10 | **SILVER — `NOCIONAL` y `MON_NOCIONAL` nullable**: layout OBLIGATORIO=SI; tabla tenía `NULL` | `ALTER COLUMN ... NOT NULL` (Section 01c) |
| 11 | **SILVER — 8 columnas obsoletas de versión anterior**: `OBJ_OPE`, `SEC_SWAP`, `FE_CORTE`, `ACT_OPE_VAL`, `ACT_OPE_ME_VAL`, `PAS_OPE_VAL`, `PAS_OPE_MR_VAL`, `NOCIONAL_VAL` | `DROP COLUMN` × 8 (Section 01a) |
| 12 | **BRONZE — tabla `SWAP_CONVO` inexistente**: reporte origen LMDA sin tabla BRONZE | `CREATE TABLE BRONZE.LMDA.SWAP_CONVO` (Section 00) |
| 13 | **Catálogo `MONEDA_DER_V1`** referenciado en layout para campos `MON_*` contiene claves de tipo cuota (`N`,`R`,`S`,`E`,`F`) — no son códigos de moneda. Se usa `MONEDA_DER_V2` con claves ISO 3 chars (`MXN`,`USD`,`EUR`…) | Confirmado por el usuario — dummy con ISO codes de V2 |
| 14 | **DUR_ACT / DUR_PAS** referencian `CATALOGOS!A41175` y `CATALOGOS!A41154` — hipervínculos a celdas internas del Excel, no archivos de catálogo externos | Omitidos; campos tratados como `numeric(15,0)` libres |
| 15 | **Typo en layout ORDEN 8**: tipo dato = `TETXO` (debe ser `TEXTO`) | Nota documental — tipo en BD correcto `varchar(3)` |

## Catálogos aplicados al dummy

| Campo | Catálogo | Valores utilizados |
|-------|----------|--------------------|
| `MON_ACT_OPE`, `MON_ACT_OPE_ME`, `MON_PAS_OPE`, `MON_PAS_OPE_MR`, `MON_NOCIONAL` | `MONEDA_DER_V2.xls` (CLAVE ISO) | MXN, USD, EUR, JPY, CAD |

## BRONZE: nombre de tabla

La tabla BRONZE utiliza el nombre `SWAP_CONVO` (sin prefijo `FILE_`), coherente con el patrón de nomenclatura del proyecto. El processor JSON apunta a `file_pattern: ^FILE_SWAP_CONVO.*`.
