# Hallazgos — 084_ENT_TENENCIA_PRECIO
# Layout: CORE_LayoutTenenciaAdicional_v3.3_Layout_TENENCIA_PRECIO

| # | Hallazgo | Corrección aplicada |
|---|----------|---------------------|
| 1 | `BRONZE.[LMDA].[TENENCIA_PRECIO]` **no existía** — el SP SILVER la referenciaba pero nunca podía leer datos | `CREATE TABLE` con 10 campos del layout + FECHA_INFO + ID + FECHA_EXTRACCION |
| 2 | Columna `TITULO_OBJETO` en SILVER no coincide con nombre del layout `TITULOOBJETO` (sin guión bajo) | `sp_rename TITULO_OBJETO → TITULOOBJETO` |
| 3 | Columna `FECHA_REPORTE` en SILVER no coincide con nombre del layout `FECHA_INFO` (campo control LMDA) | `sp_rename FECHA_REPORTE → FECHA_INFO` |
| 4 | **SP SILVER crítico**: el `SELECT` origen apuntaba a `[SILVER].[RR].[084_ENT_TENENCIA_PRECIO]` (auto-referencia) en lugar de `[BRONZE].[LMDA].[TENENCIA_PRECIO]` — el pipeline nunca ha insertado datos reales | Origen corregido a `BRONZE.LMDA.TENENCIA_PRECIO` |
| 5 | SP SILVER: DELETE e INSERT filtraban por `FECHA_REPORTE` — tras renombrar se debe filtrar por `FECHA_INFO` con ventana semanal | Filtros actualizados a `FECHA_INFO` |
| 6 | SP ION exponía `ID`, `FECHA_EXTRACCION` y `FECHA_REPORTE` — campos internos/control que no deben aparecer en el reporte (violación consideración 9) | Eliminados del SELECT |
| 7 | SP ION no respetaba el ORDEN del layout: `ID` encabezaba el SELECT antes de `TITULOOBJETO` | SELECT reordenado: columnas ORDEN 1-11 del layout |
| 8 | SP ION no aplicaba `FORMAT` a `FECHA_INFO` — debe salir como `AAAA/MM/DD` | `FORMAT(T.[FECHA_INFO], 'yyyy/MM/dd')` en posición ORDEN 11 |

## Catálogos aplicados

| Campo | Catálogo | Valores válidos |
|-------|----------|-----------------|
| `TITULOOBJETO` | `CveTitulos_V3.xlsx` | AEDUSD, ARSMXN, AUDJPY, AUDMXN, AUDUSD, BCIADMO... (catálogo extenso) |
| `CLASIFICACION_CONTABLE` | `Clasificacion Contable.xlsx` (o `ClasificacionContableCVT.xlsx`) | `PN`, `CV`, `DV`, `CO` |
| `Restriccion` | `Restriccion.xlsx` | `G`, `NG`, `V`, `RP`, `CR` |
| `Custodio` / `Cliente` | `CASFIM.xlsx` | `000111`, `000750`, `000760`, `000770`, `000775`... |
| `FechaValor` | `Fecha Valor.xlsx` | `0` (No), `1` (Sí) |

## Notas

- `FECHA_INFO` aparece como ORDEN 11 en el layout y **sí se expone** en el SP ION con `FORMAT(..., 'yyyy/MM/dd')`.
- `FECHA_INFO` actúa simultáneamente como campo de control LMDA (filtro en SP SILVER) y como columna de salida del reporte.
- El catálogo `Clasificacion Contable.xlsx` y `ClasificacionContableCVT.xlsx` contienen los mismos valores (`PN`, `CV`, `DV`); `ClasificacionContableCVT.xlsx` agrega `CO`.
