# Mapeo de campos — Salida SP ION `008_ENT_GARANTIA`

**Contexto:** REPORTES ORIGEN SAF · Periodicidad **Mensual** · `FECHA_INFO` = `EOMONTH(@FechaSistema)` (calculada).

**Tablas de origen** (JOIN en el SP SILVER):
- **A** = `BRONZE.SAF.PR_GARANTIAS` (tabla base)
- **B** = `BRONZE.SAF.PR_CREDITOS` (solo para filtros del `WHERE`; no aporta columnas a la salida)
- **C** = `BRONZE.INF.CREDITO_EMPRESARIAL`
- **D** = `BRONZE.SAF.PR_GARANTIAS_HIPOTECARIAS`

## Filtro (`WHERE`) — segrega la información antes de calcular
El SP SILVER se queda **solo con garantías avaluadas y activas, cuyo crédito asociado está vigente, no es una línea, y es de tipo comercial**:

```sql
WHERE A.FEC_AVALUO IS NOT NULL                                  -- (1)
  AND B.IND_ESTADO = 'D'                                        -- (2)
  AND B.IND_LINEA = 'N'                                         -- (3)
  AND B.NUM_DESC_TIPO_CREDITO IN (12,13,14,15,28,2,5,18,27)     -- (4) /*COM*/
  AND A.IND_ESTADO = 'A'                                        -- (5)
```

| # | Condición | Tabla | Qué hace |
|---|-----------|-------|----------|
| 1 | `A.FEC_AVALUO IS NOT NULL` | Garantías (A) | Solo garantías **con avalúo** (ya valuadas). |
| 2 | `B.IND_ESTADO = 'D'` | Créditos (B) | Crédito asociado en estado **'D' (dispuesto/vigente)**. |
| 3 | `B.IND_LINEA = 'N'` | Créditos (B) | La operación **NO es una línea** de crédito (es la disposición/crédito directo). |
| 4 | `B.NUM_DESC_TIPO_CREDITO IN (12,13,14,15,28,2,5,18,27)` | Créditos (B) | Solo **tipos de crédito comercial** (`/*COM*/`). |
| 5 | `A.IND_ESTADO = 'A'` | Garantías (A) | Solo garantías con estado **'A' (activa)**. |

**Notas del filtro:**
- Los `LEFT JOIN` a **B** se comportan como **INNER**: al filtrar por columnas de `B`, toda garantía **sin crédito asociado** (B NULL) se descarta. `C` y `D` no están en el `WHERE`, así que ahí el `LEFT JOIN` sí conserva las filas sin match.
- La segregación es por **estado/tipo de negocio, no por fecha**: el origen es un *snapshot* del estado vigente; la fecha del reporte se calcula aparte (`FECHA_INFO = EOMONTH(@FechaSistema)`).

> Todas las 28 columnas del reporte están documentadas (una línea por campo), incluidas las que salen en blanco/cero.

| # | CAMPO ION | VIENE DE | CÁLCULO | TIPO DE ORIGEN |
|---|-----------|----------|---------|----------------|
| 1 | `ID_GARANTIA` | `A.NUM_GARANTIA` | — | Directo |
| 2 | `TIPO_GARANTIA` | `A.TIP_GARANTIA` | `CASE 'HIP'→53, 'FID'→55` | Cálculo / catálogo |
| 3 | `FECHA_ULT_ACTUALIZACION` | `A.FEC_AVALUO` | `FORMAT(...,'yyyy/MM/dd')` | Directo (fecha) |
| 4 | `MONEDA_GAR` | `A.COD_MONEDA` | `CASE 1→0, 9→200` | Cálculo / catálogo |
| 5 | `PRELACION_GAR` | `C.PRELACION` | `CASE 1→1, 2→2, ELSE 0` | Cálculo / catálogo |
| 6 | `MONTO_GAR` | `A.MON_GARANTIA` | `ISNULL(A.MON_GARANTIA, 0)` | Directo |
| 7 | `FOLIO_REF_FACTURA` | — (constante en SP ION) | `''` | Constante vacía |
| 8 | `RPPC` | — (constante en SP ION) | `''` | Constante vacía |
| 9 | `RUG` | — (constante en SP ION) | `''` | Constante vacía |
| 10 | `RUORL` | — (constante en SP ION) | `''` | Constante vacía |
| 11 | `ROEEFM` | — (constante en SP ION) | `''` | Constante vacía |
| 12 | `FECHA_ULT_AVALUO` | `A.FEC_AVALUO` | `FORMAT(...,'yyyy/MM/dd')` | Directo (fecha) |
| 13 | `FECHA_INSCRIPCION_RPPC` | — (constante en SP ION) | `''` | Constante vacía |
| 14 | `FECHA_INSCRIPCION_RUG` | — (constante en SP ION) | `''` | Constante vacía |
| 15 | `FECHA_INSCRIPCION_RUORL` | — (constante en SP ION) | `''` | Constante vacía |
| 16 | `FECHA_INSCRIPCION_ROEEFM` | — (constante en SP ION) | `''` | Constante vacía |
| 17 | `LOCALIDAD_GARANTIA_INM` | `D.COD_PAIS`, `D.COD_PROVINCIA` | `CONCAT('484', IIF(COD_PAIS IS NULL,'00',COD_PAIS), IIF(COD_PROVINCIA IS NULL,'000',COD_PROVINCIA), '0001')` | Cálculo |
| 18 | `DESCRIPCION_GARANTIA` | SILVER = `NULL` | `ISNULL(...,'')` → `''` | Nulificado en SILVER |
| 19 | `VALOR_GAR_PROYECTADO` | — (constante en SP ION) | `''` | Constante vacía |
| 20 | `HC` | — (constante en SP ION) | `''` | Constante vacía |
| 21 | `VENCIMIENTO_RESTANTE` | — (constante en SP ION) | `''` | Constante vacía |
| 22 | `GRADO_RIESGO` | SILVER `GRADO_REISGP` = `NULL` (columna con typo) | `ISNULL(...,0)` → `0` | Nulificado en SILVER |
| 23 | `AGENCIA_CALIFICACION` | — (constante en SP ION) | `''` | Constante vacía |
| 24 | `CALIFICACION` | — (constante en SP ION) | `''` | Constante vacía |
| 25 | `EMISOR` | — (constante en SP ION) | `''` | Constante vacía |
| 26 | `ESCALA` | — (constante en SP ION) | `''` | Constante vacía |
| 27 | `ESIPC` | — (constante en SP ION) | `''` | Constante vacía |
| 28 | `FECHA_INFO` | `@FechaSistema` (parámetro) | `FORMAT(EOMONTH(@FechaSistema),'yyyy/MM/dd')` | Cálculo (fin de mes) |

## Resumen
- **Directos / con dato real:** 1, 3, 6, 12 (de `A`), 5 (de `C`).
- **Cálculo / catálogo:** 2, 4, 5 (CASE), 17 (CONCAT), 28 (EOMONTH).
- **Nulificados en SILVER:** 18 (`''`), 22 (`0`).
- **Constante vacía `''` (agregados en SP ION):** 7-11, 13-16, 19-21, 23-27 → **17 campos**.
- `B` (`SAF.PR_CREDITOS`) **no aporta columnas**: solo se usa en el `WHERE` (`IND_ESTADO='D'`, `IND_LINEA='N'`, `NUM_DESC_TIPO_CREDITO IN (...)`).
