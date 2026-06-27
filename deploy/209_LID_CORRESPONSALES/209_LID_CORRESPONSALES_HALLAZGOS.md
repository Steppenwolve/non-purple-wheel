# Hallazgos — 209_LID_CORRESPONSALES
# Layout: LAYOUT LID V4 LID CORRESPONSALES

| # | Hallazgo | Acción aplicada |
|---|----------|-----------------|
| 1 | **Objetos 209 inexistentes en todas las capas** — BRONZE, SILVER, SPs e INDICE_REPORTES son nuevos en su totalidad | CREATE TABLE en BRONZE y SILVER; CREATE OR ALTER para ambos SPs; INSERT en INDICE_REPORTES |
| 2 | **INDICE_REPORTES: numero=209 sin registro previo** — se realiza `INSERT` (no `UPDATE`) | `INSERT` con frecuencia='Mensual', activo=0 |
| 3 | **Todos los campos son OBLIGATORIO=Si** → `NOT NULL` en BRONZE y SILVER, incluyendo `FECHA_INFO` (ORDEN 10) que es el campo de control mensual LMDA | DDL con `NOT NULL` en todos los campos de datos |
| 4 | **CASFIM: claves mixtas en catálogo** — primeras filas en formato string con padding `'000111'`, `'000750'`…; filas siguientes como enteros `780`, `790`… | Tipo `varchar(6)` en BRONZE y SILVER para absorber ambos formatos |
| 5 | **Catálogo Moneda**: referenciado como `"Moneda"` en layout → archivo `MONEDA.xlsx` (en mayúsculas); clave alfabética ISO 3 chars (`MXN`, `USD`, `EUR`…) | Tipo `varchar(3)` |
| 6 | **Sin renombrado de columnas** — layout es nuevo, no hay desalineación camelCase/UPPERCASE | Section 01 dedicada a CREATE TABLE SILVER (sin sp_rename) |

## Catálogos aplicados al dummy

| Campo | Catálogo | Valores utilizados |
|-------|----------|--------------------|
| `TIPO_VALOR` | `Tipo_valor.xlsx` | 1, 2, 3, 10 |
| `MONEDA` | `MONEDA.xlsx` | MXN, USD, EUR |
| `ID_PAGOS_REAL` | `Id_Pagos_Real.xlsx` | 0 (sin pagos), 1 (con pagos) |
| `CONT_CORRESPONSAL` | `CASFIM.xlsx` | `000111`, `000750`, `000760`, `000770`, `000775` |
| `CONT_RECEPTORA` | `CASFIM.xlsx` | `000111`, `000750`, `000760`, `000770`, `000775` |
| `CARACT_LIQUIDACION` | `Caract_liq.xlsx` | 3 (liquidaciones a través de corresponsales) |

## Diseño de ventana mensual

```sql
DECLARE @FechaIni DATE = DATEFROMPARTS(YEAR(@FechaSistema), MONTH(@FechaSistema), 1);
DECLARE @FechaFin DATE = DATEADD(MONTH, 1, @FechaIni);
-- Filtro: FECHA_INFO >= @FechaIni AND FECHA_INFO < @FechaFin
```

Tanto el SP SILVER como el SP ION filtran por el mes completo de `FECHA_INFO`. El ETL debe garantizar que `FECHA_INFO` en el archivo fuente corresponda al mes de procesamiento.
