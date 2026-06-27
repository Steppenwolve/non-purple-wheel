# Hallazgos — 121_ENT_REPORTOS_MN_ME (Layout V3 FT_REPORTOS)

| # | Hallazgo | Corrección aplicada |
|---|----------|---------------------|
| 1 | `SILVER.[RR].[121_ENT_REPORTOS_MN_ME]` tenía **13 columnas del layout V7.1** que **no existen en V3**: `RESIDENCIA_CONTRAPARTE`, `PROPIA_TERCEROS`, `CLIENTE_PROV`, `HAIRCUT`, `REP_SUSTITUCION`, `MODALIDAD_REPORTO`, `PLAZO_EVERGREEN`, `REP_CONJUNTO_VAL`, `REP_AG_TRIPARTITO`, `AGENTE_TRIPARTITO`, `TASA_REFERENCIA_PREMIO`, `SOBRETASA_PREMIO`, `PERIODO_PAGO_PREMIO` | `ALTER TABLE DROP COLUMN` x13 (con DROP previo de DEFAULT constraints) |
| 2 | `TIPOTASAPREMIO` existía como `int NULL` en posición 46 (fuera de orden); el layout V3 lo define como TEXTO 1 (ORDEN 9, catálogo: F=Fija, V=Variable) | `ALTER COLUMN` int → `varchar(1) NOT NULL`; DEFAULT `''` |
| 3 | Faltaban `TIPOMODIFICACION` (ORDEN 18, TEXTO 1) y `FECHA_INFO` (control LMDA) en SILVER | `ALTER TABLE ADD` para ambas |
| 4 | `BRONZE.[LMDA].[FT_REPORTOS]` no tenía `TIPOTASAPREMIO`, `TIPOMODIFICACION` ni `FECHA_INFO` | `ALTER TABLE ADD` (NULL, se cargan desde el archivo fuente) |
| 5 | SP SILVER: DELETE e INSERT filtraban por `FECHACONCERTACION = @FechaSistema` en lugar de `FECHA_INFO = @FechaDia` (patrón LMDA diaria) | Filtros corregidos a `FECHA_INFO` |
| 6 | SP SILVER: INSERT incluía las 13 cols V7.1 que no existen en el layout V3 (y que en `BRONZE.[LMDA].[FT_REPORTOS]` contienen datos de otra versión) | Eliminadas del INSERT/SELECT; solo cols V3 |
| 7 | SP SILVER: faltaban `TIPOTASAPREMIO`, `TIPOMODIFICACION`, `FECHA_INFO` en INSERT | Agregados |
| 8 | SP ION: exponía las 13 cols V7.1 extra (no son del layout V3) | Eliminadas del SELECT |
| 9 | SP ION: faltaban `TIPOTASAPREMIO` (ORDEN 9) y `TIPOMODIFICACION` (ORDEN 18) en la salida | Agregados en posición correcta según ORDEN |
| 10 | SP ION: filtro `WHERE S.FECHACONCERTACION = @FECHA` en lugar de `FECHA_INFO` | Corregido a `FECHA_INFO` |
| 11 | `FECHA_INFO` no se expone en ION (campo de control interno LMDA) | Omitida del SELECT del SP ION |

## Catálogos aplicados

Catálogos leídos de `layout/CATALOGOS/`:

| Campo | Catálogo | Valores válidos usados en dummy |
|-------|----------|---------------------------------|
| `POSICIONOPERACION` | `PosicionOperacionRepo.xlsx` | `'A'` (Reportador), `'P'` (Reportado) |
| `MONEDAPRECIOUNITARIO` | `MonedaISO.xlsx` | `'MXN'`, `'USD'` |
| `TIPOTASAPREMIO` | `TipoTasaPremio_V1.xlsx` | `'F'` (Fija), `'V'` (Variable) |
| `CORROELECTRONICO` | `CorroElectronico_V1.xlsx` | `80`, `45`, `90`, `10`, `20` (numeric) |
| `TIPOPOSTURA` | `TipoPostura.xlsx` | `'NA'`, `'A'`, `'B'` |
| `OPERACIONBANCOTRABAJO` | `OperacionRealizadaBanco.xlsx` | `'T'`, `'P'` |
| `TIPOMODIFICACION` | `TipoModificacion_V1.xlsx` | `'A'` (Alta), `'B'` (Baja) |
| `CLASIFICACIONCONTABLEOPERACION` | `ClasificacionContableCVT.xlsx` | `'PN'`, `'CV'`, `'DV'` |
| `OFICINA` | `CveOficina.xlsx` | `'A'`, `'R'`, `'F'` |
| `SOBRETASA` | `CveSobretasa.xlsx` | `'0'`, `'1'` |
| `EMISOR`, `CONTRAPARTEREPORTO` | `CASFIM.xlsx` | `'000111'`, `'000750'`, `'000760'` |
| `CUSTODIO`, `CLIENTE` | `CASFIM.xlsx` (numeric) | `111`, `750`, `760` |
| `APLICA_ANEXO1C` | `CveAplicaAnexo1C.xlsx` | `0`, `1` |
| `FECHAVALOR` | `Fecha Valor.xlsx` | `0`, `1` |
| `RESTRICCION` | `Restriccion.xlsx` | `'G'`, `'NG'`, `'V'` |

## Nota sobre CORROELECTRONICO

El layout V3 lo define como TEXTO 2, pero `BRONZE.[LMDA].[FT_REPORTOS]` y `SILVER.[RR].[121_ENT_REPORTOS_MN_ME]` ya lo tienen como `numeric(2,0)`. Se mantiene el tipo numeric para preservar consistencia con la carga existente desde BRONZE. Los valores del catálogo CorroElectronico son códigos numéricos (80, 45, 90, etc.).
