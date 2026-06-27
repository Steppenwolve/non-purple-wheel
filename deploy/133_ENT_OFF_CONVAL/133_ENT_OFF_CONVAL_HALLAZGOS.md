# Hallazgos — 133_ENT_OFF_CONVAL (Layout OFF_FX_V11_OFF_CONVAL)

| # | Hallazgo | Corrección aplicada |
|---|----------|---------------------|
| 1 | `BRONZE.[LMDA].[OFF_CONVAL]` **no existía** — el SP SILVER ya la referenciaba pero nunca había podido ejecutarse | `CREATE TABLE` con los 17 campos del layout + ID + FECHA_EXTRACCION |
| 2 | `SILVER.[RR].[133_ENT_OFF_CONVAL]` tenía **3 columnas extra** no presentes en el layout V11: `FE_CORTE` (date NOT NULL), `ACT_OPE_VAL` (numeric(15,0) NOT NULL), `PAS_OPE_VAL` (numeric(15,0) NOT NULL). Al ser NOT NULL sin DEFAULT, el SP fallaría al insertar | `ALTER TABLE DROP COLUMN` x3 |
| 3 | SP SILVER: DELETE filtraba por `FE_CON_OPE = @FechaSistema` (campo de negocio) en lugar de ventana semanal de `FECHAINFO` (control LMDA) | Corregido a `FECHAINFO >= @FechaIni AND FECHAINFO < @FechaFin` |
| 4 | SP SILVER: INSERT/SELECT filtraba por `FECHAINFO = @FechaSistema` (puntual) en lugar de ventana semanal | Cambiado a patrón semanal LMDA con `@FechaIni` / `@FechaFin` |
| 5 | SP ION: filtro `WHERE FECHAINFO = @FECHA` (puntual) en lugar de ventana semanal | Cambiado a `FECHAINFO >= @FechaIni AND FECHAINFO < @FechaFin` |
| 6 | `INDICE_REPORTES` (numero=133): `frecuencia = 'Diaria'` — debe ser `'Semanal'` según el layout | `UPDATE` a `'Semanal'` |
| 7 | El catálogo `PosicionOperacion_V4` para `POS_OPER` tiene claves de hasta 3 caracteres (`S01, S02, C01, C02, P02, P03, NA`), pero la definición del layout indicaba `TEXTO 1`. La columna se amplió a `varchar(3)` para aceptar todos los valores del catálogo. Se agregó nota en los SPs con los valores válidos | `ALTER COLUMN POS_OPER varchar(3)` en BRONZE y SILVER; nota de catálogo en SP SILVER e ION |

## Catálogos aplicados

| Campo | Catálogo | Valores usados en dummy |
|-------|----------|------------------------|
| `POS_OPER` | `PosicionOperacion_V4` (ver hallazgo 7) | `'S01'`, `'S02'`, `'C01'`, `'C02'`, `'P02'`, `'P03'`, `'NA'` |
| `OBJ_OPE` | `OBJ_OPE_V1.xls` | `'NE'`, `'CC'`, `'CT'`, `'CW'`, `'CA'`, `'CP'`, `'JP'` |
| `PAQ_EST` | `PAQ_EST_DER_V1.xls` | `7` (aplica a OFF según catálogo) |
| `MON_ACT_OPE`, `MON_PAS_OPE`, `MON_NOCIONAL` | `MonedaISO.xlsx` | `'MXN'`, `'USD'`, `'EUR'` |

## Notas

- `FECHAINFO` está definido como ORDEN 17 en el layout (AAAA/MM/DD) — se expone en ION con `FORMAT(..., 'yyyy/MM/dd')` y se usa como campo de control LMDA para los filtros de los SPs.
- `NOCIONAL` y `MON_NOCIONAL` son opcionales (solo RCS) en el layout — se mantienen en la tabla y en los SPs; en BRONZE se definen como `NULL`.
- SP ION ya tenía las 17 columnas correctas y el `FORMAT` de fechas adecuado; solo se corrigió el filtro de periodicidad.
