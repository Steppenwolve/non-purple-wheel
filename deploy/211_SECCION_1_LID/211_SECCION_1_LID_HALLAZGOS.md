# Hallazgos — 211_SECCION_1_LID (Reporte LID SI)

- **Layout:** `LAYOUT LID V4 LID SI.xlsx`, hoja **LID S1**
- **Periodicidad:** Diaria
- **Origen:** LMDA → `BRONZE.LMDA.SECCION_1_LID`
- **Objetos DB:** `211_SECCION_1_LID`

## Estado inicial
Reporte **nuevo**: no existía en el esquema restaurado de prod (ni BRONZE, ni SILVER, ni ION). Se construyó desde cero usando `210_LID_LIQUIDACIONES` como plantilla.

## Estructura (4 campos, todos obligatorios)

| ORDEN | Campo | Tipo SQL | Catálogo | Notas |
|---|---|---|---|---|
| 1 | TIPO_ACTIVO | numeric(2,0) | Tipo_Activo_LID (14 valores) | Llave de negocio |
| 2 | SALDO_ID | numeric(12,0) | — | Saldo disponible inicio de día |
| 3 | MONEDA | varchar(3) | Moneda ISO | **NO es llave** (evita bloqueo de cargas: casi siempre MXN) |
| 4 | FECHA_INFO | date | — | Salida ION en formato `yyyy/MM/dd` |

## Decisiones
- **MONEDA no es llave** (petición del usuario): en el layout figura como llave junto con TIPO_ACTIVO, pero al ser MXN en la mayoría de casos generaría duplicados que bloquean la carga. `processor.json` usa `append` sin restricción de unicidad.
- **Tabla BRONZE = `LMDA.SECCION_1_LID`** (coincide con `processor.json` ya entregado; alternativa descartada: `LMDA.LID_SI`).
- **Filtro diario:** ventana `[día, día+1)` sobre `FECHA_INFO` (los hermanos LID mensuales usan ventana de mes).

## Entregables
- `211_SECCION_1_LID_AJUSTE.sql` — S00 tabla BRONZE, S01 tabla SILVER, S02 SP SILVER, S03 SP ION, S04 alta en INDICE_REPORTES
- `211_SECCION_1_LID_ROLLBACK.sql` — DROP de tablas/SPs + DELETE índice
- `211_SECCION_1_LID_processor.json` — mapeo de ingesta (4 campos)
- `211_SECCION_1_LID_dummy.txt` — 15 registros

## Prueba en esquema local (OK)
1. AJUSTE aplicado sin errores (2 tablas, 2 SPs, 1 fila índice).
2. Cargadas 15 filas dummy en BRONZE con `FECHA_INFO` = hoy.
3. `EXEC` SP SILVER → 15 filas insertadas en SILVER.
4. `EXEC` SP ION → 15 filas, columnas y formato `yyyy/MM/dd` correctos; MXN+USD; TIPO_ACTIVO 5 duplicado sin bloqueo.
