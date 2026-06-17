# Hallazgos: 083_ENT_CVT_IN — Custodia / Incumplimientos (Diaria)

Fuente de referencia: `layout/Layout_CVT_IN_V3.xlsx` — hoja `FT_CVT_IN`

---

## Columnas con discrepancias

| Orden layout | Nombre | Tipo layout | Formato | Estado en BD | Hallazgo | Corrección aplicada |
|---|---|---|---|---|---|---|
| 10 | `FECHA_INFO` | FECHA | AAAAMMDD | **Ausente** | Columna regulatoria faltante | `ADD COLUMN date NULL` |

Las 10 columnas restantes del layout están presentes en la tabla con tipos y longitudes correctos.
La tabla sí cuenta con `ID uniqueidentifier` y `FECHA_EXTRACCION smalldatetime` correctamente definidos.

---

## Cambios en Stored Procedures

### SILVER.dbo.[083_ENT_CVT_IN]

| Elemento | Estado original | Estado corregido |
|---|---|---|
| Variables `@FechaIni` / `@FechaFin` | Declaradas y calculadas (ventana mensual) | Eliminadas — código muerto |
| Variable `@FechaDia` | No existía | Agregada: `CAST(@FechaSistema AS DATE)` |
| DELETE idempotente | `WHERE [FECHACONCERTACION] = @FechaSistema` (DATETIME) | `WHERE [FECHACONCERTACION] = @FechaDia` (DATE) |
| INSERT — lista de columnas | Sin `FECHA_INFO` | Incluye `FECHA_INFO` |
| SELECT fuente | Sin `FECHA_INFO` | Selecciona `@FechaDia` como `FECHA_INFO` |

> **Nota sobre columna de filtro**: el DELETE y el INSERT filtran por `FECHACONCERTACION` (fecha en que se concertó la operación incumplida), no por una columna de fecha de proceso/reporte. Este es el comportamiento original y se preserva. Implica que si en un mismo proceso diario existen registros con distintas fechas de concertación, el DELETE idempotente solo elimina los del día procesado. Queda documentado para evaluación en producción.

> **Código muerto**: igual que en `080_CVT TRP` y `132_ENT_FUT_CONVAL`, el SP calculaba `@FechaIni` y `@FechaFin` (ventana mensual) pero el `WHERE` usaba `@FechaSistema` exacto. El reporte es de periodicidad **DIARIA**.

### ION.dbo.[083_ENT_CVT_IN]

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
| `083_ENT_CVT_IN_CORRECCION.sql` | Aplica todos los cambios. Idempotente. |
| `083_ENT_CVT_IN_ROLLBACK.sql` | Revierte al estado previo: SP ION → SP SILVER → DROP FECHA_INFO. |

---

## Notas para producción

- El rollback elimina `FECHA_INFO`; los datos en esa columna no son recuperables sin respaldo previo.
- `FECHA_INFO` se agrega como `NULL` para no romper registros existentes.
- `tbl_Control_Ejecucion`, `INDICE_REPORTES` y `LogSilverDiario` no son tocados por ninguno de los scripts.
