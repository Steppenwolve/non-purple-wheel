# Hallazgos: 156_ENT_SWAP_IV_COM — Swaps IV Complemento (Diaria)

Fuente de referencia: `layout/Layout_SWAPS_V10_IV_COM.xlsx` — hoja `FILE_SWAP_IV_COM`

---

## Columnas con discrepancias

| Orden layout | Nombre | Tipo layout | Formato | Estado en BD | Hallazgo | Corrección aplicada |
|---|---|---|---|---|---|---|
| 23 | `FECHAINFO` | FECHA | AAAA/MM/DD | **Ausente** | Columna regulatoria faltante | `ADD COLUMN date NULL` |

Las 22 columnas restantes del layout están presentes en la tabla con tipos y longitudes correctos,
incluyendo `PRE_SUB_RE` y `PRE_SUB_EN` como `numeric(13,6)` (decimal) conforme al layout.
La tabla cuenta con `ID uniqueidentifier` y `FECHA_EXTRACCION smalldatetime` correctamente definidos.

> **Nota sobre nombre**: igual que `155_ENT_SWAP_IV`, este reporte usa `FECHAINFO` (sin guion bajo).

---

## Cambios en Stored Procedures

### SILVER.dbo.[156_ENT_SWAP_IV_COM]

| Elemento | Estado original | Estado corregido |
|---|---|---|
| Variables `@FechaIni` / `@FechaFin` | Declaradas y calculadas (ventana mensual) | Eliminadas — código muerto |
| Variable `@FechaDia` | No existía | Agregada: `CAST(@FechaSistema AS DATE)` |
| DELETE idempotente | `WHERE [FECHA] = @FechaSistema` (DATETIME) | `WHERE [FECHA] = @FechaDia` (DATE) |
| INSERT — lista de columnas | Sin `FECHAINFO` (22 columnas) | Incluye `FECHAINFO` (23 columnas) |
| SELECT fuente | Sin `FECHAINFO` | Selecciona `@FechaDia` como `FECHAINFO` |

> **Código muerto**: mismo patrón recurrente — `@FechaIni` y `@FechaFin` calculados pero nunca usados en el WHERE. El reporte es de periodicidad **DIARIA**.

> **Nota sobre columna de filtro**: a diferencia de otros reportes de la familia SWAP, este SP filtra por `[FECHA]` (campo del layout, fecha de concertación), que ya es de tipo `date` en la tabla. La corrección introduce `@FechaDia` para consistencia explícita, sin cambio de comportamiento.

### ION.dbo.[156_ENT_SWAP_IV_COM]

| Elemento | Estado original | Estado corregido |
|---|---|---|
| Columna `ID` en SELECT | Incluida | Eliminada (campo interno de auditoría) |
| Columna `FECHA_EXTRACCION` en SELECT | Incluida | Eliminada (campo interno de auditoría) |
| Columna `FECHAINFO` en SELECT | Ausente | Agregada |
| Comentarios muertos al final | `--EXEC ...` y `-- Para reportes diarios ...` | Eliminados |

---

## Relación con reporte hermano

Este reporte es complementario de `155_ENT_SWAP_IV`. El campo `NU_ID` (campo #3, llave) permite unir ambos reportes. Los cambios aplicados aquí son consistentes con los aplicados en `155_ENT_SWAP_IV_CORRECCION.sql`.

---

## Scripts generados

| Archivo | Propósito |
|---|---|
| `156_ENT_SWAP_IV_COM_CORRECCION.sql` | Aplica todos los cambios. Idempotente. |
| `156_ENT_SWAP_IV_COM_ROLLBACK.sql` | Revierte al estado previo: SP ION → SP SILVER → DROP FECHAINFO. |

---

## Actualización posterior (consideraciones 11 y 12)

> Tras este hallazgo se aplicaron estas reglas (ver `deploy/CONSIDERACIONES_DESARROLLO.md`):
> - **Nombre de columna (EXCEPCIÓN del 156)**: el layout la nombra `FECHAINFO` y, por indicación del usuario, **el 156 conserva ese nombre LITERAL `FECHAINFO`** (sin guion bajo) en tabla, SPs y encabezado de salida. Es una **excepción** a la consideración 11 (igual que el 132); el reporte hermano 155 sí usa `FECHA_INFO`. El script incluye una **migración idempotente** que renombra `FECHA_INFO`→`FECHAINFO` si quedó de una corrección previa.
> - **Formato de fecha en ION**: la salida del SP de ION entrega las fechas en **`AAAA/MM/DD`** (`FORMAT(...,'yyyy/MM/dd')`), con comentario en el SP.

## Notas para producción

- El rollback elimina `FECHAINFO`; los datos en esa columna no son recuperables sin respaldo previo.
- `FECHAINFO` se agrega como `NULL` para no romper registros existentes.
- `tbl_Control_Ejecucion`, `INDICE_REPORTES` y `LogSilverDiario` no son tocados por ninguno de los scripts.
