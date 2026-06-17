# Hallazgos: 132_ENT_FUT_CONVAL — Futuros / Convalidaciones (Diaria)

Fuente de referencia: `layout/Layout OFF_FX_V11.xlsx` — hoja `FILE_FUT_CONVAL`

---

## Columnas con discrepancias

| Orden layout | Nombre | Tipo layout | Longitud | Estado en BD | Hallazgo | Corrección aplicada |
|---|---|---|---|---|---|---|
| 19 | `NOCIONAL` | NUMERO | 15 | **Ausente** | Columna regulatoria faltante | `ADD COLUMN numeric(15,0) NULL` |
| 20 | `MON_NOCIONAL` | TEXTO | 3 | **Ausente** | Columna regulatoria faltante | `ADD COLUMN varchar(3) NULL` |
| 21 | `FECHAINFO` | FECHA | aaaa/mm/dd | **Ausente** | Columna regulatoria faltante | `ADD COLUMN date NULL` |

Las 18 columnas restantes del layout están presentes en la tabla con tipos y longitudes correctos.

---

## Cambios en Stored Procedures

### SILVER.dbo.[132_ENT_FUT_CONVAL]

| Elemento | Estado original | Estado corregido |
|---|---|---|
| Variables `@FechaIni` / `@FechaFin` | Declaradas y calculadas (ventana mensual) | Eliminadas — código muerto |
| Variable `@FechaDia` | No existía | Agregada: `CAST(@FechaSistema AS DATE)` |
| DELETE idempotente | `WHERE [FE_CORTE] = @FechaSistema` (DATETIME) | `WHERE [FE_CORTE] = @FechaDia` (DATE) |
| INSERT — lista de columnas | Sin `NOCIONAL`, `MON_NOCIONAL`, `FECHAINFO` | Incluye las 3 columnas nuevas |
| SELECT fuente | Sin `NOCIONAL`, `MON_NOCIONAL`, `FECHAINFO` | Selecciona `NOCIONAL`, `MON_NOCIONAL` de la fuente y `@FechaDia` como `FECHAINFO` |

> **Detalle código muerto**: igual que en `080_CVT TRP`, el SP calculaba `@FechaIni` y `@FechaFin` (ventana mensual) pero el `WHERE` usaba `@FechaSistema` exacto. El reporte es de periodicidad **DIARIA**.

### ION.dbo.[132_ENT_FUT_CONVAL]

| Elemento | Estado original | Estado corregido |
|---|---|---|
| Columna `ID` en SELECT | Incluida | Eliminada (campo interno de auditoría) |
| Columna `FECHA_EXTRACCION` en SELECT | Incluida | Eliminada (campo interno de auditoría) |
| Columna `NOCIONAL` en SELECT | Ausente | Agregada |
| Columna `MON_NOCIONAL` en SELECT | Ausente | Agregada |
| Columna `FECHAINFO` en SELECT | Ausente | Agregada |
| Comentario muerto al final | `-- Para reportes diarios WHERE FECHA_REPORTE = @Fecha` | Eliminado |

---

## Scripts generados

| Archivo | Propósito |
|---|---|
| `132_ENT_FUT_CONVAL_CORRECCION.sql` | Aplica todos los cambios. Idempotente. |
| `132_ENT_FUT_CONVAL_ROLLBACK.sql` | Revierte al estado previo: DROP de las 3 columnas, restaura SPs originales. Orden: SP ION → SP SILVER → columnas (de última a primera). |

---

## Actualización posterior (consideraciones 11 y 12)

> Tras este hallazgo se aplicaron estas reglas (ver `deploy/CONSIDERACIONES_DESARROLLO.md`):
> - **Nombre de columna (EXCEPCIÓN del 132)**: el layout la nombra `FECHAINFO` y, por indicación del usuario, **el 132 conserva ese nombre LITERAL `FECHAINFO`** (sin guion bajo) en tabla, SPs y encabezado de salida. Es una **excepción** a la consideración 11 (que estandariza a `FECHA_INFO`); los reportes 155 y 156 sí usan `FECHA_INFO`. El script incluye una **migración idempotente** que renombra `FECHA_INFO`→`FECHAINFO` si quedó de una corrección previa.
> - **Formato de fecha en ION**: la salida del SP de ION entrega las fechas en **`AAAA/MM/DD`** (`FORMAT(...,'yyyy/MM/dd')`), con comentario en el SP.
> - **Orden de salida (consideración 13)**: el SELECT del SP de ION sigue la columna `ORDEN` del layout; `FECHAINFO` (ORDEN 21) queda como **última columna**.
> - **Campos NO regulatorios eliminados (salida y tabla)**: la versión vigente del layout `OFF_FX_V11` tiene **21 campos** y **no** incluye la sección "Campos Calculados". Por ello `FE_CORTE`, `ACT_OPE_VAL` y `PAS_OPE_VAL` **no son campos del layout** y se **eliminaron tanto del SELECT del SP de ION como de la tabla `RR`** (`DROP COLUMN`). En consecuencia, **el filtro de la ventana pasó de `FE_CORTE` a `FECHAINFO`** en los SP de SILVER e ION. El rollback **re-crea** las 3 columnas (como `NULL`, ya que sus datos se pierden) antes de restaurar los SP originales. La salida quedó en **21 columnas** y la tabla en 23 (21 layout + `ID` + `FECHA_EXTRACCION`).

## Notas para producción

- El rollback elimina `FECHAINFO`, `MON_NOCIONAL` y `NOCIONAL` en ese orden; los datos en esas columnas no son recuperables sin respaldo previo.
- Las 3 columnas se agregan como `NULL` en la corrección para no romper registros existentes. En producción evaluar si deben volverse `NOT NULL` tras la migración de datos.
- `tbl_Control_Ejecucion`, `INDICE_REPORTES` y `LogSilverDiario` no son tocados por ninguno de los scripts.
