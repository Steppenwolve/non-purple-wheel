-- ============================================================
-- AJUSTE  211_SECCION_1_LID
-- Layout : LAYOUT LID V4 LID SI  (hoja LID S1)
-- Periodicidad : Diaria  |  Origen : LMDA (BRONZE.LMDA.SECCION_1_LID)
-- Reporte      : LID SI
-- Objetos      : reporte NUEVO — se crea desde cero (no existe en prod)
-- ============================================================

-- ============================================================
-- SECTION 00 | BRONZE.[LMDA].[SECCION_1_LID] — crear tabla de aterrizaje
-- ============================================================
USE [BRONZE]
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'LMDA' AND TABLE_NAME = 'SECCION_1_LID'
)
BEGIN
    CREATE TABLE [LMDA].[SECCION_1_LID] (
        [ID]               uniqueidentifier NOT NULL CONSTRAINT [DF_LMDA_SECCION_1_LID_ID] DEFAULT (NEWID()),
        [TIPO_ACTIVO]      numeric(2,0)     NOT NULL,   -- ORDEN 1  catalogo Tipo_Activo_LID
        [SALDO_ID]         numeric(12,0)    NOT NULL,   -- ORDEN 2
        [MONEDA]           varchar(3)       NOT NULL,   -- ORDEN 3  catalogo Moneda ISO
        [FECHA_INFO]       date             NOT NULL,   -- ORDEN 4
        [FECHA_EXTRACCION] smalldatetime    NOT NULL CONSTRAINT [DF_LMDA_SECCION_1_LID_FECHA_EXTRACCION] DEFAULT (GETDATE())
    );
    PRINT 'BRONZE.LMDA.SECCION_1_LID creada.';
END
ELSE
    PRINT 'BRONZE.LMDA.SECCION_1_LID ya existe — sin cambios.';
GO

-- ============================================================
-- SECTION 01 | SILVER.[RR].[211_SECCION_1_LID] — crear tabla destino
-- ============================================================
USE [SILVER]
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'RR' AND TABLE_NAME = '211_SECCION_1_LID'
)
BEGIN
    CREATE TABLE [RR].[211_SECCION_1_LID] (
        [ID]               uniqueidentifier NOT NULL CONSTRAINT [DF_RR_211_SECCION_1_LID_ID] DEFAULT (NEWID()),
        [TIPO_ACTIVO]      numeric(2,0)     NOT NULL,
        [SALDO_ID]         numeric(12,0)    NOT NULL,
        [MONEDA]           varchar(3)       NOT NULL,
        [FECHA_INFO]       date             NOT NULL,
        [FECHA_EXTRACCION] smalldatetime    NOT NULL CONSTRAINT [DF_RR_211_SECCION_1_LID_FECHA_EXTRACCION] DEFAULT (GETDATE())
    );
    PRINT 'SILVER.RR.211_SECCION_1_LID creada.';
END
ELSE
    PRINT 'SILVER.RR.211_SECCION_1_LID ya existe — sin cambios.';
GO

-- ============================================================
-- SECTION 02 | SP SILVER — [dbo].[211_SECCION_1_LID]
--   Origen      : BRONZE.LMDA.SECCION_1_LID
--   Periodicidad: Diaria
--   Control LMDA: FECHA_INFO  (ventana: [dia, dia+1) )
-- ============================================================
USE [SILVER]
GO

CREATE OR ALTER PROCEDURE [dbo].[211_SECCION_1_LID]
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
    DECLARE @NombreJob       NVARCHAR(128) = '[211_SECCION_1_LID]';

    -- Ventana diaria por FECHA_INFO
    DECLARE @FechaIni DATE = CAST(@FechaSistema AS DATE);
    DECLARE @FechaFin DATE = DATEADD(DAY, 1, @FechaIni);

    BEGIN TRY

        IF EXISTS (
            SELECT 1 FROM [SILVER].[RR].[211_SECCION_1_LID]
            WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[211_SECCION_1_LID]
            WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin;

            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

        INSERT INTO [RR].[211_SECCION_1_LID] (
            [TIPO_ACTIVO],
            [SALDO_ID],
            [MONEDA],
            [FECHA_INFO]
        )
        SELECT
            T.[TIPO_ACTIVO],
            T.[SALDO_ID],
            T.[MONEDA],
            T.[FECHA_INFO]
        FROM [BRONZE].[LMDA].[SECCION_1_LID] T
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
-- SECTION 03 | SP ION — [dbo].[211_SECCION_1_LID]
--   Columnas : ORDEN 1-4 del layout
--   Sin ID ni FECHA_EXTRACCION
--   Fecha    : FORMAT yyyy/MM/dd — FECHA_INFO (ORDEN 4)
--   Filtro   : ventana diaria por FECHA_INFO
-- ============================================================
USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[211_SECCION_1_LID]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    -- Ventana diaria por FECHA_INFO
    DECLARE @FechaIni DATE = CAST(@FECHA AS DATE);
    DECLARE @FechaFin DATE = DATEADD(DAY, 1, @FechaIni);

    SELECT
        T.[TIPO_ACTIVO]                       AS [TIPO_ACTIVO],   -- ORDEN 1
        T.[SALDO_ID]                          AS [SALDO_ID],      -- ORDEN 2
        T.[MONEDA]                            AS [MONEDA],        -- ORDEN 3
        FORMAT(T.[FECHA_INFO], 'yyyy/MM/dd')  AS [FECHA_INFO]     -- ORDEN 4
    FROM [SILVER].[RR].[211_SECCION_1_LID] T
    WHERE T.[FECHA_INFO] >= @FechaIni AND T.[FECHA_INFO] < @FechaFin;

END;
GO

-- ============================================================
-- SECTION 04 | INDICE_REPORTES — registrar reporte 211 (Diaria)
-- ============================================================
USE [ION]
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[INDICE_REPORTES] WHERE [numero] = 211)
    INSERT INTO [dbo].[INDICE_REPORTES] ([numero], [nombre], [frecuencia], [activo], [nombre_archivo])
    VALUES (211, 'LID SI', 'Diaria', 1, 'SECCION_1_LID');

SELECT numero, nombre, frecuencia, activo, nombre_archivo
FROM dbo.INDICE_REPORTES
WHERE numero = 211;
GO
