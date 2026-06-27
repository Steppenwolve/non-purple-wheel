# Hallazgos — 075_ENT_TENENCIA_REPAD
# Layout: LayoutTenencia_V2_FT_TENENCIA

| # | Hallazgo | Corrección aplicada |
|---|----------|---------------------|
| 1 | Las 11 columnas de `BRONZE.[LMDA].[FT_TENENCIA]` están en **camelCase** (`TituloObjeto`, `NumeroTitulos`…) — no coinciden con los nombres del layout (UPPERCASE): `TITULOOBJETO`, `NUMEROTITULOS`, `CONTRAPARTE`, `MONEDA`, `PRECIOUNITARIO`, `PRECIO_VAL_MERCADO`, `CLASIFICACIONCONTABLE`, `POSICIONOPERACION`, `CVETIPOINSTRUMENTO`, `OFICINA`, `DEPOSITADOENGARANTIA` | `sp_rename` × 11 en BRONZE |
| 2 | Las mismas 11 columnas en `SILVER.[RR].[075_ENT_TENENCIA_REPAD]` presentan el mismo problema de naming camelCase | `sp_rename` × 11 en SILVER |
| 3 | **SP SILVER no existía** — el pipeline nunca tuvo implementación en la capa de transformación | `CREATE OR ALTER PROCEDURE` creado con origen `BRONZE.LMDA.FT_TENENCIA` |
| 4 | **SP ION — fecha hardcodeada**: la ventana semanal se calculaba sobre `'20250203'` (fecha fija) en lugar del parámetro `@FECHA` — el SP devolvía siempre la misma semana ignorando el argumento de entrada | Corregido a `@FECHA` |
| 5 | SP ION filtraba por `FECHA_EXTRACCION` con la ventana de la fecha hardcodeada — doble error | Filtro corregido a `FECHA_EXTRACCION >= @FechaIni AND < @FechaFin` usando `@FECHA` |
| 6 | SP ION exponía `ID` y `FECHA_EXTRACCION` (dos veces: directa y como alias `FECHA_REPORTE`) — campos internos que no deben aparecer en el reporte (violación consideración 9) | Eliminados del SELECT |
| 7 | SP ION tenía `PRINT` statements de debug dentro del cuerpo | Eliminados |
| 8 | SP ION no respetaba el ORDEN del layout (`ID` en posición 1 antes que `TITULOOBJETO`) | SELECT reordenado: columnas ORDEN 1-11 del layout con nombres UPPERCASE |
| 9 | `INDICE_REPORTES` (numero=75): `frecuencia = 'Solo cuando hay nuevas contrapartes'` — debe ser `'Semanal'` | `UPDATE` a `'Semanal'` |

## Decisión de diseño: segmentación semanal por FECHA_EXTRACCION

El CSV fuente de este reporte **no contiene campo de fecha** (`FECHA_INFO` no aplica). La segmentación semanal se realiza mediante `FECHA_EXTRACCION`, que el ETL asigna automáticamente (`DEFAULT GETDATE()`) al momento de la carga en BRONZE. Tanto el SP SILVER como el SP ION filtran por la ventana `FECHA_EXTRACCION >= @FechaIni AND FECHA_EXTRACCION < @FechaFin`.

**Implicación operativa:** el ETL debe ejecutarse dentro de la misma semana ISO (lunes a domingo) en que corre el SP SILVER. Si el ETL carga el lunes y el SP se ejecuta el viernes de la misma semana, la ventana los captura juntos correctamente.

## Catálogos aplicados

| Campo | Catálogo | Valores válidos |
|-------|----------|-----------------|
| `CONTRAPARTE` | `CASFIM.xlsx` | `000111`, `000750`, `000760`, `000770`, `000775` |
| `MONEDA` | `MonedaISO.xlsx` | `MXN`, `USD`, `EUR` (campo Opcional) |
| `CLASIFICACIONCONTABLE` | `ClasificacionContableCVT.xlsx` | `PN`, `CV`, `DV` |
| `POSICIONOPERACION` | `PosicionOperacionRepo.xlsx` | `A` (Reportador), `P` (Reportado) |
| `CVETIPOINSTRUMENTO` | `CVETIPOINSTRUMENTO.xlsx` | `TI` (Títulos), `RE` (Reportos) |
| `OFICINA` | `CveOficina.xlsx` | `A` (Agencias exterior), `R` (República Mexicana) |
| `DEPOSITADOENGARANTIA` | `ESGARANTIA.xlsx` | `0` (No), `1` (Sí) — almacenado como varchar(1) |
