# Patrón de desarrollo — Reportes "origen LMDA"

Patrón identificado en el DDL vigente (analizados: 010, 016, 024, 025, **027**, 028, 029, 030, 031,
032, 033, **082**, 112, 210, entre otros). En SILVER hay **~35-37 SPs** que siguen este patrón.

> Es el **segundo patrón de carga** del entorno, distinto al **self-select** (ver sección 4 de
> `CONSIDERACIONES_DESARROLLO.md`). Los reportes 080, 081, 083, 132, 155, 156, 212, 213 son
> self-select; los listados al final de este documento son **origen LMDA**.

---

## 1. Definición

Un reporte **origen LMDA** carga su tabla `SILVER.[RR].[NNN_…]` con un
`INSERT … SELECT` que lee desde una **tabla de aterrizaje real en BRONZE**:
`BRONZE.[LMDA].[<tabla_origen>]` (insumo tipo Lambda).

Diferencias frente al **self-select**:

| | self-select | **origen LMDA** |
|---|---|---|
| Fuente del `INSERT … SELECT` | la misma tabla `RR` | **`BRONZE.[LMDA].[<tabla>]`** |
| Ventana temporal | calculada pero a veces muerta | **activa y usada** en el WHERE |
| Transformación de catálogos | ninguna | **zero-pad opcional** en claves numéricas |
| Tabla BRONZE | no existe | **existe** (dependencia real) |

---

## 2. SP de SILVER (carga) — esqueleto

```sql
CREATE OR ALTER PROCEDURE [dbo].[NNN_NOMBRE]
    @CorreoNotificacion NVARCHAR(255) = NULL,
    @PerfilCorreo       NVARCHAR(255) = NULL,
    @ProgramadorJob     NVARCHAR(128) = NULL,
    @FechaSistema       DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @MensajeError NVARCHAR(MAX)='', @ExitoEjecucion BIT=1,
            @FilasInsertadas INT=0, @FilasEliminadas INT=0,
            @LogMessage NVARCHAR(MAX)='', @DetallesLog NVARCHAR(MAX)='',
            @FechaInicio DATETIME=GETDATE(), @NombreJob NVARCHAR(128)='[NNN_NOMBRE]',
            @FechaIni DATE, @FechaFin DATE;

    BEGIN TRY
        -- Ventana segun periodicidad (ver seccion 5 de CONSIDERACIONES_DESARROLLO):
        --   MENSUAL:    SET @FechaIni = datefromparts(year(@FechaSistema), month(@FechaSistema), 1);
        --               SET @FechaFin = dateadd(month, 1, @FechaIni);
        --               filtro -> WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin
        --   TRIMESTRAL: igual pero dateadd(month, 3, ...)
        --   DIARIA:     filtro -> WHERE [FECHA_INFO] = @FechaSistema   (sin ventana de rango)

        -- DELETE idempotente (mismo filtro de ventana)
        IF EXISTS (SELECT 1 FROM [SILVER].[RR].[NNN_NOMBRE] WHERE <filtro>)
        BEGIN
            DELETE FROM [SILVER].[RR].[NNN_NOMBRE] WHERE <filtro>;
            SET @FilasEliminadas = @@ROWCOUNT; ...
        END;

        -- Carga desde el landing BRONZE (con alias). zero-pad SOLO donde el catalogo lo exija.
        INSERT INTO [RR].[NNN_NOMBRE] ( <col1>, ..., [FECHA_INFO] )
        SELECT
             SRC.<col1>,
             ...,
             RIGHT(REPLICATE('0', 6) + CAST(SRC.<COD_CAT> AS VARCHAR(10)), 6) AS <COD_CAT>,  -- zero-pad opcional
             ...,
             SRC.FECHA_INFO
        FROM BRONZE.LMDA.<tabla_origen> SRC
        WHERE SRC.FECHA_INFO <filtro de ventana>;

        SET @FilasInsertadas = @@ROWCOUNT; ...
    END TRY
    BEGIN CATCH
        SET @ExitoEjecucion = 0; SET @MensajeError = ERROR_MESSAGE(); ...
    END CATCH

    -- Alerta por correo SOLO si error y parametros provistos (sp_send_dbmail)
    -- INSERT obligatorio en dbo.LogSilverDiario (Exitoso/Error)
END;
```

> **No** usa `tbl_Control_Ejecucion` (solo `LogSilverDiario`), igual que los reportes existentes.

---

## 3. SP de ION (entrega) — esqueleto

```sql
CREATE OR ALTER PROCEDURE [dbo].[NNN_NOMBRE]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    DECLARE @FechaIni DATE, @FechaFin DATE;
    -- mismo calculo de ventana segun periodicidad (para MENSUAL/TRIMESTRAL)

    SELECT
        <columnas del layout en orden ORDEN>,
        FORMAT([col_fecha], 'yyyy/MM/dd') AS [col_fecha],   -- fechas en AAAA/MM/DD
        FORMAT([FECHA_INFO], 'yyyy/MM/dd') AS [FECHA_INFO]  -- FECHA_INFO al final
    FROM [SILVER].[RR].[NNN_NOMBRE]
    WHERE [FECHA_INFO] <filtro de ventana>;
END;
```

