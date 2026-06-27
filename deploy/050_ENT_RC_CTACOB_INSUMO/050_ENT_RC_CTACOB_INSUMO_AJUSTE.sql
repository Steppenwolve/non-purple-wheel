-- ============================================================
-- AJUSTE  050_ENT_RC_CTACOB_INSUMO
-- Layout : LAYOUTS_RCS_v10_FILE_RC_CTACOB_INSUMO.xlsx
-- Periodo: Mensual | Origen: LMDA
-- ============================================================

-- ============================================================
-- SECTION 00 | Crear tabla BRONZE.LMDA.RC_CTACOB_INSUMO (nueva)
-- ============================================================
USE [BRONZE]
GO

IF OBJECT_ID('LMDA.[RC_CTACOB_INSUMO]', 'U') IS NULL
CREATE TABLE [LMDA].[RC_CTACOB_INSUMO]
(
    [ID]               uniqueidentifier NOT NULL DEFAULT NEWID(),
    [CONTRATO]         varchar(50)      NOT NULL,
    [NOMBRE]           varchar(50)      NOT NULL,
    [IMPORTE]          numeric(18,6)    NOT NULL,
    [MONEDA]           varchar(3)       NOT NULL,
    [CLAVE_BANXICO]    varchar(6)       NOT NULL,
    [FECHA_REPORTE]    date             NOT NULL,
    [FECHA_EXTRACCION] smalldatetime    NOT NULL DEFAULT GETDATE(),
    CONSTRAINT [PK_LMDA_RC_CTACOB_INSUMO] PRIMARY KEY ([ID])
);
GO

-- ============================================================
-- SECTION 01 | Ajuste estructura SILVER.RR.050_ENT_RC_CTACOB_INSUMO
--              IMPORTE: numeric(12,6) → numeric(18,6)
-- ============================================================
USE [SILVER]
GO

ALTER TABLE [RR].[050_ENT_RC_CTACOB_INSUMO]
    ALTER COLUMN [IMPORTE] numeric(18,6) NOT NULL;
GO

-- ============================================================
-- SECTION 02 | SP SILVER — corregir self-select
-- ============================================================
USE [SILVER]
GO

CREATE OR ALTER PROCEDURE [dbo].[050_ENT_RC_CTACOB_INSUMO]
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
    DECLARE @NombreJob       NVARCHAR(128) = '[050_ENT_RC_CTACOB_INSUMO]';
    DECLARE @FechaIni        DATE;
    DECLARE @FechaFin        DATE;

    BEGIN TRY
        SET @FechaIni = DATEFROMPARTS(YEAR(@FechaSistema), MONTH(@FechaSistema), 1);
        SET @FechaFin = DATEADD(MONTH, 1, @FechaIni);

        IF EXISTS (
            SELECT ID
            FROM [SILVER].[RR].[050_ENT_RC_CTACOB_INSUMO]
            WHERE [FECHA_REPORTE] >= @FechaIni
              AND [FECHA_REPORTE] <  @FechaFin
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[050_ENT_RC_CTACOB_INSUMO]
            WHERE [FECHA_REPORTE] >= @FechaIni
              AND [FECHA_REPORTE] <  @FechaFin;

            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

        INSERT INTO [RR].[050_ENT_RC_CTACOB_INSUMO]
        (
            [CONTRATO],
            [NOMBRE],
            [IMPORTE],
            [MONEDA],
            [CLAVE_BAN],
            [FECHA_REPORTE]
        )
        SELECT
            [CONTRATO],
            [NOMBRE],
            [IMPORTE],
            [MONEDA],
            [CLAVE_BANXICO],
            [FECHA_REPORTE]
        FROM [BRONZE].[LMDA].[RC_CTACOB_INSUMO]
        WHERE [FECHA_REPORTE] >= @FechaIni
          AND [FECHA_REPORTE] <  @FechaFin;

        SET @FilasInsertadas = @@ROWCOUNT;
        SET @LogMessage = 'Proceso completado. Filas totales: ' + CAST(@FilasInsertadas AS NVARCHAR(10));
        PRINT @LogMessage;
        SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);

    END TRY
    BEGIN CATCH
        SET @ExitoEjecucion = 0;
        SET @MensajeError   = ERROR_MESSAGE();
        SET @LogMessage     = 'Error durante la ejecución: ' + @MensajeError;
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
        SET @Cuerpo =
            'Se ha producido un error durante la ejecución de.' + @NombreJob + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) +
            'Detalles del Job:' + CHAR(13) + CHAR(10) +
            '- Nombre del Job: '         + ISNULL(@NombreJob,     'No especificado') + CHAR(13) + CHAR(10) +
            '- Programado por: '         + ISNULL(@ProgramadorJob, 'No especificado') + CHAR(13) + CHAR(10) +
            '- Fecha y hora de inicio: ' + CONVERT(VARCHAR, @FechaInicio,       120)  + CHAR(13) + CHAR(10) +
            '- Fecha y hora de fin: '    + CONVERT(VARCHAR, @FechaFinalizacion,  120)  + CHAR(13) + CHAR(10) +
            '- Duración: '               + @DuracionEjecucion + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) +
            'Mensaje de Error:' + CHAR(13) + CHAR(10) + @MensajeError + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) +
            'Log de Ejecución:' + CHAR(13) + CHAR(10) + @DetallesLog;

        BEGIN TRY
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = @PerfilCorreo,
                @recipients   = @CorreoNotificacion,
                @subject      = @Asunto,
                @body         = @Cuerpo,
                @body_format  = 'TEXT',
                @importance   = 'High';
            SET @LogMessage  = 'Alerta de error enviada exitosamente.';
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END TRY
        BEGIN CATCH
            SET @LogMessage  = 'Error al enviar alerta: ' + ERROR_MESSAGE();
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END CATCH
    END

    INSERT INTO dbo.LogSilverDiario
        (FechaEjecucion, FilasInsertadas, EstadoEjecucion, MensajeError, DetallesLog, NombreJob, ProgramadorJob)
    VALUES
        (@FechaInicio, @FilasInsertadas,
         CASE WHEN @ExitoEjecucion = 1 THEN 'Exitoso' ELSE 'Error' END,
         CASE WHEN @ExitoEjecucion = 1 THEN NULL      ELSE @MensajeError END,
         @DetallesLog, @NombreJob, @ProgramadorJob);

    SET @LogMessage = 'Proceso completado y registrado en la tabla de log.';
    PRINT @LogMessage;
END;
GO

-- ============================================================
-- SECTION 02 | SP ION — quitar ID/FECHA_EXTRACCION/FECHA_REPORTE,
--              respetar ORDEN 1-5, alias CLAVE_BANXICO
-- ============================================================
USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[050_ENT_RC_CTACOB_INSUMO]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @FechaIni DATE = DATEFROMPARTS(YEAR(@FECHA), MONTH(@FECHA), 1);
    DECLARE @FechaFin DATE = DATEADD(MONTH, 1, @FechaIni);

    SELECT
        T.[CONTRATO]   AS [CONTRATO],       -- ORDEN 1
        T.[NOMBRE]     AS [NOMBRE],         -- ORDEN 2
        T.[IMPORTE]    AS [IMPORTE],        -- ORDEN 3
        T.[MONEDA]     AS [MONEDA],         -- ORDEN 4
        T.[CLAVE_BAN]  AS [CLAVE_BANXICO]   -- ORDEN 5
    FROM [SILVER].[RR].[050_ENT_RC_CTACOB_INSUMO] T
    WHERE T.[FECHA_REPORTE] >= @FechaIni
      AND T.[FECHA_REPORTE] <  @FechaFin;
END;
GO
