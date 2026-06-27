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
| Crear SP | `CREATE OR ALTER PROCEDURE` |
| Renombrar tabla | `IF EXISTS (old) AND NOT EXISTS (new)` → `EXEC sp_rename` |
| Agregar columna | `IF NOT EXISTS (INFORMATION_SCHEMA.COLUMNS ...)` → `ALTER TABLE ... ADD` |
| Alterar columna | Verificar tipo actual antes de `ALTER TABLE ... ALTER COLUMN` |
| Crear tabla (solo si no queda otra opción) | `IF NOT EXISTS (SELECT 1 FROM sys.objects ...)` antes de `CREATE` |
| Eliminar columna (rollback) | `IF EXISTS (INFORMATION_SCHEMA.COLUMNS ...)` antes de `DROP COLUMN` |
| Eliminar SP (rollback) | `IF EXISTS (sys.objects WHERE name=... AND type='P')` antes de `DROP` |
| Eliminar tabla (rollback) | `IF EXISTS (sys.objects JOIN sys.schemas ...)` antes de `DROP TABLE` |

### Preferencia ALTER sobre DROP+CREATE

- **Usar `ALTER TABLE`** para agregar, modificar o eliminar columnas. Preserva datos existentes.
- **Usar `sp_rename`** para renombrar tablas o columnas.
- **Usar `CREATE OR ALTER PROCEDURE`** siempre para SPs (ya establecido).
- **`DROP TABLE` + `CREATE TABLE` solo cuando** la reestructuración es tan extensa (muchas columnas nuevas, tipos cambiados, columnas eliminadas) que el ALTER sería más riesgoso o verboso que un recreado limpio. Documentar la razón en el encabezado del script.

---

## 10. Objetos protegidos (nunca eliminar en rollback)

- `SILVER.dbo.tbl_Control_Ejecucion`
- `ION.dbo.INDICE_REPORTES` (en rollback solo se borra el registro del reporte, no la tabla)
- `SILVER.dbo.LogSilverDiario`

---

## 11. Nomenclatura de la columna de fecha de información

- Se respeta el **nombre exacto que indica el layout**: si dice `FECHA_INFO` → `FECHA_INFO`; si dice `FECHAINFO` → `FECHAINFO`.
- Si el layout **no incluye ninguna columna de fecha de información**, la columna `FECHA_INFO` existe únicamente como columna interna de control en la tabla `BRONZE.[LMDA]` y en `SILVER.[RR]` (para filtro de idempotencia), pero **no se expone en el SP de ION**.
- Reportes aplicados:

| Reporte | Nombre en layout | En tabla SILVER/LMDA | En SP ION |
|---------|-----------------|----------------------|-----------|
| 080, 081, 083, 155, 212, 213 | `FECHA_INFO` | `FECHA_INFO` | `FECHA_INFO` |
| 132, 156 | `FECHAINFO` | `FECHAINFO` | `FECHAINFO` |
| 093 | *(no aparece)* | `FECHA_INFO` (interna) | no expuesta |

---

## 12. Formato de fecha en la salida del SP de ION

- Todas las columnas de fecha en la **salida del SP de ION** se entregan en formato **`AAAA/MM/DD`** (`FORMAT([col], 'yyyy/MM/dd')`).
- Aplica a los 8 SPs trabajados: **080, 081, 083, 132, 155, 156, 212, 213**.
- Si el **layout marca un formato distinto** (p. ej. `AAAAMMDD`), se mantiene la salida `AAAA/MM/DD` y se deja un **comentario** en el SP indicando el formato del layout y la decisión tomada.
- En la BD las fechas se almacenan como `date`; el formato es solo de presentación en la capa ION.

---

## 13. Formato de fecha según lo que indica el layout

El formato de salida en el SP ION depende de lo que indique el layout para cada campo:

| Layout dice | Formato de salida | Ejemplo | Función SQL |
|-------------|------------------|---------|-------------|
| `AAAA/MM/DD` o sin especificar | `yyyy/MM/dd` | `2026/06/19` | `FORMAT(col, 'yyyy/MM/dd')` |
| `DD/MM/AAAA` | `dd/MM/yyyy` | `19/06/2026` | `FORMAT(col, 'dd/MM/yyyy')` |
| `YYYY-MM-DD` o `AAAA-MM-DD` | `yyyy-MM-dd` | `2026-06-19` | `FORMAT(col, 'yyyy-MM-dd')` |

> Regla general (consideración 12): usar `AAAA/MM/DD` salvo que el layout especifique explícitamente otro formato.

