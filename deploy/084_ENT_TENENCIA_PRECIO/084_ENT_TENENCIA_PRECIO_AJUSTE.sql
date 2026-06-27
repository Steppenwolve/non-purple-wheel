-- ============================================================
-- AJUSTE  084_ENT_TENENCIA_PRECIO
-- Layout : CORE_LayoutTenenciaAdicional_v3.3_Layout_TENENCIA_PRECIO
-- Periodicidad : Semanal  |  Origen : LMDA (BRONZE.LMDA.TENENCIA_PRECIO)
-- Reporte      : FILE_TENENCIA_PRECIO
-- ============================================================

-- ============================================================
-- SECTION 00 | BRONZE.[LMDA].[TENENCIA_PRECIO]  — CREATE TABLE
-- ============================================================
USE [BRONZE]
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'LMDA' AND TABLE_NAME = 'TENENCIA_PRECIO'
)
BEGIN
    CREATE TABLE [LMDA].[TENENCIA_PRECIO] (
        [ID]                    uniqueidentifier NOT NULL CONSTRAINT [DF_LMDA_TENENCIA_PRECIO_ID] DEFAULT (NEWID()),
        [TITULOOBJETO]          varchar(18)      NOT NULL,
        [PRECIO_VAL_MERCADO]    numeric(19,8)    NOT NULL,
        [CLASIFICACION_CONTABLE] varchar(2)      NOT NULL,
        [Restriccion]           varchar(2)       NOT NULL,
        [Custodio]              varchar(6)       NOT NULL,
        [FechaValor]            numeric(1,0)     NOT NULL,
        [Cliente]               varchar(6)       NOT NULL,
        [NoTitulosCliente]      numeric(12,0)    NOT NULL,
        [NoTitulosCedidos]      numeric(12,0)    NOT NULL,
        [NoTitulosGarantia]     numeric(12,0)    NOT NULL,
        [FECHA_INFO]            date             NULL,
        [FECHA_EXTRACCION]      smalldatetime    NOT NULL CONSTRAINT [DF_LMDA_TENENCIA_PRECIO_FECHA_EXTRACCION] DEFAULT (GETDATE())
    );
    PRINT 'BRONZE.LMDA.TENENCIA_PRECIO creada.';
END
ELSE
    PRINT 'BRONZE.LMDA.TENENCIA_PRECIO ya existe — sin cambios.';
GO

-- ============================================================
-- SECTION 01 | SILVER.[RR].[084_ENT_TENENCIA_PRECIO]
--   01a: sp_rename TITULO_OBJETO -> TITULOOBJETO
--   01b: sp_rename FECHA_REPORTE -> FECHA_INFO
-- ============================================================
USE [SILVER]
GO

-- 01a: TITULO_OBJETO -> TITULOOBJETO
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='084_ENT_TENENCIA_PRECIO' AND COLUMN_NAME='TITULO_OBJETO'
)
BEGIN
    EXEC sp_rename 'RR.[084_ENT_TENENCIA_PRECIO].TITULO_OBJETO', 'TITULOOBJETO', 'COLUMN';
    PRINT 'sp_rename TITULO_OBJETO -> TITULOOBJETO OK.';
END
GO

-- 01b: FECHA_REPORTE -> FECHA_INFO
USE [SILVER]
GO
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='084_ENT_TENENCIA_PRECIO' AND COLUMN_NAME='FECHA_REPORTE'
)
BEGIN
    EXEC sp_rename 'RR.[084_ENT_TENENCIA_PRECIO].FECHA_REPORTE', 'FECHA_INFO', 'COLUMN';
    PRINT 'sp_rename FECHA_REPORTE -> FECHA_INFO OK.';
END
GO

-- ============================================================
-- SECTION 02 | SP SILVER — [dbo].[084_ENT_TENENCIA_PRECIO]
--   Origen      : BRONZE.LMDA.TENENCIA_PRECIO
--   Periodicidad: Semanal
--   Control LMDA: FECHA_INFO
-- ============================================================
USE [SILVER]
GO

