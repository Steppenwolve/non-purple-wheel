/* ============================================================================
   093_ENT_CF_AJUSTE.sql
   Reporte    : ENT_CF  (Captacion de Fondos tipo I)
   Objeto     : 093_ENT_CF   (SILVER e ION)
   Layout     : Layout CF_V3_CF_I.xlsx (hoja 'CF ESP', 9 campos)
   Periodicidad : SEMANAL
   Patron     : ORIGEN LMDA (ver deploy/PATRON_ORIGEN_LMDA.md)
                Crea BRONZE.[LMDA].[CF_I] (tabla landing dedicada).
                SP SILVER: INSERT...SELECT FROM BRONZE.[LMDA].[CF_I]
                           filtrando FECHA_INFO en ventana semanal.
   Hallazgos  : ver 093_ENT_CF_HALLAZGOS.md
   Decisiones :
     - Objeto renombrado: [093_ ENT_CF] (espacio) -> [093_ENT_CF] (sin espacio).
     - Los objetos con nombre incorrecto se eliminan explicitamente.
     - FECHA_INFO: no esta en el layout; se agrega como columna estandar LMDA.
     - Ventana semanal: lunes de la semana de @FechaSistema + 7 dias.
       @FechaIni = DATEADD(DAY, -(DATEPART(WEEKDAY,@FechaSistema)+5)%7, CAST(@FechaSistema AS DATE))
       @FechaFin = DATEADD(DAY, 7, @FechaIni)
     - Sin zero-pad (valores llegan formateados en tabla LMDA).
   ============================================================================ */

/* ----------------------------------------------------------------------------
   00 - BRONZE  [LMDA].[CF_I]  -> tabla landing dedicada
   ---------------------------------------------------------------------------- */
USE [BRONZE];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
    WHERE s.name='LMDA' AND o.name='CF_I' AND o.type='U'
)
BEGIN
    CREATE TABLE [LMDA].[CF_I]
    (
        [ID]               [uniqueidentifier] NOT NULL CONSTRAINT DF_LMDA_CF_I_ID DEFAULT (NEWID()),
        [TIPOOPERACION]    [numeric](2, 0)    NOT NULL,
        [TIPOFONDEO]       [numeric](2, 0)    NOT NULL,
        [FECHA_INICIO]     [date]             NOT NULL,
        [FECHA_VENC]       [date]             NOT NULL,
        [MONTO_OPER]       [numeric](12, 0)   NOT NULL,
        [MONEDA]           [varchar](3)        NOT NULL,
        [CVE_ACREEDOR]     [varchar](18)       NOT NULL,
        [TIP_REL_ACREED]   [numeric](2, 0)    NOT NULL,
        [CVE_OPERACION]    [varchar](34)       NOT NULL,
        [FECHA_EXTRACCION] [smalldatetime]    NOT NULL CONSTRAINT DF_LMDA_CF_I_FEXT DEFAULT (GETDATE()),
        [FECHA_INFO]       [date]             NULL,
        CONSTRAINT PK_LMDA_CF_I PRIMARY KEY CLUSTERED ([ID] ASC)
    ) ON [PRIMARY];
    PRINT '>> Creada BRONZE.[LMDA].[CF_I].';
END
ELSE
    PRINT '>> BRONZE.[LMDA].[CF_I] ya existe, se omite creacion.';
GO

