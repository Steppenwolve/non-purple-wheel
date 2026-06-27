/* ============================================================================
   140_ENT_GARANTIAS_II_AJUSTE.sql
   Reporte    : ENT_GARANTIAS_II  (Garantias - Mercados No Reconocidos)
   Objeto     : 140_ENT_GARANTIAS_II   (SILVER e ION)
   Layout     : Layout_Garantias_V2_FILE_GARANTIAS_II.xlsx (14 campos)
   Periodicidad : SEMANAL
   Patron     : ORIGEN LMDA (ver deploy/PATRON_ORIGEN_LMDA.md)
                Crea BRONZE.[LMDA].[GARANTIAS_II] (tabla landing dedicada).
                SP SILVER: INSERT...SELECT FROM BRONZE.[LMDA].[GARANTIAS_II]
                           filtrando FECHAINFO en ventana semanal.
   Hallazgos  : ver 140_ENT_GARANTIAS_II_HALLAZGOS.md
   Decisiones :
     - FECHA_REPORTE renombrada a FECHAINFO (sp_rename, preserva datos).
     - FECHAINFO en ION: FORMAT('dd/MM/yyyy') segun layout DD/MM/AAAA.
     - FE_AV_BI en ION: FORMAT('yyyy/MM/dd') segun consideracion 12.
     - Sin zero-pad; sin columnas nuevas ni eliminadas (solo rename + patron).
   ============================================================================ */

/* ----------------------------------------------------------------------------
   00 - BRONZE  [LMDA].[GARANTIAS_II]  -> tabla landing dedicada
   ---------------------------------------------------------------------------- */
USE [BRONZE];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
    WHERE s.name='LMDA' AND o.name='GARANTIAS_II' AND o.type='U'
)
BEGIN
    CREATE TABLE [LMDA].[GARANTIAS_II]
    (
        [ID]               [uniqueidentifier] NOT NULL CONSTRAINT DF_LMDA_GARANTIAS_II_ID DEFAULT (NEWID()),
        [OFICINA]          [varchar](1)        NOT NULL,
        [CONT]             [varchar](6)        NOT NULL,
        [ID_GAR]           [varchar](20)       NOT NULL,
        [CON_GTA]          [numeric](3, 0)    NOT NULL,
        [POS_GTA]          [varchar](1)        NOT NULL,
        [TIP_GTA]          [numeric](2, 0)    NOT NULL,
        [CVE_TIT]          [varchar](20)       NOT NULL,
        [EMI_ACT]          [varchar](6)        NOT NULL,
        [FE_AV_BI]         [date]             NOT NULL,
        [RE_BM_BI]         [varchar](20)       NOT NULL,
        [AFORO]            [numeric](5, 2)    NOT NULL,
        [VAL_GTA]          [numeric](15, 0)   NOT NULL,
        [MDA_GTA]          [numeric](3, 0)    NOT NULL,
        [FECHA_EXTRACCION] [smalldatetime]    NOT NULL CONSTRAINT DF_LMDA_GARANTIAS_II_FEXT DEFAULT (GETDATE()),
        [FECHAINFO]        [date]             NULL,
        CONSTRAINT PK_LMDA_GARANTIAS_II PRIMARY KEY CLUSTERED ([ID] ASC)
    ) ON [PRIMARY];
    PRINT '>> Creada BRONZE.[LMDA].[GARANTIAS_II].';
END
ELSE
    PRINT '>> BRONZE.[LMDA].[GARANTIAS_II] ya existe, se omite creacion.';
GO

