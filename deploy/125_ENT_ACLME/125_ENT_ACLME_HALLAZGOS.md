# Hallazgos — 125_ENT_ACLME (ACLME Sección I-V)

- **Insumo/layout:** `Layout_ACLME_SECCION_I_V_v3 -- ACLME.xlsx` (hojas `ORIGEN y SALIDA`, `Layout I_V`, `REGLAS_NEGOCIO`)
- **Origen:** `BRONZE.LMDA.ACLME` → **Destino:** `SILVER.RR.125_ENT_ACLME` → **Salida:** SP `ION.dbo.125_ENT_ACLME`
- **Frecuencia:** Diaria

## Estado inicial (objetos ya existían en la DDL restaurada de prod)
- `BRONZE.LMDA.ACLME` ✅ estructura correcta (coincide con la hoja ORIGEN).
- `SILVER.RR.125_ENT_ACLME` ✅ estructura correcta (8 columnas de salida).
- `SILVER.dbo.125_ENT_ACLME` ❌ **era un stub defectuoso**:
  - **self-select**: `INSERT INTO RR.125 … SELECT … FROM SILVER.RR.125` (leía de sí mismo, no de BRONZE).
  - **filtro mensual** (`datefromparts month`) siendo el reporte **Diario**.
  - **sin transformación** (no calculaba plazo/posición/llave/clave ni constantes).
- `ION.dbo.125_ENT_ACLME` ⚠️ passthrough (incluía `ID`/`FECHA_EXTRACCION`, `RESERVAS` numérico, sin formato de fecha).
- `INDICE_REPORTES` **sin** la fila 125.
- Catálogo `ION.s3.…OPERACIONES_ACLME` **vacío** y sin mapa Llave→Clave → se resolvió con `CASE` en el SP.

## Lógica implementada (fórmulas del Excel → SP SILVER)
| Concepto | Regla / fórmula | Implementación |
|---|---|---|
| PLAZO | `FECHA_INICIO - FechaReporte` (regla 1) | `DATEDIFF(DAY, @FechaSistema, FECHA_INICIO) > 0` |
| Posición | USD→Compra(C), MXN→Venta(V) (regla 2) | `CASE MONEDA` |
| LLAVE | posición + tipo, con **SW→FX** (reglas 3-4, intencional) | concatenación `CASE` |
| Clave | VLOOKUP catálogo | `CASE LLAVE`: CFX→3515, CFW→3561, VFX→6415, VFW→6477 |
| AMORTIZACION | constante | `1` |
| IMPORTE_AMORTIZACION | = MONTO | `MONTO` |
| FECHA_AMORTIZACION | = FECHA_VMTO | `FECHA_VMTO` |
| NUMERO_IDENTIFICACION | = ID_SISTEMA | `ID_SISTEMA` |
| MONEDA | constante | `'USD'` |
| RESERVAS | Excel `'N/A'` (texto) | **SILVER guarda `0`** (columna numérica) y **ION emite `'N/A'`** |
| FECHA_INFO | = FechaReporte | `@FechaSistema` |

## Decisiones acordadas con el usuario
1. La transformación va en el **SP SILVER** (BRONZE→SILVER); ION solo formatea.
2. Se sigue la **fórmula** para el plazo (`FECHA_INICIO - FechaReporte`), **no** "días por vencer"; documentado en el SP.
3. **SW→FX (spot)** es intencional; por eso los claves de swaps (3636/6542) nunca se producen.
4. Alcance de entrada **Opción A**: lote del día por `FECHA_EXTRACCION = @FechaSistema` (BRONZE no tiene `FECHA_INFO`). Idempotente porque el SP borra la salida de `FECHA_INFO=@FechaSistema` antes de insertar.
5. `RESERVAS`: `0` en SILVER, `'N/A'` en ION.
6. Fechas como `DATE`; salida ION en `yyyy/MM/dd`.

## Prueba (OK)
- Cargadas **11 filas** de ejemplo en `BRONZE.LMDA.ACLME` (`FECHA_EXTRACCION` = 2025-06-12).
- `EXEC` SP SILVER `@FechaSistema='2025-06-12'` → **10 filas** (la operación `FX2516369350` con `FECHA_INICIO = FechaReporte` se excluye por plazo 0).
- **Validación celda a celda vs. Excel:** las 10 claves (columna W) coinciden al 100%.
- `EXEC` SP ION → 8 columnas, `RESERVAS='N/A'`, fechas `yyyy/MM/dd`, `FECHA_INFO=2025/06/12`.
- `INDICE_REPORTES` → 125 / ENT_ACLME / Diaria / activo.

## Catálogo externalizado (sin hardcodeo)
La equivalencia `LLAVE → CLAVE` (antes un `CASE` en el SP) se movió a una **tabla catálogo**:
`BRONZE.RR.CATALOGO_TIPO_OPERACION_ACLME` (`CLAVE` PK, `DESCRIPCION`, `LLAVE`, `POSICION`, `TIPO_INSUMO`), con las 9 claves del Excel e índice único filtrado en `LLAVE`. Se puebla con `MERGE` (idempotente).

