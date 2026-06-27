/* ============================================================================
   122_ENT_REPORTOS_CANASTA_AJUSTE.sql
   Reporte    : ENT_REPORTOS_CANASTA  (Canasta de Reportos)
   Objeto     : 122_ENT_REPORTOS_CANASTA   (SILVER e ION)
   Layout     : Layout_REPORTOS_MN_ME_V7.1_2024_CANASTA_REPORTOS.xlsx
                Hoja 'CANASTA_REPORTOS', 14 campos (ORDENES 3-16).
   Periodicidad : DIARIA
   Patron     : ORIGEN LMDA
                Lee de BRONZE.[LMDA].[CANASTA_REPORTOS] (ya existe).
                SP SILVER: INSERT...SELECT filtrando FECHA_INFO = @FechaDia.
   Hallazgos  : ver 122_ENT_REPORTOS_CANASTA_HALLAZGOS.md
   Cambios    : Solo SPs (tabla SILVER y tabla BRONZE ya tienen estructura correcta).
   ============================================================================ */

/* ----------------------------------------------------------------------------
   00 - BRONZE  [LMDA].[CANASTA_REPORTOS]  -> ya existe; CREATE solo si falta
   ---------------------------------------------------------------------------- */
USE [BRONZE];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
    WHERE s.name='LMDA' AND o.name='CANASTA_REPORTOS' AND o.type='U'
)
BEGIN
    CREATE TABLE [LMDA].[CANASTA_REPORTOS]
    (
        [ID]                            [uniqueidentifier] NOT NULL CONSTRAINT DF_LMDA_CANASTA_REP_ID   DEFAULT (NEWID()),
        [FECHACONCERTACION]             [date]             NOT NULL,
        [TITULOOBJETOREPORTO]           [varchar](18)      NOT NULL,
        [PRECIOUNITARIOTITULOS]         [numeric](19, 8)   NOT NULL,
        [NUMEROTITULOSOBJETOREPORTO]    [numeric](12, 0)   NOT NULL,
        [IMPORTEREPORTO]                [numeric](12, 0)   NOT NULL,
        [HAIRCUT]                       [numeric](4, 2)    NOT NULL,
        [FECHA_FIN_COLATERAL]           [date]             NOT NULL,
        [NUMEROIDENTIFICACIONOPERACION] [varchar](37)      NOT NULL,
        [NUM_ID_CANASTA]                [varchar](37)      NOT NULL,
        [SECCION]                       [varchar](2)       NOT NULL,
        [EMISION]                       [varchar](50)      NULL,
        [SERIE]                         [varchar](50)      NULL,
        [TIPOVALOR]                     [varchar](50)      NULL,
        [FECHA_INFO]                    [date]             NOT NULL,
        [FECHA_EXTRACCION]              [smalldatetime]    NOT NULL CONSTRAINT DF_LMDA_CANASTA_REP_FEXT DEFAULT (GETDATE()),
        CONSTRAINT PK_LMDA_CANASTA_REPORTOS PRIMARY KEY CLUSTERED ([ID] ASC)
    ) ON [PRIMARY];
    PRINT '>> Creada BRONZE.[LMDA].[CANASTA_REPORTOS].';
END
ELSE
    PRINT '>> BRONZE.[LMDA].[CANASTA_REPORTOS] ya existe, se omite creacion.';
GO

