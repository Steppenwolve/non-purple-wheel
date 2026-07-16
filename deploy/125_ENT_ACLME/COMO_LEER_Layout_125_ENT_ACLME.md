# Cómo leer `Layout_125_ENT_ACLME_LMDA_SILVER.xlsx`

Instructivo para que otra sesión de Claude interprete correctamente este archivo.
Es un **layout inverso**: documenta la estructura de las tablas físicas del reporte `125_ENT_ACLME`
(no es una plantilla de captura). Un archivo, **3 hojas**.

## Regla clave: la fila de encabezado NO es la fila 1
| Hoja | Título | Fila de encabezado | Datos desde |
|---|---|---|---|
| `LMDA` | A1 | **fila 3** (`header=2` en pandas) | fila 4 |
| `SILVER` | A1 | **fila 3** (`header=2`) | fila 4 |
| `CAT_TIPO_OPERACION` | A1 + subtítulo A2 | **fila 4** (`header=3`) | fila 5 |

```python
import pandas as pd
f = "Layout_125_ENT_ACLME_LMDA_SILVER.xlsx"
lmda   = pd.read_excel(f, sheet_name="LMDA",   header=2)
silver = pd.read_excel(f, sheet_name="SILVER", header=2)
cat    = pd.read_excel(f, sheet_name="CAT_TIPO_OPERACION", header=3)
```

## Hojas `LMDA` y `SILVER` — layout de campos
Describen respectivamente `BRONZE.LMDA.ACLME` (origen) y `SILVER.RR.125_ENT_ACLME` (salida).
Columnas:

| Columna | Significado |
|---|---|
| `ORDEN` | Consecutivo del campo |
| `NOMBRE_CAMPO` | Nombre físico de la columna |
| `TIPO_DATO` | `TEXTO` / `NUMERICO` / `FECHA` / `FECHA/HORA` / `GUID` |
| `LONGITUD` | Para TEXTO: nº de caracteres; para NUMERICO: `precisión,escala`; para FECHA: `AAAA/MM/DD`; `—` si no aplica |
| `OBLIGATORIO` | `Si` = NOT NULL, `No` = NULL |
| `DESCRIPCION` | Qué representa el campo |
| `COMENTARIO` | Qué dato se genera/espera (origen, constante, fórmula, control) |

### Convenciones a respetar
- En `SILVER`, los campos cuya `DESCRIPCION` empieza con **`[AUX]`** (y están resaltados en amarillo) son **columnas auxiliares de auditoría** (PLAZO, OPERACIONES_A_REPORTAR, POSICION_OPERACION, LLAVE): reflejan el cálculo intermedio, no son parte "natural" del reporte regulatorio (aunque el SP ION también las emite).
- Campos con `COMENTARIO` que dice **"Control"** (ID, FECHA_EXTRACCION) son técnicos, no de negocio.
- El `COMENTARIO` indica la **regla de derivación**: `"Igual a MONTO del insumo"`, `"Constante igual a 1"`, `"Se obtiene por JOIN a BRONZE.RR.CATALOGO_TIPO_OPERACION_ACLME por LLAVE"`, etc. Ahí está el mapeo LMDA→SILVER.

## Hoja `CAT_TIPO_OPERACION` — catálogo
Representa la **tabla física** `BRONZE.RR.CATALOGO_TIPO_OPERACION_ACLME`.
Columnas: `CLAVE` (PK), `DESCRIPCION`, `LLAVE`, `POSICION` (C/V), `TIPO_INSUMO`.
- La `LLAVE` (CFX/CFW/VFX/VFW) es la clave de búsqueda; el SP hace `JOIN` LMDA→catálogo por `LLAVE` para traer `CLAVE`.
- Filas con `LLAVE` vacía (3050, 3636, 6542, 7635, 7790) existen en el catálogo pero la lógica vigente **no** las produce (SW se trata como spot).

## Relación con el resto de la carpeta
- La **lógica de transformación** (plazo, posición, LLAVE, constantes) vive en `125_ENT_ACLME_AJUSTE.sql` (SP SILVER); este Excel solo la **documenta** vía la columna `COMENTARIO`.
- Datos de prueba y pipeline: `125_ENT_ACLME_INSERT_DUMMY.sql`. Detalle de decisiones: `125_ENT_ACLME_HALLAZGOS.md`.

## Qué NO asumir
- No es una plantilla de captura: no tiene dropdowns ni validación; no la trates como los `PLANTILLA_*.xlsx`.
- El orden de columnas en la hoja `SILVER` es **lógico** (auxiliares agrupadas), puede no coincidir con el orden físico (`ORDINAL_POSITION`) de la tabla en la BD.
