/* ============================================================================
   142_ENT_GARANTIAS_IV_AJUSTE.sql
   Reporte    : ENT_GARANTIAS_IV  (Garantias - Mercados No Reconocidos IV)
   Objeto     : 142_ENT_GARANTIAS_IV   (SILVER e ION)
   Layout     : Layout_Garantias_V2_FILE_GARANTIAS_IV.xlsx (hoja FILE_GARANTIAS_IV, 7 campos)
   Periodicidad : SEMANAL
   Patron     : ORIGEN LMDA
                Crea BRONZE.[LMDA].[GARANTIAS_IV] (tabla landing dedicada).
                SP SILVER: INSERT...SELECT FROM BRONZE.[LMDA].[GARANTIAS_IV]
                           filtrando FECHAINFO en ventana semanal.
   Hallazgos  : ver 142_ENT_GARANTIAS_IV_HALLAZGOS.md
   Decisiones :
     - FECHA_REPORTE renombrada a FECHAINFO (sp_rename, preserva datos).
     - FECHAINFO en ION: FORMAT('yyyy/MM/dd') — formato AAAA/MM/DD del layout
       (coincide con consideracion 12; se anota comentario en SP ION).
     - Sin zero-pad; sin columnas nuevas ni eliminadas (solo rename + patron).
   ============================================================================ */

/* ----------------------------------------------------------------------------
   00 - BRONZE  [LMDA].[GARANTIAS_IV]  -> tabla landing dedicada
   ---------------------------------------------------------------------------- */
USE [BRONZE];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
    WHERE s.name='LMDA' AND o.name='GARANTIAS_IV' AND o.type='U'
)
BEGIN
    CREATE TABLE [LMDA].[GARANTIAS_IV]
    (
        [ID]               [uniqueidentifier] NOT NULL CONSTRAINT DF_LMDA_GARANTIAS_IV_ID   DEFAULT (NEWID()),
        [OFICINA]          [varchar](1)        NOT NULL,  -- Catalogo: ANEXO A
        [CONT]             [varchar](6)        NOT NULL,  -- Catalogo: ANEXO B
        [NETEO_POS]        [numeric](2, 0)    NOT NULL,  -- Catalogo: ANEXO M (9=no aplica)
        [TIP_CONTRAT]      [numeric](1, 0)    NOT NULL,  -- Catalogo: ANEXO N
        [EXP_POT]          [numeric](15, 0)   NOT NULL,
        [RSG_MAX]          [numeric](15, 0)   NOT NULL,
        [FECHA_EXTRACCION] [smalldatetime]    NOT NULL CONSTRAINT DF_LMDA_GARANTIAS_IV_FEXT DEFAULT (GETDATE()),
        [FECHAINFO]        [date]             NULL,
        CONSTRAINT PK_LMDA_GARANTIAS_IV PRIMARY KEY CLUSTERED ([ID] ASC)
    ) ON [PRIMARY];
    PRINT '>> Creada BRONZE.[LMDA].[GARANTIAS_IV].';
END
ELSE
    PRINT '>> BRONZE.[LMDA].[GARANTIAS_IV] ya existe, se omite creacion.';
GO

