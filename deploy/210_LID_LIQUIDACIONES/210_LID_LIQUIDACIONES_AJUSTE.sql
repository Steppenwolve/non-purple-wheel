-- ============================================================
-- AJUSTE  210_LID_LIQUIDACIONES
-- Layout : LAYOUT LID V4 LID LIQUIDACIONES
-- Periodicidad : Mensual  |  Origen : LMDA (BRONZE.LMDA.LID_LIQUIDACIONES)
-- Reporte      : LID LIQUIDACIONES
-- ============================================================

-- ============================================================
-- SECTION 00 | BRONZE.[LMDA].[LID_LIQUIDACIONES]  — verificar existencia
--   Tabla ya existe con estructura correcta — no se requieren cambios DDL
-- ============================================================
USE [BRONZE]
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'LMDA' AND TABLE_NAME = 'LID_LIQUIDACIONES'
)
BEGIN
    CREATE TABLE [LMDA].[LID_LIQUIDACIONES] (
        [ID]                 uniqueidentifier NOT NULL CONSTRAINT [DF_LMDA_LID_LIQUIDACIONES_ID] DEFAULT (NEWID()),
        [FECHA_LIQ]          date             NOT NULL,
        [HORA_LIQ]           varchar(5)       NOT NULL,
        [TIPO_VALOR]         numeric(2,0)     NOT NULL,
        [TIPO_OBLIGACION]    numeric(2,0)     NOT NULL,
        [MONTO_PAGOS]        numeric(12,0)    NOT NULL,
        [MONEDA]             varchar(3)       NOT NULL,
        [ID_PAGOS]           numeric(1,0)     NOT NULL,
        [FLAG_HORARIO]       numeric(1,0)     NOT NULL,
        [ID_PAGOS_RET]       numeric(1,0)     NOT NULL,
        [FECHA_EST_PAGO]     date             NOT NULL,
        [HORA_EST_PAGO]      varchar(5)       NOT NULL,
        [PENALIZACION]       numeric(12,0)    NOT NULL,
        [MOTIVO_RET]         numeric(2,0)     NOT NULL,
        [ID_OPERACION]       varchar(50)      NOT NULL,
        [CARACT_LIQUIDACION] numeric(2,0)     NOT NULL,
        [FECHA_INFO]         date             NOT NULL,
        [FECHA_EXTRACCION]   smalldatetime    NOT NULL CONSTRAINT [DF_LMDA_LID_LIQUIDACIONES_FECHA_EXTRACCION] DEFAULT (GETDATE())
    );
    PRINT 'BRONZE.LMDA.LID_LIQUIDACIONES creada.';
END
ELSE
    PRINT 'BRONZE.LMDA.LID_LIQUIDACIONES ya existe — sin cambios.';
GO

-- ============================================================
-- SECTION 01 | SILVER.[RR].[210_LID_LIQUIDACIONES]
--   Nombres de columnas ya coinciden con el layout — sin sp_rename
-- ============================================================
USE [SILVER]
GO

PRINT 'SECTION 01: SILVER.RR.210_LID_LIQUIDACIONES — estructura correcta, sin ajustes de columnas.';
GO

-- ============================================================
-- SECTION 02 | SP SILVER — [dbo].[210_LID_LIQUIDACIONES]
--   Origen      : BRONZE.LMDA.LID_LIQUIDACIONES
--   Periodicidad: Mensual
--   Control LMDA: FECHA_INFO  (ventana: primer dia del mes >= FECHA_INFO < primer dia del mes siguiente)
--   Correccion  : SP anterior filtraba FECHA_LIQ = @FechaSistema (diaria); se corrige a mensual por FECHA_INFO
-- ============================================================
USE [SILVER]
GO