CREATE OR ALTER PROCEDURE [dbo].[084_ENT_TENENCIA_PRECIO]
    @CorreoNotificacion NVARCHAR(255) = NULL,
    @PerfilCorreo       NVARCHAR(255) = NULL,
    @ProgramadorJob     NVARCHAR(128) = NULL,
    @FechaSistema       DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @MensajeError    NVARCHAR(MAX) = '';
    DECLARE @ExitoEjecucion  BIT           = 1;
    DECLARE @FilasInsertadas INT           = 0;
    DECLARE @LogMessage      NVARCHAR(MAX) = '';
    DECLARE @DetallesLog     NVARCHAR(MAX) = '';
    DECLARE @FechaInicio     DATETIME      = GETDATE();
    DECLARE @FilasEliminadas INT           = 0;
    DECLARE @NombreJob       NVARCHAR(128) = '[084_ENT_TENENCIA_PRECIO] ';

    DECLARE @FechaIni DATE = DATEADD(DAY, -((DATEPART(WEEKDAY, @FechaSistema) + 5) % 7), CAST(@FechaSistema AS DATE));
    DECLARE @FechaFin DATE = DATEADD(DAY, 7, @FechaIni);

	-- CORE_LayoutTenenciaAdicional_v3.3_Layout  
	-- Query
	
    BEGIN TRY 

        IF EXISTS (
            SELECT 1 FROM [SILVER].[RR].[084_ENT_TENENCIA_PRECIO]
            WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[084_ENT_TENENCIA_PRECIO]
            WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin;

            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

        INSERT INTO [RR].[084_ENT_TENENCIA_PRECIO] (
            [TITULOOBJETO],
            [PRECIO_VAL_MERCADO],
            [CLASIFICACION_CONTABLE],
            [Restriccion],
            [Custodio],
            [FechaValor],
            [Cliente],
            [NoTitulosCliente],
            [NoTitulosCedidos],
            [NoTitulosGarantia],
            [FECHA_INFO]
        )
        SELECT
            T.[TITULOOBJETO],
            T.[PRECIO_VAL_MERCADO],
            T.[CLASIFICACION_CONTABLE],
            T.[Restriccion],
            T.[Custodio],
            T.[FechaValor],
            T.[Cliente],
            T.[NoTitulosCliente],
            T.[NoTitulosCedidos],
            T.[NoTitulosGarantia],
            T.[FECHA_INFO]
        FROM [BRONZE].[LMDA].[TENENCIA_PRECIO] T
        WHERE T.[FECHA_INFO] >= @FechaIni AND T.[FECHA_INFO] < @FechaFin;

        SET @FilasInsertadas = @@ROWCOUNT;
        SET @LogMessage = 'Proceso completado. Filas totales: ' + CAST(@FilasInsertadas AS NVARCHAR(10));
        PRINT @LogMessage;
        SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);

    END TRY

    BEGIN CATCH
        SET @ExitoEjecucion = 0;
        SET @MensajeError   = ERROR_MESSAGE();
        SET @LogMessage     = 'Error durante la ejecucion: ' + @MensajeError;
        PRINT @LogMessage;
        SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
    END CATCH

    DECLARE @Asunto            NVARCHAR(255);
    DECLARE @Cuerpo            NVARCHAR(MAX);
    DECLARE @FechaFinalizacion DATETIME = GETDATE();
    DECLARE @DuracionEjecucion VARCHAR(20) =
        CAST(DATEDIFF(SECOND, @FechaInicio, @FechaFinalizacion) AS VARCHAR(10)) + ' segundos';

    IF @ExitoEjecucion = 0
        AND @CorreoNotificacion IS NOT NULL
        AND @PerfilCorreo IS NOT NULL
    BEGIN
        SET @Asunto = 'ALERTA: Error en ' + ISNULL(@NombreJob, 'Job Desconocido');
        SET @Cuerpo = 'Se ha producido un error durante la ejecucion de ' + @NombreJob + CHAR(13) + CHAR(10)
            + 'Mensaje de Error:' + CHAR(13) + CHAR(10) + @MensajeError + CHAR(13) + CHAR(10)
            + 'Log de Ejecucion:' + CHAR(13) + CHAR(10) + @DetallesLog;

        BEGIN TRY
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = @PerfilCorreo,
                @recipients   = @CorreoNotificacion,
                @subject      = @Asunto,
                @body         = @Cuerpo,
                @body_format  = 'TEXT',
                @importance   = 'High';
        END TRY
        BEGIN CATCH
            PRINT 'Error al enviar alerta: ' + ERROR_MESSAGE();
        END CATCH
    END

    INSERT INTO dbo.LogSilverDiario (
        FechaEjecucion, FilasInsertadas, EstadoEjecucion,
        MensajeError, DetallesLog, NombreJob, ProgramadorJob
    )
    VALUES (
        @FechaInicio,
        @FilasInsertadas,
        CASE WHEN @ExitoEjecucion = 1 THEN 'Exitoso' ELSE 'Error' END,
        CASE WHEN @ExitoEjecucion = 1 THEN NULL ELSE @MensajeError END,
        @DetallesLog,
        @NombreJob,
        @ProgramadorJob
    );

    PRINT 'Proceso completado y registrado en la tabla de log.';