/* ----------------------------------------------------------------------------
   01 - SILVER  [RR].[122_ENT_REPORTOS_CANASTA]
        Estructura ya correcta. Solo asegurar DEFAULT constraints.
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.default_constraints dc
    JOIN sys.columns col ON col.default_object_id = dc.object_id
    JOIN sys.objects o ON o.object_id = dc.parent_object_id
    WHERE o.name='122_ENT_REPORTOS_CANASTA' AND col.name='ID'
)
    ALTER TABLE [RR].[122_ENT_REPORTOS_CANASTA]
        ADD CONSTRAINT DF_122_CANASTA_REP_ID DEFAULT (NEWID()) FOR [ID];

IF NOT EXISTS (
    SELECT 1 FROM sys.default_constraints dc
    JOIN sys.columns col ON col.default_object_id = dc.object_id
    JOIN sys.objects o ON o.object_id = dc.parent_object_id
    WHERE o.name='122_ENT_REPORTOS_CANASTA' AND col.name='FECHA_EXTRACCION'
)
    ALTER TABLE [RR].[122_ENT_REPORTOS_CANASTA]
        ADD CONSTRAINT DF_122_CANASTA_REP_FEXT DEFAULT (GETDATE()) FOR [FECHA_EXTRACCION];

-- Si la tabla no existiera: CREATE desde cero
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name='122_ENT_REPORTOS_CANASTA' AND schema_id=SCHEMA_ID('RR') AND type='U')
BEGIN
    CREATE TABLE [RR].[122_ENT_REPORTOS_CANASTA]
    (
        [ID]                            [uniqueidentifier] NOT NULL CONSTRAINT DF_122_CANASTA_REP_ID   DEFAULT (NEWID()),
        [FECHACONCERTACION]             [date]             NOT NULL,
        [TITULOOBJETOREPORTO]           [varchar](18)      NOT NULL,
        [PRECIOUNITARIOTITULOS]         [numeric](19, 8)   NOT NULL,
        [NUMEROTITULOSOBJETOREPORTO]    [numeric](12, 0)   NOT NULL,
        [IMPORTEREPORTO]                [numeric](12, 0)   NOT NULL,
        [HAIRCUT]                       [numeric](4, 2)    NOT NULL,
        [FECHA_FIN_COLATERAL]           [date]             NOT NULL,
        [NUMEROIDENTIFICACIONOPERACION] [varchar](37)      NOT NULL,
        [NUM_ID_CANASTA]                [varchar](37)      NOT NULL,
        [SECCION]                       [varchar](2)       NOT NULL,
        [EMISION]                       [varchar](50)      NULL,
        [SERIE]                         [varchar](50)      NULL,
        [TIPOVALOR]                     [varchar](50)      NULL,
        [FECHA_INFO]                    [date]             NOT NULL,
        [FECHA_EXTRACCION]              [smalldatetime]    NOT NULL CONSTRAINT DF_122_CANASTA_REP_FEXT DEFAULT (GETDATE()),
        CONSTRAINT PK_RR_122_CANASTA_REPORTOS PRIMARY KEY CLUSTERED ([ID] ASC)
    ) ON [PRIMARY];
    PRINT '>> Creada SILVER.[RR].[122_ENT_REPORTOS_CANASTA] desde cero.';
END
ELSE
    PRINT '>> SILVER.[RR].[122_ENT_REPORTOS_CANASTA] lista.';
GO

/* ----------------------------------------------------------------------------
   02 - SILVER SP  [dbo].[122_ENT_REPORTOS_CANASTA]  (ORIGEN LMDA)
        Correccion: filtro DIARIO por FECHA_INFO (antes: FECHACONCERTACION, ventana mensual).
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[122_ENT_REPORTOS_CANASTA]
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
            @FechaInicio DATETIME=GETDATE(), @NombreJob NVARCHAR(128)='[122_ENT_REPORTOS_CANASTA]',
            @FechaDia DATE = CAST(@FechaSistema AS DATE);

    BEGIN TRY
        -- DIARIA: ventana delimitada por FECHA_INFO
        IF EXISTS (SELECT 1 FROM [SILVER].[RR].[122_ENT_REPORTOS_CANASTA] WHERE [FECHA_INFO] = @FechaDia)
        BEGIN
            DELETE FROM [SILVER].[RR].[122_ENT_REPORTOS_CANASTA] WHERE [FECHA_INFO] = @FechaDia;
            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage; SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13)+CHAR(10);
        END

        INSERT INTO [RR].[122_ENT_REPORTOS_CANASTA] (
            [FECHACONCERTACION],[TITULOOBJETOREPORTO],[PRECIOUNITARIOTITULOS],
            [NUMEROTITULOSOBJETOREPORTO],[IMPORTEREPORTO],[HAIRCUT],[FECHA_FIN_COLATERAL],
            [NUMEROIDENTIFICACIONOPERACION],[NUM_ID_CANASTA],[SECCION],
            [EMISION],[SERIE],[TIPOVALOR],[FECHA_INFO]
        )
        SELECT
            C.[FECHACONCERTACION], C.[TITULOOBJETOREPORTO], C.[PRECIOUNITARIOTITULOS],
            C.[NUMEROTITULOSOBJETOREPORTO], C.[IMPORTEREPORTO], C.[HAIRCUT], C.[FECHA_FIN_COLATERAL],
            C.[NUMEROIDENTIFICACIONOPERACION], C.[NUM_ID_CANASTA], C.[SECCION],
            C.[EMISION], C.[SERIE], C.[TIPOVALOR], C.[FECHA_INFO]
        FROM [BRONZE].[LMDA].[CANASTA_REPORTOS] C
        WHERE C.[FECHA_INFO] = @FechaDia;

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
PRINT '>> Creado/actualizado SILVER.dbo.[122_ENT_REPORTOS_CANASTA] (LMDA, filtro FECHA_INFO diario).';
GO

/* ----------------------------------------------------------------------------
   03 - ION SP  [dbo].[122_ENT_REPORTOS_CANASTA]  (entrega)
        14 cols del layout (ORDENES 3-16). Fechas en AAAA/MM/DD.
        Sin ID ni FECHA_EXTRACCION. Filtro DIARIO por FECHA_INFO.
        Correccion: filtro antes era FECHACONCERTACION = @FECHA.
   ---------------------------------------------------------------------------- */
