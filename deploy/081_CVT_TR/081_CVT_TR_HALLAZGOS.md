# Hallazgos: 081_CVT TR — Custodia / Transferencias (Diaria)

Fuente de referencia: `layout/Layout_CVT_TR_V3.xlsx` — hoja `FT_CVT_TR`

---

## Columnas con discrepancias

| Orden layout | Nombre | Tipo layout | Formato | Estado en BD | Hallazgo | Corrección aplicada |
|---|---|---|---|---|---|---|
| 10 | `FECHA_INFO` | FECHA | AAAAMMDD | **Ausente** | Columna regulatoria faltante | `ADD COLUMN date NULL` |

Las 9 columnas restantes del layout están presentes en la tabla con tipos y longitudes correctos.
La tabla cuenta con `ID uniqueidentifier` y `FECHA_EXTRACCION smalldatetime` correctamente definidos.

---

## Cambios en Stored Procedures

### SILVER.dbo.[081_CVT TR]

| Elemento | Estado original | Estado corregido |
|---|---|---|
| Variables `@FechaIni` / `@FechaFin` | Declaradas y calculadas (ventana mensual) | Eliminadas — código muerto |
| Variable `@FechaDia` | No existía | Agregada: `CAST(@FechaSistema AS DATE)` |
| DELETE idempotente | `WHERE [FECHATRANSFERENCIA] = @FechaSistema` (DATETIME) | `WHERE [FECHATRANSFERENCIA] = @FechaDia` (DATE) |
| INSERT — lista de columnas | Sin `FECHA_INFO` | Incluye `FECHA_INFO` |
| SELECT fuente | Sin `FECHA_INFO` | Selecciona `@FechaDia` como `FECHA_INFO` |

> **Código muerto**: igual que en `080_CVT TRP`, `132_ENT_FUT_CONVAL` y `083_ENT_CVT_IN`, el SP calculaba `@FechaIni` y `@FechaFin` (ventana mensual) sin usarlos en el WHERE. El reporte es de periodicidad **DIARIA**.

> **Nota sobre columna de filtro**: el DELETE e INSERT filtran por `FECHATRANSFERENCIA` (fecha efectiva de entrega/recepción de títulos), no por una columna de fecha de proceso. Mismo patrón documentado en `083_ENT_CVT_IN`. Se preserva el comportamiento original y queda anotado para evaluación en producción.

### ION.dbo.[081_CVT TR]

| Elemento | Estado original | Estado corregido |
|---|---|---|
| Columna `ID` en SELECT | Incluida | Eliminada (campo interno de auditoría) |
| Columna `FECHA_EXTRACCION` en SELECT | Incluida | Eliminada (campo interno de auditoría) |
| Columna `FECHA_INFO` en SELECT | Ausente | Agregada |
| Comentarios muertos al final | `--EXEC ...` y `-- Para reportes diarios ...` | Eliminados |

---

## Scripts generados

| Archivo | Propósito |
|---|---|
| `081_CVT_TR_CORRECCION.sql` | Aplica todos los cambios. Idempotente. |
| `081_CVT_TR_ROLLBACK.sql` | Revierte al estado previo: SP ION → SP SILVER → DROP FECHA_INFO. |

---

## Notas para producción

- El rollback elimina `FECHA_INFO`; los datos en esa columna no son recuperables sin respaldo previo.
- `FECHA_INFO` se agrega como `NULL` para no romper registros existentes.
- `tbl_Control_Ejecucion`, `INDICE_REPORTES` y `LogSilverDiario` no son tocados por ninguno de los scripts.
