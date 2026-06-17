# Consideraciones de Desarrollo — Entorno ION/Impera

Documento de referencia acumulado durante el análisis y desarrollo de reportes
(análisis: 005, 006, 007, 093, 119; corrección/desarrollo: 080, 081, 083, 132, 155, 156, 212, 213).
Actualizar conforme se confirmen o agreguen reglas.

---

## 1. Arquitectura medallón

| Capa | Base de datos | Rol |
|------|--------------|-----|
| BRONZE | `BRONZE` | Landing — tablas fuente tal como llegan |
| SILVER | `SILVER` | Transformación/ETL — tablas `RR.*` + SPs de carga |
| ION | `ION` | Entrega regulatoria — SPs de consulta (solo SELECT) |

---

## 2. Estructura de tablas `SILVER.[RR].*`

Toda tabla de reporte en el esquema `RR` de SILVER debe incluir:

| Campo | Tipo | Constraint | Default |
|-------|------|-----------|---------|
| `ID` | `uniqueidentifier` | PK NOT NULL | `newid()` |
| `FECHA_EXTRACCION` | `smalldatetime` | NOT NULL | `getdate()` |
| *(columnas del layout)* | según layout | según layout | — |

> Estos campos son **internos/auditoría** y **no deben exponerse** en el SP de ION.

---

## 3. Convención de nombres de objetos

```
NNN_NOMBRE_REPORTE
```

- `NNN` = número de reporte con ceros a la izquierda (ej. `080`, `213`)
- Aplica a: tabla SILVER `[RR].[NNN_NOMBRE]`, SP SILVER `dbo.[NNN_NOMBRE]`, SP ION `dbo.[NNN_NOMBRE]`
- Nombres que inician con dígito requieren corchetes en todas las referencias SQL

---

## 4. Patrón de SP SILVER (ETL)

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

    -- Variables estándar
    DECLARE @MensajeError    NVARCHAR(MAX) = '';
    DECLARE @ExitoEjecucion  BIT           = 1;
    DECLARE @FilasInsertadas INT           = 0;
    DECLARE @FilasEliminadas INT           = 0;
    DECLARE @LogMessage      NVARCHAR(MAX) = '';
    DECLARE @DetallesLog     NVARCHAR(MAX) = '';
    DECLARE @FechaInicio     DATETIME      = GETDATE();
    DECLARE @NombreJob       NVARCHAR(128) = '[NNN_NOMBRE]';

    -- Variables de ventana (ver sección 5)

    BEGIN TRY
        -- 1. Cálculo de ventana temporal
        -- 2. DELETE idempotente
        -- 3. INSERT ... SELECT sobre la misma tabla RR (patrón self-select de los reportes existentes)
        --    NOTA: NO se asume landing BRONZE ni transformación de catálogos (zero-pad).
        --    El objeto 209 (que sí usaba BRONZE/zero-pad) NO es referencia válida.
    END TRY
    BEGIN CATCH
        SET @ExitoEjecucion = 0;
        SET @MensajeError   = ERROR_MESSAGE();
        -- PRINT + acumular en @DetallesLog
    END CATCH

    -- Notificación por correo (solo si error Y parámetros provistos)
    IF @ExitoEjecucion = 0 AND @CorreoNotificacion IS NOT NULL AND @PerfilCorreo IS NOT NULL
        EXEC msdb.dbo.sp_send_dbmail ...;

    -- Log obligatorio
    INSERT INTO dbo.LogSilverDiario
        (FechaEjecucion, FilasInsertadas, EstadoEjecucion, MensajeError, DetallesLog, NombreJob, ProgramadorJob)
    VALUES (...);
END;
```

---

## 5. Tipos de ventana temporal

| Periodicidad | Variables | Lógica de cálculo | Condición WHERE |
|---|---|---|---|
| **DIARIA** | `@FechaDia DATE` | `CAST(@FechaSistema AS DATE)` | `= @FechaDia` |
| **MENSUAL** | `@FechaIni DATE`, `@FechaFin DATE` | `DATEFROMPARTS(year, month, 1)` / `DATEADD(month,1,@FechaIni)` | `>= @FechaIni AND < @FechaFin` |
| **TRIMESTRAL** | `@FechaIni DATE`, `@FechaFin DATE` | inicio del trimestre calendario / `DATEADD(month,3,@FechaIni)` | `>= @FechaIni AND < @FechaFin` |

> La ventana debe ser **consistente entre el SP SILVER y el SP ION** del mismo reporte. Una discrepancia (como la encontrada en 119) es un hallazgo a corregir.

---

## 6. Patrón de SP ION (entrega regulatoria)

```sql
CREATE OR ALTER PROCEDURE [dbo].[NNN_NOMBRE]
    @FECHA DATE   -- o @FECHA_INI / @FECHA_FIN según periodicidad
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SELECT
        -- Solo columnas del layout regulatorio
        -- NO incluir ID ni FECHA_EXTRACCION
    FROM [SILVER].[RR].[NNN_NOMBRE]
    WHERE [columna_fecha] = @FECHA;  -- o rango según periodicidad