/* ----------------------------------------------------------------------------
   01 - SILVER  [RR].[142_ENT_GARANTIAS_IV]
        a) Renombrar FECHA_REPORTE -> FECHAINFO (preserva datos existentes).
        b) Asegurar DEFAULT constraints (ID y FECHA_EXTRACCION).
        c) CREATE desde cero si no existe la tabla.
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
-- a) Renombrar FECHA_REPORTE -> FECHAINFO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='142_ENT_GARANTIAS_IV' AND COLUMN_NAME='FECHA_REPORTE')
   AND NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
                   WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='142_ENT_GARANTIAS_IV' AND COLUMN_NAME='FECHAINFO')
BEGIN
    EXEC sp_rename '[RR].[142_ENT_GARANTIAS_IV].[FECHA_REPORTE]', 'FECHAINFO', 'COLUMN';
    PRINT '>> Columna FECHA_REPORTE renombrada a FECHAINFO en SILVER.[RR].[142_ENT_GARANTIAS_IV].';
END
ELSE
    PRINT '>> Rename FECHA_REPORTE->FECHAINFO: ya aplicado o no necesario.';
GO

-- b) Asegurar DEFAULT constraints (pueden faltar en tablas importadas del DDL)
IF NOT EXISTS (
    SELECT 1 FROM sys.default_constraints dc
    JOIN sys.columns col ON col.default_object_id = dc.object_id
    JOIN sys.objects o ON o.object_id = dc.parent_object_id
    WHERE o.name='142_ENT_GARANTIAS_IV' AND col.name='ID'
)
    ALTER TABLE [RR].[142_ENT_GARANTIAS_IV]
        ADD CONSTRAINT DF_142_GARANTIAS_IV_ID DEFAULT (NEWID()) FOR [ID];

IF NOT EXISTS (
    SELECT 1 FROM sys.default_constraints dc
    JOIN sys.columns col ON col.default_object_id = dc.object_id
    JOIN sys.objects o ON o.object_id = dc.parent_object_id
    WHERE o.name='142_ENT_GARANTIAS_IV' AND col.name='FECHA_EXTRACCION'
)
    ALTER TABLE [RR].[142_ENT_GARANTIAS_IV]
        ADD CONSTRAINT DF_142_GARANTIAS_IV_FEXT DEFAULT (GETDATE()) FOR [FECHA_EXTRACCION];
PRINT '>> DEFAULT constraints verificados en SILVER.[RR].[142_ENT_GARANTIAS_IV].';
GO

-- c) CREATE desde cero si no existe
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name='142_ENT_GARANTIAS_IV' AND schema_id=SCHEMA_ID('RR') AND type='U')
BEGIN
    CREATE TABLE [RR].[142_ENT_GARANTIAS_IV]
    (
        [ID]               [uniqueidentifier] NOT NULL CONSTRAINT DF_142_GARANTIAS_IV_ID   DEFAULT (NEWID()),
        [OFICINA]          [varchar](1)        NOT NULL,
        [CONT]             [varchar](6)        NOT NULL,
        [NETEO_POS]        [numeric](2, 0)    NOT NULL,
        [TIP_CONTRAT]      [numeric](1, 0)    NOT NULL,
        [EXP_POT]          [numeric](15, 0)   NOT NULL,
        [RSG_MAX]          [numeric](15, 0)   NOT NULL,
        [FECHAINFO]        [date]             NULL,
        [FECHA_EXTRACCION] [smalldatetime]    NOT NULL CONSTRAINT DF_142_GARANTIAS_IV_FEXT DEFAULT (GETDATE()),
        CONSTRAINT PK_RR_142_GARANTIAS_IV PRIMARY KEY CLUSTERED ([ID] ASC)
    ) ON [PRIMARY];
    PRINT '>> Creada SILVER.[RR].[142_ENT_GARANTIAS_IV] desde cero.';
END
ELSE
    PRINT '>> SILVER.[RR].[142_ENT_GARANTIAS_IV] lista (rename + DEFAULT constraints).';
GO

/* ----------------------------------------------------------------------------
   02 - SILVER SP  [dbo].[142_ENT_GARANTIAS_IV]  (ORIGEN LMDA)
        Carga desde BRONZE.[LMDA].[GARANTIAS_IV]. SEMANAL. Filtro por FECHAINFO.
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[142_ENT_GARANTIAS_IV]
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
            @FechaInicio DATETIME=GETDATE(), @NombreJob NVARCHAR(128)='[142_ENT_GARANTIAS_IV]',
            @FechaIni DATE, @FechaFin DATE;

    BEGIN TRY
        -- SEMANAL: lunes de la semana de @FechaSistema
        SET @FechaIni = DATEADD(DAY, -(DATEPART(WEEKDAY, @FechaSistema) + 5) % 7, CAST(@FechaSistema AS DATE));
        SET @FechaFin = DATEADD(DAY, 7, @FechaIni);

        IF EXISTS (SELECT 1 FROM [SILVER].[RR].[142_ENT_GARANTIAS_IV]
                   WHERE [FECHAINFO] >= @FechaIni AND [FECHAINFO] < @FechaFin)
        BEGIN
            DELETE FROM [SILVER].[RR].[142_ENT_GARANTIAS_IV]
            WHERE [FECHAINFO] >= @FechaIni AND [FECHAINFO] < @FechaFin;
            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage; SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13)+CHAR(10);
        END

        INSERT INTO [RR].[142_ENT_GARANTIAS_IV] (
            [OFICINA],[CONT],[NETEO_POS],[TIP_CONTRAT],[EXP_POT],[RSG_MAX],[FECHAINFO]
        )
        SELECT
            R.[OFICINA], R.[CONT], R.[NETEO_POS], R.[TIP_CONTRAT], R.[EXP_POT], R.[RSG_MAX], R.[FECHAINFO]
        FROM [BRONZE].[LMDA].[GARANTIAS_IV] R
        WHERE R.[FECHAINFO] >= @FechaIni AND R.[FECHAINFO] < @FechaFin;

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
PRINT '>> Creado/actualizado SILVER.dbo.[142_ENT_GARANTIAS_IV] (origen LMDA.GARANTIAS_IV).';
GO

/* ----------------------------------------------------------------------------
   03 - ION SP  [dbo].[142_ENT_GARANTIAS_IV]  (entrega V2)
        7 cols del layout (ORDENES 1-7). Sin ID ni FECHA_EXTRACCION.
        FECHAINFO: FORMAT('yyyy/MM/dd') — layout indica AAAA/MM/DD (coincide con consideracion 12).
        Ventana semanal identica al SP SILVER.
   ---------------------------------------------------------------------------- */
