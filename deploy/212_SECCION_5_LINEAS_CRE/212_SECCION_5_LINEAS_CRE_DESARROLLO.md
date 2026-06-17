# Desarrollo: 212_SECCION_5_LINEAS_CRE — LID S5 (Sección 5: Uso de Líneas de Crédito Intradía)

Fuente de referencia: `layout/LAYOUT LID V4 LID S5.xlsx` — hoja `LID S5`

> **Reporte nuevo, desarrollado desde cero.** No existía SP ni tabla en SILVER/ION.
> Se sigue el patrón del despliegue `213_SECCION_A_CAT_LINEAS` (objetos 209), adaptando la periodicidad.

---

## Datos generales

| Atributo | Valor |
|---|---|
| Número de objeto | `212` |
| Nombre de objeto (SILVER e ION) | `212_SECCION_5_LINEAS_CRE` |
| Nombre del reporte (índice) | `LID S5` |
| **Periodicidad** | **Mensual** |
| Origen de datos | tabla `RR` (patrón **self-select**, igual que los 6 reportes existentes; sin landing BRONZE) |
| Tabla RR SILVER | `SILVER.[RR].[212_SECCION_5_LINEAS_CRE]` |
| SP carga | `SILVER.dbo.[212_SECCION_5_LINEAS_CRE]` |
| SP extracción | `ION.dbo.[212_SECCION_5_LINEAS_CRE]` |

---

## Estructura de columnas (layout → tabla)

| Orden | Col. reporte | Campo | Tipo layout | Tipo en BD | Catálogo | Obligatorio |
|---|---|---|---|---|---|---|
| 1 | 3 | FECHA_EJE | FECHA AAAA/MM/DD | `date` | | Sí |
| 2 | 4 | HORA_USO | TEXTO 5 | `varchar(5)` | | Sí |
| 3 | 5 | ID_LINEA (llave) | TEXTO 50 | `varchar(50)` | → Sección A | Sí |
| 4 | 6 | FECHA_LIQ_L | FECHA AAAA/MM/DD | `date` | (def. 2500/12/31) | Sí |
| 5 | 7 | HORA_LIQ_L | TEXTO 5 | `varchar(5) NULL` | | No |
| 6 | 8 | MONTO_EJ_L | NUMERICO 12,0 | `numeric(12,0)` | | Sí |
| 7 | 9 | MONEDA_EJ_L | TEXTO 3 | `varchar(3)` | Moneda | Sí |
| 8 | 10 | CAR_LINEA | NUMERICO 1,0 | `varchar(1)` | Carcteristica_Linea | Sí |
| 9 | 11 | PORC_CUBIERTO | NUMERICO 0,2 | `numeric(5,2)` ⚠️ | | Sí |
| 10 | 12 | TIPO_GAR | TEXTO 2 | `varchar(2)` | Tipo_Gar | Sí |
| 11 | 13 | MONTO_PENALIZA | NUMERICO 12,0 | `numeric(12,0)` | | Sí |
| 12 | 14 | MOTIVO_REST | NUMERICO 2,0 | `varchar(2)` | Motivo_Ret | Sí |
| 13 | 2 | FECHA_INFO | FECHA AAAA/MM/DD | `date` | | Sí |

Más los campos estándar de toda tabla RR: `ID uniqueidentifier` (PK, default `newid()`) y `FECHA_EXTRACCION smalldatetime` (default `getdate()`), que **no se exponen** en el SP de ION.

---

## Decisiones de diseño y supuestos a CONFIRMAR

1. ⚠️ **PORC_CUBIERTO**: el layout indica formato `NUMERICO 0,2`, notación ambigua (no es una precisión/escala válida directa). Se interpretó como `numeric(5,2)` (porcentaje con 2 decimales). **Confirmar** si debe ser una fracción 0–1 (`numeric(3,2)`) o porcentaje 0–100.
2. **Catálogos sin transformación**: los valores de catálogo (`MONEDA_EJ_L`, `CAR_LINEA`, `TIPO_GAR`, `MOTIVO_REST`) se almacenan/arrastran **tal cual**, sin zero-pad. (Una versión inicial aplicaba zero-pad heredado del objeto 209, que fue descartado; este reporte se realineó al patrón de los 6 reportes existentes.)
3. **Periodicidad mensual ACTIVA**: a diferencia de los reportes diarios revisados (080/081/083/132/155/156), aquí la ventana mensual `@FechaIni`/`@FechaFin` **se usa** en el WHERE de ambas capas:
   - `@FechaIni = DATEFROMPARTS(year, month, 1)`
   - `@FechaFin = DATEADD(MONTH, 1, @FechaIni)`
   - `WHERE FECHA_INFO >= @FechaIni AND FECHA_INFO < @FechaFin`
