# Hallazgos: 080_CVT TRP — Custodia / Transferencia de Títulos (Diaria)

Fuente de referencia: `layout/Layout_CVT_TRP_V3.xlsx` — hoja `CVT_TRP`

---

## Columnas con discrepancias

| # | Nombre en layout | Tipo layout | Formato / Longitud | Estado en BD | Hallazgo | Corrección aplicada |
|---|-----------------|-------------|-------------------|--------------|----------|---------------------|
| 5 | NUMTITULOS | NUMERO | Longitud 12 | `int` (máx 10 dígitos) | Tipo insuficiente para la longitud requerida | `ALTER COLUMN numeric(12,0) NOT NULL` |
| 9 | FECHA_INFO | FECHA | aaaammdd | **Ausente** | Columna regulatoria faltante en tabla y SPs | `ADD COLUMN date NULL` + incluida en SILVER SP y ION SP |

---

## Cambios en Stored Procedures

### SILVER.dbo.[080_CVT TRP]

| Elemento | Estado original | Estado corregido |
|----------|----------------|-----------------|
| Variables `@FechaIni` / `@FechaFin` | Declaradas y calculadas (ventana mensual) | Eliminadas — código muerto |
| Variable `@FechaDia` | No existía | Agregada: `CAST(@FechaSistema AS DATE)` |
| DELETE idempotente | `WHERE [FECHATRANS] = @FechaSistema` (DATETIME) | `WHERE [FECHATRANS] = @FechaDia` (DATE) |
| INSERT — lista de columnas | Sin `FECHA_INFO` | Incluye `FECHA_INFO` |
| SELECT fuente | Sin `FECHA_INFO` | Selecciona `@FechaDia` como `FECHA_INFO` |

> **Detalle código muerto**: el SP original calculaba `@FechaIni = DATEFROMPARTS(...)` y `@FechaFin = DATEADD(month,1,@FechaIni)` pero el `WHERE` del DELETE y del INSERT usaban `@FechaSistema` exacto (lógica DIARIA), por lo que la ventana mensual nunca se aplicó. El reporte es de periodicidad **DIARIA** confirmada.

### ION.dbo.[080_CVT TRP]

| Elemento | Estado original | Estado corregido |
|----------|----------------|-----------------|
| Columna `ID` en SELECT | Incluida | Eliminada (campo interno de auditoría) |
| Columna `FECHA_EXTRACCION` en SELECT | Incluida | Eliminada (campo interno de auditoría) |
| Columna `FECHA_INFO` en SELECT | Ausente | Agregada (campo regulatorio del layout) |

---

## Scripts generados

| Archivo | Propósito |
|---------|-----------|
| `080_CVT_TRP_CORRECCION.sql` | Aplica todos los cambios descritos. Idempotente. |
| `080_CVT_TRP_ROLLBACK.sql` | Revierte al estado previo: `numeric` → `int`, DROP `FECHA_INFO`, restaura SPs originales. |

---

## Notas para producción

- El rollback **no recupera datos** que hayan sido escritos en `FECHA_INFO` antes de hacer el rollback; esa columna se elimina con `DROP COLUMN`.
- `CREATE OR ALTER` en el rollback restaura la definición conocida del SP original. No existe una operación de "undo" nativa para SPs en SQL Server.
- Los objetos `tbl_Control_Ejecucion` e `INDICE_REPORTES` no son tocados por ninguno de los dos scripts.