/* ----------------------------------------------------------------------------
   01 - SILVER  [RR].[140_ENT_GARANTIAS_II]
        Renombrar FECHA_REPORTE -> FECHAINFO (preserva datos existentes).
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='140_ENT_GARANTIAS_II' AND COLUMN_NAME='FECHA_REPORTE')
   AND NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
                   WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='140_ENT_GARANTIAS_II' AND COLUMN_NAME='FECHAINFO')
BEGIN
    EXEC sp_rename '[RR].[140_ENT_GARANTIAS_II].[FECHA_REPORTE]', 'FECHAINFO', 'COLUMN';
    PRINT '>> Columna FECHA_REPORTE renombrada a FECHAINFO en SILVER.[RR].[140_ENT_GARANTIAS_II].';
END
ELSE
    PRINT '>> Rename FECHA_REPORTE->FECHAINFO: ya aplicado o no necesario.';
GO

-- Asegurar DEFAULT NEWID() en ID y DEFAULT GETDATE() en FECHA_EXTRACCION
-- (pueden faltar en tablas importadas del DDL sin constraints explícitos)
IF NOT EXISTS (
    SELECT 1 FROM sys.default_constraints dc
    JOIN sys.columns col ON col.default_object_id = dc.object_id
    JOIN sys.objects o ON o.object_id = dc.parent_object_id
    WHERE o.name='140_ENT_GARANTIAS_II' AND col.name='ID'
)
    ALTER TABLE [RR].[140_ENT_GARANTIAS_II]
        ADD CONSTRAINT DF_140_GARANTIAS_II_ID DEFAULT (NEWID()) FOR [ID];

-- Asegurar DEFAULT GETDATE() en FECHA_EXTRACCION (puede faltar en tablas importadas del DDL)
IF NOT EXISTS (
    SELECT 1 FROM sys.default_constraints dc
    JOIN sys.columns col ON col.default_object_id = dc.object_id
    JOIN sys.objects o ON o.object_id = dc.parent_object_id
    WHERE o.name='140_ENT_GARANTIAS_II' AND col.name='FECHA_EXTRACCION'
)
    ALTER TABLE [RR].[140_ENT_GARANTIAS_II]
        ADD CONSTRAINT DF_140_GARANTIAS_II_FEXT DEFAULT (GETDATE()) FOR [FECHA_EXTRACCION];
PRINT '>> DEFAULT FECHA_EXTRACCION verificado en SILVER.[RR].[140_ENT_GARANTIAS_II].';
GO

/* ----------------------------------------------------------------------------
   02 - SILVER SP  [dbo].[140_ENT_GARANTIAS_II]  (ORIGEN LMDA)
        Carga desde BRONZE.[LMDA].[GARANTIAS_II]. SEMANAL. Filtro por FECHAINFO.
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[140_ENT_GARANTIAS_II]
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
            @FechaInicio DATETIME=GETDATE(), @NombreJob NVARCHAR(128)='[140_ENT_GARANTIAS_II]',
            @FechaIni DATE, @FechaFin DATE;

    BEGIN TRY
        -- SEMANAL: lunes de la semana de @FechaSistema
        SET @FechaIni = DATEADD(DAY, -(DATEPART(WEEKDAY, @FechaSistema) + 5) % 7, CAST(@FechaSistema AS DATE));
        SET @FechaFin = DATEADD(DAY, 7, @FechaIni);

        IF EXISTS (SELECT 1 FROM [SILVER].[RR].[140_ENT_GARANTIAS_II]
                   WHERE [FECHAINFO] >= @FechaIni AND [FECHAINFO] < @FechaFin)
        BEGIN
            DELETE FROM [SILVER].[RR].[140_ENT_GARANTIAS_II]
            WHERE [FECHAINFO] >= @FechaIni AND [FECHAINFO] < @FechaFin;
            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage; SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13)+CHAR(10);
        END

        INSERT INTO [RR].[140_ENT_GARANTIAS_II] (
            [OFICINA],[CONT],[ID_GAR],[CON_GTA],[POS_GTA],[TIP_GTA],
            [CVE_TIT],[EMI_ACT],[FE_AV_BI],[RE_BM_BI],[AFORO],[VAL_GTA],[MDA_GTA],[FECHAINFO]
        )
        SELECT
            R.[OFICINA], R.[CONT], R.[ID_GAR], R.[CON_GTA], R.[POS_GTA], R.[TIP_GTA],
            R.[CVE_TIT], R.[EMI_ACT], R.[FE_AV_BI], R.[RE_BM_BI], R.[AFORO], R.[VAL_GTA], R.[MDA_GTA], R.[FECHAINFO]
        FROM [BRONZE].[LMDA].[GARANTIAS_II] R
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
PRINT '>> Creado/actualizado SILVER.dbo.[140_ENT_GARANTIAS_II] (origen LMDA.GARANTIAS_II).';
GO

/* ----------------------------------------------------------------------------
   03 - ION SP  [dbo].[140_ENT_GARANTIAS_II]  (entrega V2)
        14 cols regulatorias. Sin ID ni FECHA_EXTRACCION.
        FE_AV_BI: AAAA/MM/DD (consideracion 12).
        FECHAINFO: DD/MM/AAAA (formato explicito en layout). Ventana semanal.
   ---------------------------------------------------------------------------- */