4. **Patrón de carga (self-select)**: el SP de SILVER hace `INSERT … SELECT` sobre la **misma tabla `RR`** filtrando por la ventana mensual, igual que los 6 reportes existentes. **No** hay landing BRONZE `[LMDA]` ni transformación de catálogos. (La versión inicial usaba BRONZE/LMDA heredado del 209; se descartó.)
5. **Orden de salida en ION**: se respeta la columna **`ORDEN`** del layout (consideración 13), por lo que `FECHA_INFO` (ORDEN 13) va como **última columna**. (Una versión inicial usó `COLUMNA REPORTE APLICA`, que la ubicaba en posición 2; se corrigió.) La columna 1 del archivo físico (típicamente clave de institución en reportes CNBV) no está en el layout y no se modeló.
6. **Formato de fechas en ION**: salida `AAAAMMDD` vía `FORMAT(..., 'yyyyMMdd')` para FECHA_INFO, FECHA_EJE y FECHA_LIQ_L (relacionado con el pendiente global sobre `AAAA/MM/DD` vs `AAAAMMDD`).
7. **Índice**: registrado en `ION.dbo.INDICE_REPORTES` (numero=212, nombre='SECCION_5_LINEAS_CRE', frecuencia='Mensual', activo=0, nombre_archivo=NULL), consistente con la carga de `indices.csv`. El número 212 no estaba presente en el CSV (hueco), por lo que se inserta. (El nombre se ajustó de `LID S5` a `SECCION_5_LINEAS_CRE` para seguir la convención del índice, sin prefijo numérico.)

---

## Catálogos — análisis empírico (IMPORTANTE)

El layout marca 4 campos con catálogo: `MONEDA_EJ_L` (Moneda), `CAR_LINEA` (Carcteristica_Linea),
`TIPO_GAR` (Tipo_Gar) y `MOTIVO_REST` (Motivo_Ret). Se investigó contra la BD real para tener
**certeza** de si el desarrollo debe contemplarlos:

### Hallazgos verificados contra la base de datos

1. **Ningún SP usa catálogos internamente.** 0 de 435 SPs (215 en SILVER + 220 en ION) referencian
   `s3`, `repo_lakehouse_Catalogo` ni hacen JOIN a catálogos. El SP hermano más cercano
   `210_LID_LIQUIDACIONES` (LID, diario) tampoco. → El patrón real es que el SP **solo arrastra la
   clave**; no la traduce ni la valida contra el catálogo (validación en otra capa: Lambda / calidad
   de datos / motor de validación externo).

2. **Los catálogos sí existen** en `ION.s3` (367 tablas tipo `repo_lakehouse_Catalogo_*`), pero con
   **nomenclatura distinta** a los nombres lógicos del layout. No hay mapeo 1:1 evidente:

   | Catálogo (layout) | Candidatos en `ION.s3` (nombre similar) | Mapeo claro |
   |---|---|---|
   | Moneda | `..._ADICIONALES_CFEN_MONEDA`, `..._MonedaISO_ACLME`, `..._Moneda_ISO_GAMMA_VEGA` (16 variantes) | ❌ ambiguo |
   | Carcteristica_Linea | `..._Opertativos_Caracteristicas_*`, `..._TipoLinea_V1` | ❌ ambiguo |
   | Tipo_Gar | múltiples `*_GARANTIAS`, ninguno específico de líneas de crédito | ❌ no encontrado claro |
   | Motivo_Ret | `..._Motivo_Reclamacion_R27` / `_R2711` (reclamación, no restitución) | ❌ no corresponde |

   > Nota: el nombre del layout `Carcteristica_Linea` viene con la errata original (sin la primera `a`).

### Conclusión

**El desarrollo del SP 212 NO requiere los catálogos para funcionar** — la prueba de extremo a extremo
lo confirmó. La columna "Catálogo" del layout es una **regla de validación de datos**, no una
dependencia de ejecución del SP.

### Decisión tomada

Se **conserva** la verificación informativa (sección 02 del script de creación) de forma intencional.
Más adelante se trabajarán otros layouts y SPs que **pueden mantener una lógica distinta** (p. ej.
reportes que sí hagan lookup contra catálogo); cuando aparezca ese caso se revisará el mapeo a los
nombres físicos reales de `ION.s3`. Por ahora la sección 02:

- Es **solo informativa** (PRINT/SELECT); no crea, no llena, no bloquea el despliegue.
- Usa nombres lógicos (`repo_lakehouse_Catalogo_Moneda`, etc.) que **no existen tal cual** en la BD,
  por lo que reportará "FALTA". Esto es esperado y no indica un problema del despliegue.

### Pendiente asociado

- [ ] Cuando un layout/SP futuro requiera **validación real contra catálogo**, definir el mapeo
  nombre-lógico → tabla física `ION.s3` para los 4 catálogos de LID S5 (el usuario puede proporcionar
  los catálogos correctos). Hasta entonces, los valores se arrastran sin validar en el SP.

---

## Scripts generados

| Archivo | Propósito |
|---|---|
| `212_SECCION_5_LINEAS_CRE_CREACION.sql` | Despliegue: verificación de catálogos, tabla RR, SP SILVER (self-select), SP ION, registro en índice. Idempotente. |
| `212_SECCION_5_LINEAS_CRE_ROLLBACK.sql` | Reversa en orden de dependencias: índice → SP ION → SP SILVER → tabla RR. No toca objetos compartidos. |

---

## Notas para producción

- El rollback elimina las tablas y por tanto los datos cargados; no recuperable sin respaldo previo.
- `tbl_Control_Ejecucion`, `INDICE_REPORTES` (como tabla) y `LogSilverDiario` no se eliminan en el rollback (solo se borra la fila 212 del índice).
- Validar la **REGLA DE ORO** (sin referencias a objetos `impera`/`imperahub`) que el preflight verifica automáticamente.
- Antes de activar el reporte (`activo = 1`) confirmar los supuestos #1, #4 y #5 con el área regulatoria/fuente.
