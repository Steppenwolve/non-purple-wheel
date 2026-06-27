-- ============================================================
-- AJUSTE  209_LID_CORRESPONSALES
-- Layout : LAYOUT LID V4 LID CORRESPONSALES
-- Periodicidad : Mensual  |  Origen : LMDA (BRONZE.LMDA.LID_CORRESPONSALES)
-- Reporte      : LID CORRESPONSALES
-- Objetos nuevos en todas las capas — sin sp_rename
-- ============================================================

-- ============================================================
-- SECTION 00 | BRONZE.[LMDA].[LID_CORRESPONSALES]  — CREATE TABLE
-- ============================================================
USE [BRONZE]
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'LMDA' AND TABLE_NAME = 'LID_CORRESPONSALES'
)
BEGIN
    CREATE TABLE [LMDA].[LID_CORRESPONSALES] (
        [ID]                 uniqueidentifier NOT NULL CONSTRAINT [DF_LMDA_LID_CORRESPONSALES_ID] DEFAULT (NEWID()),
        [FECHA_LIQ]          date             NOT NULL,
        [HORA_LIQ]           varchar(5)       NOT NULL,
        [TIPO_VALOR]         numeric(2,0)     NOT NULL,
        [MONTO_PAGOS]        numeric(12,0)    NOT NULL,
        [MONEDA]             varchar(3)       NOT NULL,
        [ID_PAGOS_REAL]      numeric(2,0)     NOT NULL,
        [CONT_CORRESPONSAL]  varchar(6)       NOT NULL,
        [CONT_RECEPTORA]     varchar(6)       NOT NULL,
        [CARACT_LIQUIDACION] numeric(2,0)     NOT NULL,
        [FECHA_INFO]         date             NOT NULL,
        [FECHA_EXTRACCION]   smalldatetime    NOT NULL CONSTRAINT [DF_LMDA_LID_CORRESPONSALES_FECHA_EXTRACCION] DEFAULT (GETDATE())
    );
    PRINT 'BRONZE.LMDA.LID_CORRESPONSALES creada.';
END
ELSE
    PRINT 'BRONZE.LMDA.LID_CORRESPONSALES ya existe — sin cambios.';
GO

-- ============================================================
-- SECTION 01 | SILVER.[RR].[209_LID_CORRESPONSALES]  — CREATE TABLE
--   Objeto nuevo — no se requiere sp_rename
-- ============================================================
USE [SILVER]
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'RR' AND TABLE_NAME = '209_LID_CORRESPONSALES'
)
BEGIN
    CREATE TABLE [RR].[209_LID_CORRESPONSALES] (
        [ID]                 uniqueidentifier NOT NULL CONSTRAINT [DF_RR_209_LID_CORRESPONSALES_ID] DEFAULT (NEWID()),
        [FECHA_LIQ]          date             NOT NULL,
        [HORA_LIQ]           varchar(5)       NOT NULL,
        [TIPO_VALOR]         numeric(2,0)     NOT NULL,
        [MONTO_PAGOS]        numeric(12,0)    NOT NULL,
        [MONEDA]             varchar(3)       NOT NULL,
        [ID_PAGOS_REAL]      numeric(2,0)     NOT NULL,
        [CONT_CORRESPONSAL]  varchar(6)       NOT NULL,
        [CONT_RECEPTORA]     varchar(6)       NOT NULL,
        [CARACT_LIQUIDACION] numeric(2,0)     NOT NULL,
        [FECHA_INFO]         date             NOT NULL,
        [FECHA_EXTRACCION]   smalldatetime    NOT NULL CONSTRAINT [DF_RR_209_LID_CORRESPONSALES_FECHA_EXTRACCION] DEFAULT (GETDATE())
    );
    PRINT 'SILVER.RR.209_LID_CORRESPONSALES creada.';
END
ELSE
    PRINT 'SILVER.RR.209_LID_CORRESPONSALES ya existe — sin cambios.';
GO

-- ============================================================
-- SECTION 02 | SP SILVER — [dbo].[209_LID_CORRESPONSALES]
--   Origen      : BRONZE.LMDA.LID_CORRESPONSALES
--   Periodicidad: Mensual
--   Control LMDA: FECHA_INFO  (ventana: primer dia del mes >= FECHA_INFO < primer dia del mes siguiente)
-- ============================================================
USE [SILVER]
GO