USE [ION];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[140_ENT_GARANTIAS_II]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @FechaIni DATE, @FechaFin DATE;
    SET @FechaIni = DATEADD(DAY, -(DATEPART(WEEKDAY, @FECHA) + 5) % 7, @FECHA);
    SET @FechaFin = DATEADD(DAY, 7, @FechaIni);

    -- NOTA (consideracion 13): orden por ORDEN del layout.
    -- NOTA: FE_AV_BI en AAAA-MM-DD (layout especifica YYYY-MM-DD con guion).
    -- NOTA: FECHAINFO en DD/MM/AAAA segun formato explicito del layout.
    SELECT
        [OFICINA]                              AS OFICINA,
        [CONT]                                 AS CONT,
        [ID_GAR]                               AS ID_GAR,
        [CON_GTA]                              AS CON_GTA,
        [POS_GTA]                              AS POS_GTA,
        [TIP_GTA]                              AS TIP_GTA,
        [CVE_TIT]                              AS CVE_TIT,
        [EMI_ACT]                              AS EMI_ACT,
        FORMAT([FE_AV_BI],  'yyyy-MM-dd')      AS FE_AV_BI,
        [RE_BM_BI]                             AS RE_BM_BI,
        [AFORO]                                AS AFORO,
        [VAL_GTA]                              AS VAL_GTA,
        [MDA_GTA]                              AS MDA_GTA,
        FORMAT([FECHAINFO], 'dd/MM/yyyy')      AS FECHAINFO
    FROM [SILVER].[RR].[140_ENT_GARANTIAS_II]
    WHERE [FECHAINFO] >= @FechaIni AND [FECHAINFO] < @FechaFin;
END;
GO
PRINT '>> Creado/actualizado ION.dbo.[140_ENT_GARANTIAS_II] (salida V2, 14 cols).';
GO

/* ----------------------------------------------------------------------------
   04 - ION.dbo.INDICE_REPORTES : asegurar registro 140
   ---------------------------------------------------------------------------- */
USE [ION];
GO
SET NOCOUNT ON;
IF EXISTS (SELECT 1 FROM dbo.INDICE_REPORTES WHERE numero = 140)
    UPDATE dbo.INDICE_REPORTES SET nombre='ENT_GARANTIAS_II', frecuencia='Semanal' WHERE numero = 140;
ELSE
    INSERT INTO dbo.INDICE_REPORTES (numero,nombre,frecuencia,activo,nombre_archivo)
    VALUES (140,'ENT_GARANTIAS_II','Semanal',0,NULL);
PRINT '>> Registro 140 verificado en ION.dbo.INDICE_REPORTES.';
GO
PRINT '>> Ajuste 140_ENT_GARANTIAS_II (origen LMDA.GARANTIAS_II, layout V2, semanal) completado.';
GO