USE [ION];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[142_ENT_GARANTIAS_IV]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @FechaIni DATE, @FechaFin DATE;
    SET @FechaIni = DATEADD(DAY, -(DATEPART(WEEKDAY, @FECHA) + 5) % 7, @FECHA);
    SET @FechaFin = DATEADD(DAY, 7, @FechaIni);

    -- Orden por ORDEN del layout 
    -- FECHAINFO: layout especifica AAAA/MM/DD -> FORMAT('yyyy/MM/dd') 
    SELECT
        [OFICINA]                              AS OFICINA,
        [CONT]                                 AS CONT,
        [NETEO_POS]                            AS NETEO_POS,
        [TIP_CONTRAT]                          AS TIP_CONTRAT,
        [EXP_POT]                              AS EXP_POT,
        [RSG_MAX]                              AS RSG_MAX,
        FORMAT([FECHAINFO], 'yyyy/MM/dd')      AS FECHAINFO  -- AAAA/MM/DD segun layout 
    FROM [SILVER].[RR].[142_ENT_GARANTIAS_IV]
    WHERE [FECHAINFO] >= @FechaIni AND [FECHAINFO] < @FechaFin;
END;
GO
PRINT '>> Creado/actualizado ION.dbo.[142_ENT_GARANTIAS_IV] (salida V2, 7 cols).';
GO

/* ----------------------------------------------------------------------------
   04 - ION.dbo.INDICE_REPORTES : asegurar registro 142
   ---------------------------------------------------------------------------- */
USE [ION];
GO
SET NOCOUNT ON;
IF EXISTS (SELECT 1 FROM dbo.INDICE_REPORTES WHERE numero = 142)
    UPDATE dbo.INDICE_REPORTES SET nombre='ENT_GARANTIAS_IV', frecuencia='Semanal' WHERE numero = 142;
ELSE
    INSERT INTO dbo.INDICE_REPORTES (numero,nombre,frecuencia,activo,nombre_archivo)
    VALUES (142,'ENT_GARANTIAS_IV','Semanal',0,NULL);
PRINT '>> Registro 142 verificado en ION.dbo.INDICE_REPORTES.';
GO
PRINT '>> Ajuste 142_ENT_GARANTIAS_IV (origen LMDA.GARANTIAS_IV, layout V2, semanal) completado.';
GO