END;
```

---

## 7. Tabla `dbo.INDICE_REPORTES` (ION)

El índice de reportes en uso es **`ION.dbo.INDICE_REPORTES`**, con esta estructura:

| Columna | Tipo | Valor al desplegar |
|---------|------|-------------------|
| `numero` | `int` | `NNN` |
| `nombre` | `varchar(100)` | nombre del reporte (p. ej. `LID S5`) |
| `frecuencia` | `varchar(100)` | periodicidad (`Diaria`, `Mensual`, `Trimestral`, …) |
| `activo` | `bit` | `0` (inactivo al desplegar) |
| `nombre_archivo` | `varchar(100)` NULL | `NULL` |

> En el rollback **solo se elimina el registro** del reporte (`DELETE WHERE numero=NNN`); la tabla nunca se borra.

---

## 8. Tabla `dbo.tbl_Control_Ejecucion` (SILVER)

- Se crea en el script de despliegue si no existe.
- **Nunca se elimina en el rollback.**
- Igual aplica a `INDICE_REPORTES`.

---

## 9. Convención de scripts de deploy/rollback

```
deploy\
  NNN_NOMBRE_REPORTE\
    NNN_NOMBRE_REPORTE_CREACION.sql   -- o _CORRECCION.sql si es corrección
    NNN_NOMBRE_REPORTE_ROLLBACK.sql
    NNN_NOMBRE_REPORTE_HALLAZGOS.md   -- si aplica
```

### Reglas de idempotencia

| Operación | Patrón |
|-----------|--------|
| Crear tabla | `IF NOT EXISTS (SELECT 1 FROM sys.objects ...)` antes de `CREATE` |
| Crear SP | `CREATE OR ALTER PROCEDURE` |
| Agregar columna | `IF NOT EXISTS (INFORMATION_SCHEMA.COLUMNS ...)` antes de `ALTER TABLE ... ADD` |
| Alterar columna | Verificar tipo actual antes de `ALTER TABLE ... ALTER COLUMN` |
| Eliminar columna (rollback) | `IF EXISTS (INFORMATION_SCHEMA.COLUMNS ...)` antes de `DROP COLUMN` |
| Eliminar SP (rollback) | `IF EXISTS (sys.objects WHERE name=... AND type='P')` antes de `DROP` |
| Eliminar tabla (rollback) | `IF EXISTS (sys.objects JOIN sys.schemas ...)` antes de `DROP TABLE` |

---

## 10. Objetos protegidos (nunca eliminar en rollback)

- `SILVER.dbo.tbl_Control_Ejecucion`
- `ION.dbo.INDICE_REPORTES` (en rollback solo se borra el registro del reporte, no la tabla)
- `SILVER.dbo.LogSilverDiario`

---

## 11. Nomenclatura de la columna de fecha de información

- El nombre estándar de la columna es **`FECHA_INFO`** (con guion bajo), tanto en la tabla `RR` como en los SPs.
- Si el **layout la nombra `FECHAINFO`** (sin guion bajo), de todas formas se implementa como **`FECHA_INFO`**.
- En el SP se deja un **comentario** indicando que el layout la nombra `FECHAINFO` y que se estandarizó a `FECHA_INFO`.
- Reportes cuyo layout usa `FECHAINFO`: **132**, **155**, **156**.
- **Excepciones confirmadas — reportes 132 y 156**: por indicación del usuario, **132 y 156 conservan el nombre LITERAL `FECHAINFO`** (sin guion bajo) en tabla, SPs y encabezado de salida. **155** sí sigue la regla general (`FECHA_INFO`).

---

## 12. Formato de fecha en la salida del SP de ION

- Todas las columnas de fecha en la **salida del SP de ION** se entregan en formato **`AAAA/MM/DD`** (`FORMAT([col], 'yyyy/MM/dd')`).
- Aplica a los 8 SPs trabajados: **080, 081, 083, 132, 155, 156, 212, 213**.
- Si el **layout marca un formato distinto** (p. ej. `AAAAMMDD`), se mantiene la salida `AAAA/MM/DD` y se deja un **comentario** en el SP indicando el formato del layout y la decisión tomada.
- En la BD las fechas se almacenan como `date`; el formato es solo de presentación en la capa ION.

---

## 13. Orden de columnas en la salida del SP de ION

- El orden de las columnas en la salida del SP de ION se toma de la columna **`ORDEN`** del layout
  (la enumeración de campos), **no** de `COLUMNA REPORTE APLICA`.
- Los valores de `ORDEN` **pueden no ser secuenciales** (huecos); aun así se respeta ese orden relativo.
- Caso típico: `FECHA_INFO` suele ser el **último** `ORDEN` del layout, por lo que va como **última columna**
  de la salida (aunque `COLUMNA REPORTE APLICA` la ubique antes).

---

## Pendientes confirmados

- [ ] Confirmar si la discrepancia de ventana en `119_ENT_PRESTAMOS_VALORES` (SILVER mensual vs ION diaria) requiere corrección.