/* ----------------------------------------------------------------------------
   01 - SILVER  [RR].[093_ENT_CF]  -> renombrar y agregar columna FECHA_INFO
        Prefiere ALTER sobre DROP+CREATE para preservar datos existentes.
        a) Si existe [093_ ENT_CF] (nombre incorrecto): renombrar con sp_rename.
        b) Si no existe ninguna version: CREATE desde cero.
        c) Agregar FECHA_INFO si no existe.
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
-- a) Renombrar tabla con nombre incorrecto (espacio) si existe y la correcta aun no
IF EXISTS     (SELECT 1 FROM sys.objects WHERE name='093_ ENT_CF' AND schema_id=SCHEMA_ID('RR') AND type='U')
   AND NOT EXISTS (SELECT 1 FROM sys.objects WHERE name='093_ENT_CF'  AND schema_id=SCHEMA_ID('RR') AND type='U')
    EXEC sp_rename '[RR].[093_ ENT_CF]', '093_ENT_CF', 'OBJECT';
GO
-- b) Si todavia no existe ninguna version, crear desde cero
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name='093_ENT_CF' AND schema_id=SCHEMA_ID('RR') AND type='U')
BEGIN
    CREATE TABLE [RR].[093_ENT_CF]
    (
        [ID]               [uniqueidentifier] NOT NULL CONSTRAINT DF_093_ENT_CF_ID DEFAULT (NEWID()),
        [TIPOOPERACION]    [numeric](2, 0)    NOT NULL,
        [TIPOFONDEO]       [numeric](2, 0)    NOT NULL,
        [FECHA_INICIO]     [date]             NOT NULL,
        [FECHA_VENC]       [date]             NOT NULL,
        [MONTO_OPER]       [numeric](12, 0)   NOT NULL,
        [MONEDA]           [varchar](3)        NOT NULL,
        [CVE_ACREEDOR]     [varchar](18)       NOT NULL,
        [TIP_REL_ACREED]   [numeric](2, 0)    NOT NULL,
        [CVE_OPERACION]    [varchar](34)       NOT NULL,
        [FECHA_INFO]       [date]             NULL,
        [FECHA_EXTRACCION] [smalldatetime]    NOT NULL CONSTRAINT DF_093_ENT_CF_FEXT DEFAULT (GETDATE()),
        CONSTRAINT PK_RR_093_ENT_CF PRIMARY KEY CLUSTERED ([ID] ASC)
    ) ON [PRIMARY];
    PRINT '>> Creada SILVER.[RR].[093_ENT_CF] desde cero.';
END
GO
-- c) Agregar FECHA_INFO si no existe (caso rename desde tabla original sin esa columna)
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='093_ENT_CF' AND COLUMN_NAME='FECHA_INFO')
    ALTER TABLE [RR].[093_ENT_CF] ADD [FECHA_INFO] [date] NULL;

-- d) Asegurar DEFAULT constraints (pueden faltar en tablas importadas del DDL)
IF NOT EXISTS (
    SELECT 1 FROM sys.default_constraints dc
    JOIN sys.columns col ON col.default_object_id = dc.object_id
    JOIN sys.objects o ON o.object_id = dc.parent_object_id
    WHERE o.name='093_ENT_CF' AND col.name='ID'
)
    ALTER TABLE [RR].[093_ENT_CF]
        ADD CONSTRAINT DF_093_ENT_CF_ID DEFAULT (NEWID()) FOR [ID];

IF NOT EXISTS (
    SELECT 1 FROM sys.default_constraints dc
    JOIN sys.columns col ON col.default_object_id = dc.object_id
    JOIN sys.objects o ON o.object_id = dc.parent_object_id
    WHERE o.name='093_ENT_CF' AND col.name='FECHA_EXTRACCION'
)
    ALTER TABLE [RR].[093_ENT_CF]
        ADD CONSTRAINT DF_093_ENT_CF_FEXT DEFAULT (GETDATE()) FOR [FECHA_EXTRACCION];
PRINT '>> SILVER.[RR].[093_ENT_CF] lista (rename + ALTER + DEFAULT constraints).';
GO

/* ----------------------------------------------------------------------------
   02 - SILVER SP  [dbo].[093_ENT_CF]  (ORIGEN LMDA)
        Elimina SP con nombre incorrecto [093_ ENT_CF].
        Carga desde BRONZE.[LMDA].[CF_I]. SEMANAL. Filtro por FECHA_INFO.
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
-- Eliminar SP con nombre incorrecto
IF EXISTS (SELECT 1 FROM sys.objects WHERE name='093_ ENT_CF' AND type='P')
    DROP PROCEDURE [dbo].[093_ ENT_CF];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[093_ENT_CF]
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
            @FechaInicio DATETIME=GETDATE(), @NombreJob NVARCHAR(128)='[093_ENT_CF]',
            @FechaIni DATE, @FechaFin DATE;

    BEGIN TRY
        -- SEMANAL: lunes de la semana de @FechaSistema
        SET @FechaIni = DATEADD(DAY, -(DATEPART(WEEKDAY, @FechaSistema) + 5) % 7, CAST(@FechaSistema AS DATE));
        SET @FechaFin = DATEADD(DAY, 7, @FechaIni);

        IF EXISTS (SELECT 1 FROM [SILVER].[RR].[093_ENT_CF]
                   WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin)
        BEGIN
            DELETE FROM [SILVER].[RR].[093_ENT_CF]
            WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin;
            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage; SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13)+CHAR(10);
        END

        INSERT INTO [RR].[093_ENT_CF] (
            [TIPOOPERACION],[TIPOFONDEO],[FECHA_INICIO],[FECHA_VENC],[MONTO_OPER],
            [MONEDA],[CVE_ACREEDOR],[TIP_REL_ACREED],[CVE_OPERACION],[FECHA_INFO]
        )
        SELECT
            R.[TIPOOPERACION], R.[TIPOFONDEO], R.[FECHA_INICIO], R.[FECHA_VENC], R.[MONTO_OPER],
            R.[MONEDA], R.[CVE_ACREEDOR], R.[TIP_REL_ACREED], R.[CVE_OPERACION], R.[FECHA_INFO]
        FROM [BRONZE].[LMDA].[CF_I] R
        WHERE R.[FECHA_INFO] >= @FechaIni AND R.[FECHA_INFO] < @FechaFin;

        SET @FilasInsertadas = @@ROWCOUNT;
        SET @LogMessage = 'Proceso completado. Filas totales: ' + CAST(@FilasInsertadas AS NVARCHAR(10));
        PRINT @LogMessage; SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13)+CHAR(10);
    END TRY
    BEGIN CATCH
        SET @ExitoEjecucion=0; SET @MensajeError=ERROR_MESSAGE();
        SET @DetallesLog = @DetallesLog + 'Error durante la ejecucion: ' + @MensajeError + CHAR(13)+CHAR(10);
    END CATCH

    IF @ExitoEjecucion=0 AND @CorreoNotificacion IS NOT NULL AND @PerfilCorreo IS NOT NULL
    BEGIN
        DECLARE @Asunto NVARCHAR(255)='ALERTA: Error en ' + @NombreJob;
        DECLARE @Cuerpo NVARCHAR(MAX)='Error en ' + @NombreJob + CHAR(13)+CHAR(10) +
            '- Programado por: ' + ISNULL(@ProgramadorJob,'No especificado') + CHAR(13)+CHAR(10) +
            '- Inicio: ' + CONVERT(VARCHAR,@FechaInicio,120) + CHAR(13)+CHAR(10) +
            '- Mensaje: ' + @MensajeError + CHAR(13)+CHAR(10) + 'Log:' + CHAR(13)+CHAR(10) + @DetallesLog;
        BEGIN TRY
            EXEC msdb.dbo.sp_send_dbmail @profile_name=@PerfilCorreo, @recipients=@CorreoNotificacion,
                 @subject=@Asunto, @body=@Cuerpo, @body_format='TEXT', @importance='High';
        END TRY BEGIN CATCH
            SET @DetallesLog = @DetallesLog + 'Error al enviar alerta: ' + ERROR_MESSAGE() + CHAR(13)+CHAR(10);
        END CATCH
    END

    INSERT INTO dbo.LogSilverDiario
        (FechaEjecucion, FilasInsertadas, EstadoEjecucion, MensajeError, DetallesLog, NombreJob, ProgramadorJob)
    VALUES (@FechaInicio, @FilasInsertadas,
        CASE WHEN @ExitoEjecucion=1 THEN 'Exitoso' ELSE 'Error' END,
        CASE WHEN @ExitoEjecucion=1 THEN NULL ELSE @MensajeError END,
        @DetallesLog, @NombreJob, @ProgramadorJob);
END;
GO
PRINT '>> Creado/actualizado SILVER.dbo.[093_ENT_CF] (origen LMDA.CF_I).';
GO

/* ----------------------------------------------------------------------------
   03 - ION SP  [dbo].[093_ENT_CF]  (entrega V3)
        Elimina SP con nombre incorrecto [093_ ENT_CF].
        9 cols regulatorias (layout no incluye FECHA_INFO). Fechas AAAA/MM/DD.
        Sin ID ni FECHA_EXTRACCION. Ventana semanal por FECHA_INFO (interna).
   ---------------------------------------------------------------------------- */