CREATE OR ALTER PROCEDURE [dbo].[209_LID_CORRESPONSALES]
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
    DECLARE @NombreJob       NVARCHAR(128) = '[209_LID_CORRESPONSALES] ';

    -- Ventana mensual por FECHA_INFO
    DECLARE @FechaIni DATE = DATEFROMPARTS(YEAR(@FechaSistema), MONTH(@FechaSistema), 1);
    DECLARE @FechaFin DATE = DATEADD(MONTH, 1, @FechaIni);

    BEGIN TRY

        IF EXISTS (
            SELECT 1 FROM [SILVER].[RR].[209_LID_CORRESPONSALES]
            WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[209_LID_CORRESPONSALES]
            WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin;

            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

        INSERT INTO [RR].[209_LID_CORRESPONSALES] (
            [FECHA_LIQ],
            [HORA_LIQ],
            [TIPO_VALOR],
            [MONTO_PAGOS],
            [MONEDA],
            [ID_PAGOS_REAL],
            [CONT_CORRESPONSAL],
            [CONT_RECEPTORA],
            [CARACT_LIQUIDACION],
            [FECHA_INFO]
        )
        SELECT
            T.[FECHA_LIQ],
            T.[HORA_LIQ],
            T.[TIPO_VALOR],
            T.[MONTO_PAGOS],
            T.[MONEDA],
            T.[ID_PAGOS_REAL],
            T.[CONT_CORRESPONSAL],
            T.[CONT_RECEPTORA],
            T.[CARACT_LIQUIDACION],
            T.[FECHA_INFO]
        FROM [BRONZE].[LMDA].[LID_CORRESPONSALES] T
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
-- SECTION 03 | SP ION — [dbo].[209_LID_CORRESPONSALES]
--   Columnas : ORDEN 1-10 del layout (incluye FECHA_INFO)
--   Sin ID ni FECHA_EXTRACCION
--   Fechas   : FORMAT yyyy/MM/dd — FECHA_LIQ (1), FECHA_INFO (10)
--   Filtro   : ventana mensual por FECHA_INFO
-- ============================================================
USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[209_LID_CORRESPONSALES]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    -- Ventana mensual por FECHA_INFO
    DECLARE @FechaIni DATE = DATEFROMPARTS(YEAR(@FECHA), MONTH(@FECHA), 1);
    DECLARE @FechaFin DATE = DATEADD(MONTH, 1, @FechaIni);

    SELECT
        FORMAT(T.[FECHA_LIQ],  'yyyy/MM/dd') AS [FECHA_LIQ],          -- ORDEN 1
        T.[HORA_LIQ]                         AS [HORA_LIQ],            -- ORDEN 2
        T.[TIPO_VALOR]                       AS [TIPO_VALOR],           -- ORDEN 3
        T.[MONTO_PAGOS]                      AS [MONTO_PAGOS],          -- ORDEN 4
        T.[MONEDA]                           AS [MONEDA],               -- ORDEN 5
        T.[ID_PAGOS_REAL]                    AS [ID_PAGOS_REAL],        -- ORDEN 6
        T.[CONT_CORRESPONSAL]                AS [CONT_CORRESPONSAL],    -- ORDEN 7
        T.[CONT_RECEPTORA]                   AS [CONT_RECEPTORA],       -- ORDEN 8
        T.[CARACT_LIQUIDACION]               AS [CARACT_LIQUIDACION],   -- ORDEN 9
        FORMAT(T.[FECHA_INFO], 'yyyy/MM/dd') AS [FECHA_INFO]            -- ORDEN 10
    FROM [SILVER].[RR].[209_LID_CORRESPONSALES] T
    WHERE T.[FECHA_INFO] >= @FechaIni AND T.[FECHA_INFO] < @FechaFin;

END;
GO

-- ============================================================
-- SECTION 04 | INDICE_REPORTES — INSERT nuevo registro 209
-- ============================================================
USE [ION]
GO

IF NOT EXISTS (SELECT 1 FROM dbo.INDICE_REPORTES WHERE numero = 209)
BEGIN
    INSERT INTO dbo.INDICE_REPORTES (numero, nombre, frecuencia, activo, nombre_archivo)
    VALUES (209, 'LID_CORRESPONSALES', 'Mensual', 0, NULL);
    PRINT 'INDICE_REPORTES: registro 209 insertado.';
END
ELSE
BEGIN
    UPDATE dbo.INDICE_REPORTES
    SET frecuencia = 'Mensual', nombre = 'LID_CORRESPONSALES'
    WHERE numero = 209;
    PRINT 'INDICE_REPORTES: registro 209 actualizado.';
END

SELECT numero, nombre, frecuencia, activo, nombre_archivo
FROM dbo.INDICE_REPORTES
WHERE numero = 209;
GO