USE [ION];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[122_ENT_REPORTOS_CANASTA]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    -- Fechas en AAAA/MM/DD (consideracion 12). Orden por ORDEN del layout (consideracion 14).
    SELECT
        FORMAT([FECHACONCERTACION],          'yyyy/MM/dd') AS FECHACONCERTACION,
        [TITULOOBJETOREPORTO]                              AS TITULOOBJETOREPORTO,
        [PRECIOUNITARIOTITULOS]                            AS PRECIOUNITARIOTITULOS,
        [NUMEROTITULOSOBJETOREPORTO]                       AS NUMEROTITULOSOBJETOREPORTO,
        [IMPORTEREPORTO]                                   AS IMPORTEREPORTO,
        [HAIRCUT]                                          AS HAIRCUT,
        FORMAT([FECHA_FIN_COLATERAL],        'yyyy/MM/dd') AS FECHA_FIN_COLATERAL,
        [NUMEROIDENTIFICACIONOPERACION]                    AS NUMEROIDENTIFICACIONOPERACION,
        [NUM_ID_CANASTA]                                   AS NUM_ID_CANASTA,
        [SECCION]                                          AS SECCION,
        [EMISION]                                          AS EMISION,
        [SERIE]                                            AS SERIE,
        [TIPOVALOR]                                        AS TIPOVALOR,
        FORMAT([FECHA_INFO],                 'yyyy/MM/dd') AS FECHA_INFO
    FROM [SILVER].[RR].[122_ENT_REPORTOS_CANASTA]
    WHERE [FECHA_INFO] = @FECHA;
END;
GO
PRINT '>> Creado/actualizado ION.dbo.[122_ENT_REPORTOS_CANASTA] (14 cols, filtro FECHA_INFO).';
GO

/* ----------------------------------------------------------------------------
   04 - ION.dbo.INDICE_REPORTES : asegurar registro 122
   ---------------------------------------------------------------------------- */
USE [ION];
GO
SET NOCOUNT ON;
IF EXISTS (SELECT 1 FROM dbo.INDICE_REPORTES WHERE numero = 122)
    UPDATE dbo.INDICE_REPORTES SET nombre='ENT_REPORTOS_CANASTA', frecuencia='Diaria' WHERE numero = 122;
ELSE
    INSERT INTO dbo.INDICE_REPORTES (numero,nombre,frecuencia,activo,nombre_archivo)
    VALUES (122,'ENT_REPORTOS_CANASTA','Diaria',0,NULL);
PRINT '>> Registro 122 verificado en ION.dbo.INDICE_REPORTES.';
GO
PRINT '>> Ajuste 122_ENT_REPORTOS_CANASTA completado.';
GO