USE [ION];
GO
-- Eliminar SP con nombre incorrecto
IF EXISTS (SELECT 1 FROM sys.objects WHERE name='093_ ENT_CF' AND type='P')
    DROP PROCEDURE [dbo].[093_ ENT_CF];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[093_ENT_CF]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @FechaIni DATE, @FechaFin DATE;
    SET @FechaIni = DATEADD(DAY, -(DATEPART(WEEKDAY, @FECHA) + 5) % 7, @FECHA);
    SET @FechaFin = DATEADD(DAY, 7, @FechaIni);

    -- NOTA (consideracion 12): fechas en AAAA/MM/DD. (consideracion 13): orden por ORDEN del layout.
    -- NOTA: el layout V3 no incluye FECHA_INFO; no se expone en la entrega.
    SELECT
        [TIPOOPERACION]                              AS TIPOOPERACION,
        [TIPOFONDEO]                                 AS TIPOFONDEO,
        FORMAT([FECHA_INICIO],  'yyyy/MM/dd')        AS FECHA_INICIO,
        FORMAT([FECHA_VENC],    'yyyy/MM/dd')        AS FECHA_VENC,
        [MONTO_OPER]                                 AS MONTO_OPER,
        [MONEDA]                                     AS MONEDA,
        [CVE_ACREEDOR]                               AS CVE_ACREEDOR,
        [TIP_REL_ACREED]                             AS TIP_REL_ACREED,
        [CVE_OPERACION]                              AS CVE_OPERACION
    FROM [SILVER].[RR].[093_ENT_CF]
    WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin;
END;
GO
PRINT '>> Creado/actualizado ION.dbo.[093_ENT_CF] (salida V3, 9 cols).';
GO

/* ----------------------------------------------------------------------------
   04 - ION.dbo.INDICE_REPORTES : asegurar registro 93
        (ya existe con nombre ENT_CF, Semanal; solo actualizar por si acaso)
   ---------------------------------------------------------------------------- */
USE [ION];
GO
SET NOCOUNT ON;
IF EXISTS (SELECT 1 FROM dbo.INDICE_REPORTES WHERE numero = 93)
    UPDATE dbo.INDICE_REPORTES SET nombre='ENT_CF', frecuencia='Semanal' WHERE numero = 93;
ELSE
    INSERT INTO dbo.INDICE_REPORTES (numero,nombre,frecuencia,activo,nombre_archivo)
    VALUES (93,'ENT_CF','Semanal',0,NULL);
PRINT '>> Registro 93 verificado en ION.dbo.INDICE_REPORTES.';
GO
PRINT '>> Ajuste 093_ENT_CF (origen LMDA.CF_I, layout V3, semanal) completado.';
GO