CREATE OR ALTER PROCEDURE [dbo].[210_LID_LIQUIDACIONES]
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
    DECLARE @NombreJob       NVARCHAR(128) = '[210_LID_LIQUIDACIONES] ';

    -- Ventana mensual por FECHA_INFO
    DECLARE @FechaIni DATE = DATEFROMPARTS(YEAR(@FechaSistema), MONTH(@FechaSistema), 1);
    DECLARE @FechaFin DATE = DATEADD(MONTH, 1, @FechaIni);

    BEGIN TRY

        IF EXISTS (
            SELECT 1 FROM [SILVER].[RR].[210_LID_LIQUIDACIONES]
            WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[210_LID_LIQUIDACIONES]
            WHERE [FECHA_INFO] >= @FechaIni AND [FECHA_INFO] < @FechaFin;

            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

        INSERT INTO [RR].[210_LID_LIQUIDACIONES] (
            [FECHA_LIQ],
            [HORA_LIQ],
            [TIPO_VALOR],
            [TIPO_OBLIGACION],
            [MONTO_PAGOS],
            [MONEDA],
            [ID_PAGOS],
            [FLAG_HORARIO],
            [ID_PAGOS_RET],
            [FECHA_EST_PAGO],
            [HORA_EST_PAGO],
            [PENALIZACION],
            [MOTIVO_RET],
            [ID_OPERACION],
            [CARACT_LIQUIDACION],
            [FECHA_INFO]
        )
        SELECT
            T.[FECHA_LIQ],
            T.[HORA_LIQ],
            T.[TIPO_VALOR],
            T.[TIPO_OBLIGACION],
            T.[MONTO_PAGOS],
            T.[MONEDA],
            T.[ID_PAGOS],
            T.[FLAG_HORARIO],
            T.[ID_PAGOS_RET],
            T.[FECHA_EST_PAGO],
            T.[HORA_EST_PAGO],
            T.[PENALIZACION],
            T.[MOTIVO_RET],
            T.[ID_OPERACION],
            T.[CARACT_LIQUIDACION],
            T.[FECHA_INFO]
        FROM [BRONZE].[LMDA].[LID_LIQUIDACIONES] T
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
-- SECTION 03 | SP ION — [dbo].[210_LID_LIQUIDACIONES]
--   Columnas : ORDEN 1-16 del layout (incluye FECHA_INFO)
--   Sin ID ni FECHA_EXTRACCION
--   Fechas   : FORMAT yyyy/MM/dd — FECHA_LIQ (1), FECHA_EST_PAGO (10), FECHA_INFO (16)
--   Filtro   : ventana mensual por FECHA_INFO
--   Correccion: SP anterior filtraba FECHA_LIQ = @FECHA (diaria); se corrige a mensual por FECHA_INFO
-- ============================================================
USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[210_LID_LIQUIDACIONES]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    -- Ventana mensual por FECHA_INFO
    DECLARE @FechaIni DATE = DATEFROMPARTS(YEAR(@FECHA), MONTH(@FECHA), 1);
    DECLARE @FechaFin DATE = DATEADD(MONTH, 1, @FechaIni);

    SELECT
        FORMAT(T.[FECHA_LIQ],      'yyyy/MM/dd') AS [FECHA_LIQ],          -- ORDEN 1
        T.[HORA_LIQ]                             AS [HORA_LIQ],            -- ORDEN 2
        T.[TIPO_VALOR]                           AS [TIPO_VALOR],           -- ORDEN 3
        T.[TIPO_OBLIGACION]                      AS [TIPO_OBLIGACION],      -- ORDEN 4
        T.[MONTO_PAGOS]                          AS [MONTO_PAGOS],          -- ORDEN 5
        T.[MONEDA]                               AS [MONEDA],               -- ORDEN 6
        T.[ID_PAGOS]                             AS [ID_PAGOS],             -- ORDEN 7
        T.[FLAG_HORARIO]                         AS [FLAG_HORARIO],         -- ORDEN 8
        T.[ID_PAGOS_RET]                         AS [ID_PAGOS_RET],         -- ORDEN 9
        FORMAT(T.[FECHA_EST_PAGO], 'yyyy/MM/dd') AS [FECHA_EST_PAGO],      -- ORDEN 10
        T.[HORA_EST_PAGO]                        AS [HORA_EST_PAGO],        -- ORDEN 11
        T.[PENALIZACION]                         AS [PENALIZACION],         -- ORDEN 12
        T.[MOTIVO_RET]                           AS [MOTIVO_RET],           -- ORDEN 13
        T.[ID_OPERACION]                         AS [ID_OPERACION],         -- ORDEN 14
        T.[CARACT_LIQUIDACION]                   AS [CARACT_LIQUIDACION],   -- ORDEN 15
        FORMAT(T.[FECHA_INFO],     'yyyy/MM/dd') AS [FECHA_INFO]            -- ORDEN 16
    FROM [SILVER].[RR].[210_LID_LIQUIDACIONES] T
    WHERE T.[FECHA_INFO] >= @FechaIni AND T.[FECHA_INFO] < @FechaFin;

END;
GO

-- ============================================================
-- SECTION 04 | INDICE_REPORTES — corregir frecuencia Diaria -> Mensual
-- ============================================================
USE [ION]
GO

UPDATE [dbo].[INDICE_REPORTES]
SET [frecuencia] = 'Mensual'
WHERE [numero] = 210;

SELECT numero, nombre, frecuencia, activo, nombre_archivo
FROM dbo.INDICE_REPORTES
WHERE numero = 210;
GO