- **Sin** `ID` ni `FECHA_EXTRACCION` en la salida.
- Fechas en **`AAAA/MM/DD`** (consideración 12).
- Orden de columnas por **`ORDEN`** del layout; `FECHA_INFO` al final (consideración 13).

---

## 4. Regla de zero-pad (catálogos numéricos)

Cuando una clave de catálogo es **numérica en el origen** pero el layout la pide como **texto de ancho
fijo de N**, se rellena con ceros a la izquierda en el SELECT de SILVER:

```sql
RIGHT(REPLICATE('0', N) + CAST(<columna> AS VARCHAR(10)), N) AS <columna>
```

Ejemplo real (082): `CONTRAPARTEOPERACION` y `EMISOR` a 6 caracteres. Es **opcional** (027 no lo usa).
Equivale al `RIGHT('0' + CAST(...), 1)` que ya vimos; ambos son válidos.

---

## 5. Convenciones que SÍ aplican (heredadas)

- `ID uniqueidentifier` (PK, `newid()`) + `FECHA_EXTRACCION smalldatetime` (`getdate()`) en la tabla `RR`,
  **no expuestos** en ION.
- Periodicidad → tipo de ventana (DIARIA exacta / MENSUAL / TRIMESTRAL rango).
- Nombre de columna `FECHA_INFO` (con las excepciones 132 y 156 que usan `FECHAINFO`).
- Salida ION en `AAAA/MM/DD`, orden por `ORDEN`, `FECHA_INFO` última.
- Registro en `ION.dbo.INDICE_REPORTES`.

---

## 6. Inventario de reportes origen LMDA (DDL vigente)

| Reporte | Tabla origen BRONZE.LMDA | Zero-pad |
|---|---|---|
| 010_ENT_PERSONA | DATOS_CLIENTE | |
| 016_ENT_ANEXO19 | FLUJOS | |
| 024_ENT_SWAP_CUOTAS_INT | SWAP_CUOTAS_INT | |
| 025_ENT_HIPOTECARIO | INPC_Historico | |
| 027_ENT_INVERSIONES_PERMANENTES | INVERSIONES_PERMANENTES | |
| 028_ENT_CONCILIACIONES | CONCILIACIONES | |
| 029_ENT_FLUJOS | FLUJOS_VARIACIONES | |
| 030_ENT_ELIMINACIONES | ELIMINACIONES | |
| 031_ENT_CONSOLIDACION | CONSOLIDACION | |
| 032_ENT_R10RECLASIFICACIONES | Reclasificaciones | |
| 033_ENT_R07 | IMPUESTOS_DIFERIDOS | |
| 038_ENT_CUOTAS_IPAB_DEF_PROVISIONAL | ENT_CUOTAS_IPAB_DEF | |
| 039_ENT_EVENTOS_ROP | EVENTOS_ROP | |
| 040_ENT_ALTA_Y_SEGUIMIENTO_ROP | ALTA_Y_SEGUIMIENTO_ROP | |
| 041_ENT_CARTERA_RC08A | CARTERA_RC08A | |
| 051_ENT_CONTRAPARTES | CONTRAPARTES | |
| 053_ENT_RC12IN_PI_MIN | RC12IN_PI_MIN | |
| 054_ENT_RC12IN_IN_MIN | RC12IN_IN_MIN | |
| 062_ENT_PARTES_RELACIONADAS | ENT_PARTES_RELACIONADAS | |
| 082_ENT_CVT_MN_ME | CVT_MN_ME | **sí** |
| 106_RECO | RECO | |
| 112_CARGOS DIFERIDOS | CARGOS_DIFERIDOS | |
| 121_ENT_REPORTOS_MN_ME | FT_REPORTOS | |
| 122_ENT_REPORTOS_CANASTA | CANASTA_REPORTOS | |
| 127_ENT_R35_3511_INSUMO | ENT_R35_3511_INSUMO | |
| 131_ENT_OFF | ENT_OFF | |
| 133_ENT_OFF_CONVAL | OFF_CONVAL | |
| 158_R01_PAGOS_ANT | R01_PAGOS_ANT | |
| 196_ENT_XVS | XVS | |
| 200_ENT_SECCION_1 | SECCION_1 | |
| 201_ENT_SECCION_2A | SECCION_2A | |
| 204_ENT_SECCION_2D | SECCION_2D | |
| 205_ENT_SECCION_2E | SECCION_2E | |
| 208_ENT_CUOTAS_IPAB_DEF_FINAL | ENT_CUOTAS_IPAB_DEF | |
| 210_LID_LIQUIDACIONES | LID_LIQUIDACIONES | |

> Total ~35 (la detección puede variar ±2 por formato del `FROM`). Hay 37 SPs que referencian
> `BRONZE.[LMDA]` en total; algunos lo hacen en subconsultas además del `FROM` principal.

---

## 7. Cómo pedir un reporte de este tipo

Para generar un reporte nuevo "origen LMDA" a partir de un layout, indicar:
1. Número y nombre del objeto (`NNN_NOMBRE`).
2. **Tabla origen** en `BRONZE.[LMDA].[<tabla>]` (o pedir que se modele desde el layout si no existe aún).
3. Periodicidad (DIARIA / MENSUAL / TRIMESTRAL).
4. Qué columnas requieren **zero-pad** y a qué ancho (si aplica).

> Nota del usuario: **alguno de estos 37 se va a ajustar con un layout más nuevo** (pendiente de recibir).
