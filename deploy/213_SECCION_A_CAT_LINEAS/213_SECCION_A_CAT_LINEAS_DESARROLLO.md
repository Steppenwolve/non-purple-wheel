# Desarrollo: 213_SECCION_A_CAT_LINEAS — LID SA (Sección A: Catálogo de Líneas de Crédito Intradía)

Fuente de referencia: `layout/LAYOUT LID V4 LID SA.xlsx` — hoja `LID SA`

> **Reporte nuevo, desarrollado desde cero.** No existía SP ni tabla en SILVER/ION.
> Sigue el mismo patrón que `212_SECCION_5_LINEAS_CRE` (LID S5).

---

## Datos generales

| Atributo | Valor |
|---|---|
| Número de objeto | `213` |
| Nombre de objeto (SILVER e ION) | `213_SECCION_A_CAT_LINEAS` |
| Nombre del reporte (índice) | `LID SA` |
| **Periodicidad** | **Mensual** |
| Origen de datos | tabla `RR` (patrón **self-select**, igual que los 6 reportes existentes; sin landing BRONZE) |
| Tabla RR SILVER | `SILVER.[RR].[213_SECCION_A_CAT_LINEAS]` |
| SP carga | `SILVER.dbo.[213_SECCION_A_CAT_LINEAS]` |
| SP extracción | `ION.dbo.[213_SECCION_A_CAT_LINEAS]` |
| Relación | Es el **catálogo (Sección A)** que valida el `ID_LINEA` del reporte LID S5 (`212_SECCION_5_LINEAS_CRE`) |

---

## Estructura de columnas (layout → tabla)

| Orden | Col. reporte | Llave | Campo | Tipo layout | Tipo en BD | Catálogo |
|---|---|---|---|---|---|---|
| 1 | 3 | Sí | FECHA_OTORG_L | FECHA AAAA/MM/DD | `date` | |
| 2 | 4 | No | FECHA_MODIF_L | FECHA AAAA/MM/DD | `date` | |
| 3 | 5 | No | FECHA_VENC_L | FECHA AAAA/MM/DD | `date` (def. 2500/12/31) | |
| 4 | 6 | Sí | ID_LINEA | TEXTO 50 | `varchar(50)` | |
| 5 | 7 | Sí | ID_CONTRAPARTE | TEXTO 6 | `varchar(6)` | |
| 6 | 8 | No | TIPO_LINEA | NUMERICO 1,0 | `varchar(1)` | Tipo_Linea |
| 7 | 9 | No | MONEDA_L | TEXTO 3 | `varchar(3)` | Moneda |
| 8 | 10 | No | IND_CAMBIOS_L | NUMERICO 1,0 | `varchar(1)` | Modif_Linea |
| 9 | 11 | No | MONTO_LINEA | NUMERICO 12,0 | `numeric(12,0)` | |
| 10 | 2 | No | FECHA_INFO | FECHA AAAA/MM/DD | `date` | |

Más los campos estándar: `ID uniqueidentifier` (PK, default `newid()`) y `FECHA_EXTRACCION smalldatetime`
(default `getdate()`), que **no se exponen** en el SP de ION.

> Nota: para multimoneda, `MONEDA_L` admite el valor especial `"AAA"` (indicado en el layout).

---

## Decisiones de diseño y supuestos a CONFIRMAR

1. **Catálogos sin transformación**: los valores de catálogo (`TIPO_LINEA`, `MONEDA_L`, `IND_CAMBIOS_L`)
   se almacenan/arrastran **tal cual**, sin zero-pad. (Una versión inicial aplicaba zero-pad heredado
   del objeto 209, que fue descartado; este reporte se realineó al patrón de los 6 reportes existentes.)
2. **Periodicidad mensual ACTIVA**: la ventana `@FechaIni`/`@FechaFin` **se usa** en el WHERE de ambas
   capas (`FECHA_INFO >= inicio_mes AND < inicio_mes_siguiente`).
3. **Patrón de carga (self-select)**: el SP de SILVER hace `INSERT … SELECT` sobre la **misma tabla
   `RR`** filtrando por la ventana mensual, igual que los 6 reportes existentes. **No** hay landing
   BRONZE `[LMDA]` ni transformación de catálogos. (La versión inicial usaba BRONZE/LMDA del 209; se descartó.)