- El SP SILVER ahora obtiene la clave con `INNER JOIN … CATALOGO … ON cat.LLAVE = b.LLAVE` (el JOIN también descarta llaves sin equivalencia, sustituyendo al `WHERE LLAVE IN (...)`).
- La **lógica de negocio** (posición, SW→FX, plazo) permanece en el SP; solo la **tabla de equivalencias** salió a catálogo.
- **Ventaja:** cambiar/añadir claves (p. ej. habilitar swaps 3636/6542) es un `UPDATE`/`INSERT` en el catálogo, **sin redesplegar el SP**.
- Convención: se ubica en `BRONZE.RR` junto a otros catálogos del entorno (p. ej. `RR.Catalogo_Cuenta_R04A_V1`).

## Entregables
- `125_ENT_ACLME_AJUSTE.sql` — S00 BRONZE, S01 SILVER, **S01C catálogo BRONZE.RR**, S02 SP SILVER (transformación + JOIN), S03 SP ION, S04 INDICE.
- `125_ENT_ACLME_ROLLBACK.sql` — restaura SP SILVER (stub) y SP ION (passthrough) originales, elimina INDICE 125 y **dropea el catálogo**. No toca las tablas de datos ni sus filas.
- `125_ENT_ACLME_INSERT_DUMMY.sql` — 11 filas de insumo parametrizadas por `@FechaReporte`.
- `Layout_125_ENT_ACLME_LMDA_SILVER.xlsx` — layouts inversos (LMDA, SILVER, catálogo).
- `125_ENT_ACLME_HALLAZGOS.md` — este documento.

## Columnas de auditoría en SILVER (agregado posterior)
A petición de negocio, para **trazabilidad** se agregaron a `SILVER.RR.125_ENT_ACLME` las 4 columnas intermedias del cálculo (las que en el Excel son S–V), pobladas por el SP:

| Columna | Origen | Ejemplo |
|---|---|---|
| `PLAZO` | `FECHA_INICIO - FechaReporte` | 1, 33, 42… |
| `OPERACIONES_A_REPORTAR` | tipo original (SW/FX/FW) | SW / FX / FW |
| `POSICION_OPERACION` | C/V | C / V |
| `LLAVE` | llave del VLOOKUP | CFX / CFW / VFX / VFW |

Son **NULLABLE**. El `AJUSTE.sql` las crea en tablas nuevas y las agrega con `ALTER … IF COL_LENGTH IS NULL` en tablas preexistentes (idempotente). El `ROLLBACK.sql` restaura el comportamiento de los SP; las columnas de auditoría quedan (nullable, inofensivas).

**Salida del SP ION:** por requerimiento, el SP ION también **emite estas 4 columnas auxiliares** además de las del reporte, en el orden del Excel:
`PLAZO, OPERACIONES_A_REPORTAR, POSICION_OPERACION, LLAVE, TIPO_OPERACION, AMORTIZACION, IMPORTE_AMORTIZACION, FECHA_AMORTIZACION, NUMERO_IDENTIFICACION, MONEDA, RESERVAS, FECHA_INFO` (12 columnas).

## Campo INSTITUCION y nuevo layout de salida ION (hoja SALIDA_ION)
Por requerimiento se documentó la salida del SP ION en la hoja `SALIDA_ION` del Excel (9 columnas) y se ajustó:
- **Nuevo campo `INSTITUCION` `numeric(6,0)`** agregado a `BRONZE.LMDA.ACLME` y `SILVER.RR.125_ENT_ACLME` (idempotente vía `ALTER … IF COL_LENGTH IS NULL`, `DEFAULT 0`). El SP SILVER lo **arrastra** desde LMDA. En prod (limpio) se crea de origen en el `CREATE TABLE`.
- **SP ION reescrito** a las 9 columnas del layout, en orden: `TIPO_OPERACION, INSTITUCION, AMORTIZACION, IMPORTE_AMORTIZACION, FECHA_AMORTIZACION, NUMERO_IDENTIFICACION, MONEDA, RESERVAS, FECHA_INFO`.
  - `INSTITUCION` se emite como TEXTO(6) con **zero-padding** (`FORMAT(...,'000000')`, p. ej. `040138`).
  - Las 4 columnas auxiliares (PLAZO, OPERACIONES_A_REPORTAR, POSICION_OPERACION, LLAVE) **siguen en SILVER** (auditoría) pero **ya no se emiten** en el reporte.
  - `RESERVAS`: se mantiene `0` en LMDA/SILVER y el SP ION lo presenta como `'N/A'`.
- `INSERT_DUMMY` agrega la columna con un placeholder `@Institucion = 40138` (ajustable por cliente).
- **Prueba:** ION emite 9 columnas; `INSTITUCION='040138'`, `RESERVAS='N/A'`, 10 filas.

**Nota:** en prod aún no se ha aplicado ningún cambio; el `AJUSTE.sql` sirve como despliegue completo (incluye INSTITUCION en los `CREATE` y en los `ALTER` idempotentes).

## Nota
Los datos de prueba se **dejan en `BRONZE.LMDA.ACLME`** (11 filas) y en `SILVER.RR.125_ENT_ACLME` (10 filas) para inspección.
