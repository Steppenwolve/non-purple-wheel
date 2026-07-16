# Generador de plantillas de captura validadas

`build_validated_templates.py` genera plantillas Excel de captura a partir de un **layout** (`layout/*.xlsx`)
y sus **catálogos** (`layout/CATALOGOS/*.xlsx|.xls`). Cada plantilla trae dropdowns, ayudas en globo,
tipado por columna y una capa de validación que **atrapa el copy-paste**.

## Uso

```bash
# regenerar todas las plantillas registradas
python build_validated_templates.py

# regenerar solo una(s) por su 'main'
python build_validated_templates.py SWAP OFF_CONVAL
```

El archivo debe estar **cerrado en Excel** (si no, sale `[LOCKED]`).

## Agregar un layout nuevo

1. Analiza el layout: identifica la hoja y qué columna es Nombre / Tipo / Formato(longitud) /
   Catalogo / Descripcion / Comentario.
2. Verifica catálogos con `resolve()` (maneja variantes de nombre: `MONEDA-ISO`→`MonedaISO.xlsx`,
   `CASFIM-V2`→`CASFIM_V2.xlsx`). Avisa si falta alguno **antes** de generar.
3. Agrega un dict a `CFGS` con el mapeo de columnas, `out_dir` (`NNN_ENT_NOMBRE`), `out_name`
   (`PLANTILLA_NOMBRE.xlsx`), `main` (título de la hoja principal) y los formatos de fecha.
4. Corre el script filtrando por el `main` nuevo.

## Qué produce cada plantilla

- **Hoja principal**: columnas en orden del layout; 200 filas con formato por tipo
  (TEXTO→`@`, NUMERICO→`0`/`0.00`, FECHA→formato del cfg).
- **Globos en encabezados**: `Descripcion` + `Comentario` del layout.
- **Dropdowns** en columnas con catálogo (rechazan valor fuera de catálogo).
- **Hojas `CAT_*` ocultas** con los catálogos + named ranges `CL_<safekey>`.
- **Formato condicional** por columna que pinta de rojo si rompe tipo/longitud/catálogo
  (se recalcula al pegar).
- **Hoja `VALIDACION`**: semáforo `✔/✖`, total y desglose (# errores / # vacíos).
- **Hoja `CHK` oculta**: alimenta el reporte.
- `fullCalcOnLoad = True`.

## Gotchas aprendidos (NO romper)

- **Relleno de formato condicional**: usar `PatternFill(start_color, end_color, fill_type="solid")`
  para que se pueble `bgColor`. Con solo `fgColor` **NO pinta** en CF.
- **CASFIM** (`C_CASFIM`, `CASFIM-V2`): zero-padding a 6 dígitos en las claves numéricas.
- **Validación numérica anti-error**: usar `IF(ISNUMBER(x), <checks>, TRUE)` para que texto pegado
  en un campo numérico se marque sin producir `#VALUE!`.
- **`showDropDown` está invertido** en openpyxl: `False` = muestra la flecha; `True` = la oculta.
- **Typos de tipo** (ej. `TETXO`): `norm_tipo()` los normaliza.
- Catálogos `.xls` antiguos se leen con pandas/xlrd sin problema.
- La validación de Excel **NO se dispara al pegar**; por eso la capa de formato condicional es
  el control real dentro del archivo. El gate definitivo es la **ingesta** (processor/SP).

## Plantillas ya generadas

| out_dir | main | catálogos |
|---|---|---|
| 140_ENT_GARANTIAS_II | GARANTIAS_II | 5 |
| 142_ENT_GARANTIAS_IV | GARANTIAS_IV | 4 |
| 133_ENT_OFF_CONVAL | OFF_CONVAL | 4 |
| 121_ENT_REPORTOS_MN_ME | REPORTOS_MN_ME | 21 |
| 021_ENT_SWAPS_CONVO | SWAP_CONVO | 1 |
| 154_ENT_SWAPS | SWAP | 20 |