4. **Orden de salida en ION**: se respeta la columna **`ORDEN`** del layout (consideración 13), por lo
   que `FECHA_INFO` (ORDEN 10) va como **última columna**. (Una versión inicial usó `COLUMNA REPORTE
   APLICA`, que la ubicaba en posición 2; se corrigió.) La columna 1 del archivo físico (clave de
   institución) no está en el layout y no se modeló.
5. **Formato de fechas en ION**: salida `AAAAMMDD` (relacionado con el pendiente global `AAAA/MM/DD`
   vs `AAAAMMDD`).
6. **Índice**: registrado en `ION.dbo.INDICE_REPORTES` (numero=213, nombre='SECCION_A_CAT_LINEAS', Mensual,
   activo=0, nombre_archivo=NULL). El número 213 era un hueco en `indices.csv`, por lo que se inserta.
   (El nombre se ajustó de `LID SA` a `SECCION_A_CAT_LINEAS` para seguir la convención del índice, sin prefijo numérico.)

---

## Catálogos — tratamiento (consistente con LID S5)

El layout marca 3 campos con catálogo: `TIPO_LINEA` (Tipo_Linea), `MONEDA_L` (Moneda) e
`IND_CAMBIOS_L` (Modif_Linea). Conforme al análisis empírico documentado en
`212_SECCION_5_LINEAS_CRE_DESARROLLO.md`:

- **Ningún SP del entorno usa catálogos internamente** (0 de 435). El SP solo arrastra la clave;
  la validación contra catálogo vive en otra capa.
- Los catálogos existen en `ION.s3` pero con nomenclatura distinta a los nombres lógicos del layout;
  no hay mapeo 1:1 evidente (p. ej. `Tipo_Linea` → candidato `repo_lakehouse_Catalogo_TipoLinea_V1`).
- Se **conserva** la verificación informativa (sección 02), que reportará "FALTA" por usar nombres
  lógicos. Esto es esperado y **no bloquea** el despliegue.

### Pendiente asociado

- [ ] Definir el mapeo nombre-lógico → tabla física `ION.s3` para los catálogos de LID SA cuando un
  layout/SP futuro requiera validación real contra catálogo.

---

## Scripts generados

| Archivo | Propósito |
|---|---|
| `213_SECCION_A_CAT_LINEAS_CREACION.sql` | Despliegue: verificación de catálogos, tabla RR, SP SILVER (self-select), SP ION, registro en índice. Idempotente. |
| `213_SECCION_A_CAT_LINEAS_ROLLBACK.sql` | Reversa en orden de dependencias: índice → SP ION → SP SILVER → tabla RR. No toca objetos compartidos. |

---

## Notas para producción

- El rollback elimina las tablas y por tanto los datos cargados; no recuperable sin respaldo previo.
- `tbl_Control_Ejecucion`, `INDICE_REPORTES` (como tabla) y `LogSilverDiario` no se eliminan en el
  rollback (solo se borra la fila 213 del índice).
- **Relación con LID S5**: el `ID_LINEA` del reporte 212 (LID S5) debe existir en este catálogo
  (213, LID SA). Si en el futuro se implementa validación cruzada, este es el catálogo de referencia.
- Antes de activar el reporte (`activo = 1`) confirmar los supuestos #3 y #4 con la fuente/área
  regulatoria.

> Aviso de nomenclatura: existe un despliegue previo (carpeta `deploy/213_SECCION_A_CAT_LINEAS/` con
> archivos `LID_CAT_LINEAS_CREACION.sql` / `_ROLLBACK.sql`) que modelaba el MISMO reporte de Sección A
> pero con objetos numerados **209_ENT_LID_CAT_LINEAS** y periodicidad **Diaria**. Esta versión usa el
> número **213**, nombre `SECCION_A_CAT_LINEAS` y periodicidad **Mensual**, conforme a la indicación
> más reciente.
>
> **DECISIÓN (vigente):** el reporte/objeto **209_ENT_LID_CAT_LINEAS se deja TAL CUAL está** — se
> modificará en el futuro. Los scripts `LID_CAT_LINEAS_*.sql` de esta carpeta **no se tocan ni se
> eliminan**. El desarrollo nuevo (213, Mensual) coexiste como entregable independiente; no es una
> conciliación ni un reemplazo del 209 por ahora.
