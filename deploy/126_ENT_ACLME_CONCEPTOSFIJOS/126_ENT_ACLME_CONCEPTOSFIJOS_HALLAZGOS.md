# Hallazgos — 126_ENT_ACLME_CONCEPTOSFIJOS (ACLME Conceptos Fijos)

- **Insumo:** `Layout_ACLME_ConceptosFijos_v3/v4` (hojas `Layout`, `ConceptosFijos`, `Relas de negocio`)
- **Origen:** `BRONZE.LMDA.ACLME` (mismo insumo que 125; otra presentación) → **Destino:** `SILVER.RR.126_ENT_ACLME_CONCEPTOSFIJOS` → **Salida:** SP `ION.dbo.126_ENT_ACLME_CONCEPTOSFIJOS`
- **Frecuencia:** Diaria

## Qué hace
Agrega el insumo ACLME por **CONCEPTO**: asigna concepto por `(MONEDA, TIPO_OPERACION)` y **suma `MONTO`**.

### Mapeo de concepto (reglas de negocio → catálogo)
| MONEDA | TIPO_OPERACION | CONCEPTO | Descripción |
|---|---|---|---|
| USD | SW o FX | 9725 | Compras de Spots |
| MXN | FX | 9730 | Ventas de Spots |
| USD | FW | 9890 | Compras de Forwards |
| MXN | FW | 9900 | Venta de Forwards |

**Swaps (decisión del usuario: tal cual las reglas):** SW+USD → 9725 (compra spots); SW+MXN → **no mapea, se descarta**. Los conceptos 9895/9910 (swaps) nunca se producen.

## Estado inicial (objetos existían en la DDL restaurada)
- `SILVER.RR.126_ENT_ACLME_CONCEPTOSFIJOS` existía con `CONCEPTO, IMPORTE numeric(15,8), MONEDA, RESERVAS numeric(15,8), FECHA_INFO` — **sin INSTITUCION ni auxiliares**.
- SP SILVER = stub (mensual + self-select); SP ION = passthrough. INDICE sin fila 126.

## Decisiones acordadas
1. **Auxiliares en SILVER** por fila-concepto: `DESCRIPCION` y `MOVIMIENTOS` (conteo).
2. **NO agrupar por INSTITUCION** — se emite como valor único (`MAX(INSTITUCION)`); GROUP BY solo por CONCEPTO.
3. Catálogo en **`BRONZE.RR.CATALOGO_CONCEPTOS_PLAZO_FIJO_ACLME`** (mapeo `MONEDA,TIPO_OPERACION → CONCEPTO`, PK compuesta), con JOIN en el SP (no hardcodeo).
4. **Swaps tal cual las reglas** (ver arriba).
- **RESERVAS**: fija; se guarda `0` en SILVER y el SP ION emite `'N/A'` (regla de negocio "Valor fijo N/A"). El texto del layout sobre conceptos 3460/3470 **no aplica** a los conceptos de este reporte.
- **INSTITUCION**: campo del layout (posición 2) que fluye desde LMDA; en ION se emite TEXTO(6) con zero-padding.
- **Sin filtro de plazo** (a diferencia del 125): se agrega todo el lote del día (Opción A por `FECHA_EXTRACCION`).
- **IMPORTE `numeric(15,8)`** (como en prod): los montos de prueba usan los del archivo ConceptosFijos (pequeños) para no hacer overflow.

## Salida SP ION (6 columnas del layout)
`CONCEPTO, INSTITUCION, IMPORTE, MONEDA, RESERVAS, FECHA_INFO`. Los auxiliares (DESCRIPCION, MOVIMIENTOS) quedan **solo en SILVER**.

## Prueba (OK — coincide con el Excel)
Con `@FechaSistema='2025-06-12'` y las 11 filas del insumo:
| CONCEPTO | Descripción | Mov | IMPORTE |
|---|---|---|---|
| 9725 | Compras de Spots | 2 | 6000 |
| 9730 | Ventas de Spots | 2 | 26500 |
| 9890 | Compras de Forwards | 5 | 37000 |
| 9900 | Venta de Forwards | 1 | 15000 |

ION: 6 columnas, `INSTITUCION='040138'`, `RESERVAS='N/A'`, fechas `yyyy/MM/dd`. INDICE 126 registrado.

## Entregables
- `126_..._AJUSTE.sql` — S00 BRONZE, S01 SILVER (+INSTITUCION/auxiliares), S01C catálogo, S02 SP SILVER (agregación + JOIN), S03 SP ION, S04 INDICE.
- `126_..._ROLLBACK.sql` — restaura SP stub/passthrough, elimina INDICE, dropea catálogo y columnas agregadas. No toca BRONZE.
- `126_..._INSERT_DUMMY.sql` — 11 filas (montos ConceptosFijos) + INSTITUCION.
- `126_..._HALLAZGOS.md` — este documento.

## Nota
El `INSERT_DUMMY` de este reporte carga BRONZE con montos pequeños (los del archivo ConceptosFijos) para respetar `IMPORTE numeric(15,8)`. Difiere del dummy del 125 (montos grandes); ambos comparten la misma tabla `BRONZE.LMDA.ACLME`, así que el último cargado define los datos.
