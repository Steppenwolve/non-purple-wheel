# Hallazgos: 155_ENT_SWAP_IV — Swaps (Diaria)

Fuente de referencia: `layout/Layout_SWAPS_V10_IV.xlsx` — hoja `SWAP_IV`

---

## Columnas con discrepancias

| Orden layout | Nombre | Tipo layout | Formato | Estado en BD | Hallazgo | Corrección aplicada |
|---|---|---|---|---|---|---|
| 54 | `FECHAINFO` | FECHA | AAAA/MM/DD | **Ausente** | Columna regulatoria faltante | `ADD COLUMN date NULL` |

Las 53 columnas restantes del layout están presentes en la tabla con tipos y longitudes correctos,
incluyendo `PRE_SUB_RE` y `PRE_SUB_EN` como `numeric(13,6)` (decimal) conforme al layout.
La tabla cuenta con `ID uniqueidentifier` y `FECHA_EXTRACCION smalldatetime` correctamente definidos.

> **Nota sobre nombre**: este layout usa `FECHAINFO` (sin guion bajo), a diferencia de otros reportes
> que usan `FECHA_INFO`. Se respeta el nombre exacto del layout.

---

## Cambios en Stored Procedures

### SILVER.dbo.[155_ENT_SWAP_IV]

| Elemento | Estado original | Estado corregido |
|---|---|---|
| Variables `@FechaIni` / `@FechaFin` | Declaradas y calculadas (ventana mensual) | Eliminadas — código muerto |
| Variable `@FechaDia` | No existía | Agregada: `CAST(@FechaSistema AS DATE)` |
| DELETE idempotente | `WHERE [FE_CON_OPE] = @FechaSistema` (DATETIME) | `WHERE [FE_CON_OPE] = @FechaDia` (DATE) |
| INSERT — lista de columnas | Sin `FECHAINFO` (53 columnas) | Incluye `FECHAINFO` (54 columnas) |
| SELECT fuente | Sin `FECHAINFO` | Selecciona `@FechaDia` como `FECHAINFO` |

> **Código muerto**: mismo patrón recurrente — `@FechaIni` y `@FechaFin` calculados pero nunca usados en el WHERE. El reporte es de periodicidad **DIARIA**.

> **Nota sobre columna de filtro**: el DELETE e INSERT filtran por `FE_CON_OPE` (fecha de concertación de la operación), no por una columna de fecha de proceso. Patrón ya documentado en `083_ENT_CVT_IN` y `081_CVT TR`. Se preserva el comportamiento original.

### ION.dbo.[155_ENT_SWAP_IV]

| Elemento | Estado original | Estado corregido |
|---|---|---|
| Columna `ID` en SELECT | Incluida | Eliminada (campo interno de auditoría) |
| Columna `FECHA_EXTRACCION` en SELECT | Incluida | Eliminada (campo interno de auditoría) |
| Columna `FECHAINFO` en SELECT | Ausente | Agregada |
| Comentarios muertos al final | `--EXEC ...` y `-- Para reportes diarios ...` | Eliminados |

---

## Scripts generados

| Archivo | Propósito |
|---|---|
| `155_ENT_SWAP_IV_CORRECCION.sql` | Aplica todos los cambios. Idempotente. |
| `155_ENT_SWAP_IV_ROLLBACK.sql` | Revierte al estado previo: SP ION → SP SILVER → DROP FECHAINFO. |

---

## Actualización posterior (consideraciones 11 y 12)

> Tras este hallazgo se aplicaron dos reglas generales (ver `deploy/CONSIDERACIONES_DESARROLLO.md`):
> - **Nombre de columna**: el layout la nombra `FECHAINFO`, pero se **estandarizó a `FECHA_INFO`** (con guion bajo) en tabla y SPs. El script de corrección incluye un bloque de **migración idempotente** (`sp_rename` si encuentra la columna vieja) y deja un comentario en el SP. En las tablas/SPs el nombre vigente es **`FECHA_INFO`**.
> - **Formato de fecha en ION**: la salida del SP de ION entrega las fechas en **`AAAA/MM/DD`** (`FORMAT(...,'yyyy/MM/dd')`), con comentario en el SP. (`FE_EN_RE` y `FE_RE_EN` no se formatean: son catálogos de texto `MOD_TAS`, no fechas.)
>
> Nota: las referencias a `FECHAINFO` que aparecen más abajo reflejan el nombre **original del layout**; el objeto desplegado usa `FECHA_INFO`.

## Notas para producción

- El rollback elimina `FECHA_INFO`; los datos en esa columna no son recuperables sin respaldo previo.
- `FECHA_INFO` se agrega como `NULL` para no romper registros existentes.
- En el entorno existen SPs hermanos de la familia SWAP (153, 154, 156, 157) que no forman parte de este alcance pero que probablemente presenten los mismos hallazgos.
- `tbl_Control_Ejecucion`, `INDICE_REPORTES` y `LogSilverDiario` no son tocados por ninguno de los scripts.