---

## 14. Orden de columnas en la salida del SP de ION

- El orden de las columnas en la salida del SP de ION se toma de la columna **`ORDEN`** del layout
  (la enumeración de campos), **no** de `COLUMNA REPORTE APLICA`.
- Los valores de `ORDEN` **pueden no ser secuenciales** (huecos); aun así se respeta ese orden relativo.
- Caso típico: `FECHA_INFO` / `FECHAINFO` suele ser el **último** `ORDEN` del layout, por lo que va como
  **última columna** de la salida (aunque `COLUMNA REPORTE APLICA` la ubique antes).

---

## 15. DEFAULT constraints en tablas importadas del DDL

Las tablas creadas vía `CREATE TABLE` dentro de un script de ajuste incluyen los constraints `DEFAULT (NEWID())` en `ID` y `DEFAULT (GETDATE())` en `FECHA_EXTRACCION`. Sin embargo, las tablas **importadas del DDL original** pueden no tenerlos.

Al trabajar con una tabla existente (patrón ALTER), verificar y agregar si faltan:

```sql
IF NOT EXISTS (... WHERE o.name='NNN_NOMBRE' AND col.name='ID')
    ALTER TABLE [RR].[NNN_NOMBRE] ADD CONSTRAINT DF_NNN_ID DEFAULT (NEWID()) FOR [ID];

IF NOT EXISTS (... WHERE o.name='NNN_NOMBRE' AND col.name='FECHA_EXTRACCION')
    ALTER TABLE [RR].[NNN_NOMBRE] ADD CONSTRAINT DF_NNN_FEXT DEFAULT (GETDATE()) FOR [FECHA_EXTRACCION];
```

> Incluir estos bloques en la sección 01 del AJUSTE, antes del SP SILVER.

---

## Estado del entorno (actualizado 2026-06-17)

- **DDL vigente reinstalado limpio** desde `C:\LOCAL\DESA\Rusty-Cracket\scheme\{BRONZE,ION,SILVER}.sql`
  (UTF-16). Conteos: BRONZE 206 tablas / 24 rutinas · ION 397 / 224 · SILVER 218 / 216.
- `ION.dbo.INDICE_REPORTES` **cargado** desde `scheme\INDICE_REPORTES.csv` (210 filas; 212 y 213 ya con
  los nombres `SECCION_5_LINEAS_CRE` / `SECCION_A_CAT_LINEAS`).
- **Dos patrones de carga** identificados: **self-select** (este documento, sección 4) y **origen LMDA**
  (ver `PATRON_ORIGEN_LMDA.md`, ~35-37 SPs que cargan desde `BRONZE.[LMDA].[…]`).
- **Ubicación**: `deploy/` y `layout/` viven ahora en el repo git
  `C:\LOCAL\DESA\non-purple-wheel\non-purple-wheel\`; el arnés (scheme/, scripts .py, BD) sigue en
  `C:\LOCAL\DESA\Rusty-Cracket`.

---

## Pendientes confirmados

- [ ] Confirmar si la discrepancia de ventana en `119_ENT_PRESTAMOS_VALORES` (SILVER mensual vs ION diaria) requiere corrección.
- [ ] **Ajustar uno de los ~37 reportes origen LMDA con un layout más nuevo** (el usuario está reuniendo la información).
- [ ] **Tras la reinstalación limpia**: verificar si el DDL vigente ya incorpora las correcciones que hicimos hoy
  (080, 081, 083, 132, 155, 156) y los reportes 212/213, para saber qué conviene re-aplicar desde `deploy/`.
- [ ] **Validación real contra catálogos** (`ION.s3`): diferida hasta que un layout/SP futuro la requiera; definir
  entonces el mapeo nombre-lógico → tabla física.

### Resueltos (referencia)
- ✔ Nombre `FECHA_INFO` estandarizado (consideración 11), con **excepciones 132 y 156** que usan `FECHAINFO` literal.
- ✔ Formato de salida `AAAA/MM/DD` (consideración 12) y orden por `ORDEN` con `FECHA_INFO` al final (consideración 13).
- ✔ 212/213 realineados a **self-select** (sin BRONZE/LMDA ni zero-pad); el objeto 209 descartado como referencia.
- ✔ 132 sin columnas ajenas al layout (`FE_CORTE`, `ACT_OPE_VAL`, `PAS_OPE_VAL`); filtro por `FECHAINFO`.
- ✔ Estructura/uso de `INDICE_REPORTES` (ION) definido y cargado.
