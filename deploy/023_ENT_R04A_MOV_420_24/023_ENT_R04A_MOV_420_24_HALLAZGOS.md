# Hallazgos — 023_ENT_R04A_MOV_420_24 (R04A Movimientos 420/424, IFRS9)

- **Insumo:** `Simulado_Desagregado_v2.xlsx` (hoja `Fuente_datos`, 1,420 filas) · Layout de salida: `Credito_IFRS9_R04A_MOV_420_24.xlsx`
- **Origen:** `BRONZE.LMDA.R04A_MOV_420_24` (insumo **desagregado** por E1/E2/E3) → **Destino:** `SILVER.RR.023_ENT_R04A_MOV_420_24` → **Salida:** SP `ION.dbo.023_ENT_R04A_MOV_420_24`
- **Frecuencia:** Mensual (ventana por `FECHA_INFO`)

## Cambio de lógica
Se **sustituyó** el origen LMDA por una estructura **desagregada** (columnas `E1/E2/E3` = importe por etapa de deterioro), y la salida se **agrega/despivota** a una fila por etapa.

### Transformación (DESPIVOTE)
Por cada fila de BRONZE, por cada etapa con importe **> 0**, se genera una fila en SILVER (`CROSS APPLY (VALUES (1,E1),(2,E2),(3,E3))`):

| Campo SILVER | Regla |
|---|---|
| `CUENTA_CREDITO` | copia directa; **NULL → `0`**; **sin** zero-padding |
| `ETAPA_DETERIORO` | **1 = E1, 2 = E2, 3 = E3** |
| `TIPO_MOV_420_424` | copia (numérico); **zero-padding a 2 se hace en el SP ION** |
| `IMPORTE` | el valor de `E1` / `E2` / `E3` |
| `MONEDA` | constante **`'MXN'`** |
| `FECHA_INFO` | copia directa |

- **Sin filtro** por `CONCEPTO/TIPO/ESTATUS/TIPO_CARTERA/RESTRINGIDO` → esas columnas **quedan en BRONZE como histórico auditable** (no se cargan a SILVER).

## Estado inicial (defectos corregidos)
- `SILVER.dbo.023_ENT_R04A_MOV_420_24` era un **stub con self-select** (`INSERT INTO RR.023 … SELECT … FROM SILVER.RR.023`) y filtro mensual. Se reescribió para leer del nuevo origen BRONZE y despivotar.
- `SILVER.RR.023_ENT_R04A_MOV_420_24`: `IMPORTE` y `MONEDA` estaban **NULL** pero el layout los marca obligatorios → pasados a **NOT NULL**; `TIPO_MOV_420_424` era `numeric(16,2)` → alineado a **numeric(2,0)** (el layout tenía un error de dedo: la longitud real es 2).

## Decisiones acordadas
1. `MONEDA` = valor fijo **`'MXN'`** (el insumo no trae moneda).
2. `CUENTA_CREDITO` **sin** zero-padding; **NULL → 0**.
3. `ETAPA_DETERIORO` derivada de la columna E (1/2/3).
4. `TIPO_MOV_420_424`: **numérico en SILVER**, **zero-padding a 2** en el SP ION (patrón como el 154).
5. Layout: longitud de `TIPO_MOV_420_424` corregida a **2** (era typo 16,2).
6. `FECHA_INFO` en el SP ION: **`AAAA/MM/DD`** (10 caracteres).
7. Sin filtro de negocio; columnas descriptivas como histórico en BRONZE.
8. `CONCEPTO`/`TIPO_CARTERA` en BRONZE ampliadas a `varchar(96)` (el insumo excede 50: 72 y 59).

## Prueba (OK)
- BRONZE: **1,420 filas** cargadas (25 con `CUENTA_CREDITO` NULL).
- `EXEC` SP SILVER `@FechaSistema='2026-06-30'` → **60 filas** (etapas con E>0). Distribución: etapa 1 = 18, etapa 2 = 18, etapa 3 = 24. Conteo validado contra el conteo independiente de E>0 en BRONZE.
- `EXEC` SP ION → 6 columnas del layout; `TIPO_MOV_420_424` zero-padded a 2 (`08`, `02`…); `FECHA_INFO='2026/06/30'` (10 chars); `MONEDA='MXN'`.
- `INDICE_REPORTES` → `23 / ENT_R04A_MOV_420_24 / Mensual / activo`.

## Entregables (`deploy\023_ENT_R04A_MOV_420_24\`)
- `023_R04A_MOV_420_24_LMDA_SUSTITUIR.sql` — DROP+CREATE de la tabla LMDA (estructura desagregada).
- `023_R04A_MOV_420_24_INSERT_DUMMY.sql` — 1,420 filas del insumo (2 lotes de VALUES).
- `023_ENT_R04A_MOV_420_24_SILVER_AJUSTE.sql` — IMPORTE/MONEDA → NOT NULL (Opción A).
- `023_ENT_R04A_MOV_420_24_AJUSTE.sql` — S01 alinea TIPO_MOV, S02 SP SILVER (despivote), S03 SP ION (zero-pad + fecha), S04 INDICE.
- `023_ENT_R04A_MOV_420_24_ROLLBACK.sql` — restaura SPs originales, revierte columnas SILVER, elimina INDICE 23 y dropea la tabla LMDA.
- `023_ENT_R04A_MOV_420_24_HALLAZGOS.md` — este documento.

## Notas
- La tabla SILVER conserva su orden físico (IMPORTE/MONEDA al final por ALTERs previos); si se requiere el orden exacto del layout habría que recrearla.
- La estructura BRONZE (desagregada) y la SILVER (agregada por etapa) son **intencionalmente distintas**.