END;
GO

-- ============================================================
-- SECTION 03 | SP ION — [dbo].[084_ENT_TENENCIA_PRECIO]
--   Columnas: ORDEN 1-11 del layout (incluye FECHA_INFO)
--   Sin ID ni FECHA_EXTRACCION
--   FECHA_INFO: FORMAT yyyy/MM/dd
--   Filtro semanal por FECHA_INFO
-- ============================================================
USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[084_ENT_TENENCIA_PRECIO]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @FechaIni DATE = DATEADD(DAY, -((DATEPART(WEEKDAY, @FECHA) + 5) % 7), @FECHA);
    DECLARE @FechaFin DATE = DATEADD(DAY, 7, @FechaIni);

    SELECT
        T.[TITULOOBJETO]                            AS [TITULOOBJETO],           -- ORDEN 1
        T.[PRECIO_VAL_MERCADO]                      AS [PRECIO_VAL_MERCADO],     -- ORDEN 2
        T.[CLASIFICACION_CONTABLE]                  AS [CLASIFICACION_CONTABLE], -- ORDEN 3
        T.[Restriccion]                             AS [Restriccion],            -- ORDEN 4
        T.[Custodio]                                AS [Custodio],               -- ORDEN 5
        T.[FechaValor]                              AS [FechaValor],             -- ORDEN 6
        T.[Cliente]                                 AS [Cliente],                -- ORDEN 7
        T.[NoTitulosCliente]                        AS [NoTitulosCliente],       -- ORDEN 8
        T.[NoTitulosCedidos]                        AS [NoTitulosCedidos],       -- ORDEN 9
        T.[NoTitulosGarantia]                       AS [NoTitulosGarantia],      -- ORDEN 10
        FORMAT(T.[FECHA_INFO], 'yyyy/MM/dd')        AS [FECHA_INFO]              -- ORDEN 11
    FROM [SILVER].[RR].[084_ENT_TENENCIA_PRECIO] T
    WHERE T.[FECHA_INFO] >= @FechaIni AND T.[FECHA_INFO] < @FechaFin;

END;
GO

-- ============================================================
-- SECTION 04 | INDICE_REPORTES — verificar
-- ============================================================
USE [ION]
GO

SELECT numero, nombre, frecuencia, activo, nombre_archivo
FROM dbo.INDICE_REPORTES
WHERE numero = 84;
GO
