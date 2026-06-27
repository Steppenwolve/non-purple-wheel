# Hallazgos — 210_LID_LIQUIDACIONES
# Layout: LAYOUT LID V4 LID LIQUIDACIONES

| # | Hallazgo | Corrección aplicada |
|---|----------|---------------------|
| 1 | `INDICE_REPORTES.frecuencia = 'Diaria'` — el reporte tiene periodicidad mensual | `UPDATE` a `'Mensual'` en Section 04 |
| 2 | **SP SILVER — filtro incorrecto (diario)**: filtraba `WHERE [FECHA_LIQ] = @FechaSistema` (igualdad exacta por fecha de liquidación). Para un reporte mensual LMDA el control debe ser `FECHA_INFO` con ventana `>= primer día del mes AND < primer día del mes siguiente` | Reemplazado por ventana mensual `DATEFROMPARTS(YEAR,MONTH,1)` sobre `FECHA_INFO` |
| 3 | **SP ION — filtro incorrecto (diario)**: filtraba `WHERE [FECHA_LIQ] = @FECHA`. Para mensual debe filtrar por rango mensual de `FECHA_INFO` | Reemplazado por ventana mensual sobre `FECHA_INFO` |
| 4 | Estructura de `BRONZE.LMDA.LID_LIQUIDACIONES` y `SILVER.RR.210_LID_LIQUIDACIONES` **correcta** — nombres y tipos de columnas coinciden con el layout | Sin cambios DDL ni sp_rename |
| 5 | SP ION anterior no aplicaba `FORMAT` consistente a todas las fechas (solo algunas tenían el alias correcto) | Aplicado `FORMAT(...,'yyyy/MM/dd')` a `FECHA_LIQ` (ORDEN 1), `FECHA_EST_PAGO` (ORDEN 10) y `FECHA_INFO` (ORDEN 16) |

## Catálogos aplicados al dummy

| Campo | Catálogo | Valores utilizados |
|-------|----------|--------------------|
| `TIPO_VALOR` | `Tipo_valor.xlsx` | 1 (máximo), 2 (segundo máximo), 3 (tercer máximo), 10 (total del día) |
| `TIPO_OBLIGACION` | `Tipo_Obligacion.xlsx` | 1, 2, 3, 4, 6, 7, 8, 10 |
| `MONEDA` | `MonedaISO.xlsx` | MXN, USD, EUR |
| `ID_PAGOS` | `Id_Pagos.xlsx` | 0 (sin obligaciones), 1 (con obligaciones) |
| `FLAG_HORARIO` | `Flag_Horario.xlsx` | 0 (sin horario específico), 1 (con horario específico) |
| `ID_PAGOS_RET` | `Id_Pagos_Ret.xlsx` | 1, 2, 3, 4, 5, 7, 8, 9 |
| `MOTIVO_RET` | `MOTIVO_RET.xlsx` | 0 (no aplica), 1, 2, 3 |
| `CARACT_LIQUIDACION` | `Caract_liq.xlsx` | 1 (en tiempo y forma), 2 (retrasadas/no aplicadas), 3 (a través de corresponsales) |

## Diseño de ventana mensual

El SP SILVER y el SP ION filtran por el mes completo de `FECHA_INFO`:

```sql
DECLARE @FechaIni DATE = DATEFROMPARTS(YEAR(@FechaSistema), MONTH(@FechaSistema), 1);
DECLARE @FechaFin DATE = DATEADD(MONTH, 1, @FechaIni);
-- Filtro: FECHA_INFO >= @FechaIni AND FECHA_INFO < @FechaFin
```

El ETL debe asegurarse de que `FECHA_INFO` en el archivo fuente corresponda al mes que se desea procesar. El SP SILVER elimina e inserta todos los registros del mes indicado en `@FechaSistema`.
