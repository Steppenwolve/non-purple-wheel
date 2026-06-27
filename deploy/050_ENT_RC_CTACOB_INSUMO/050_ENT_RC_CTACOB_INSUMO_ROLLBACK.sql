-- ============================================================
-- ROLLBACK  050_ENT_RC_CTACOB_INSUMO
-- ============================================================

-- ============================================================
-- SECTION R01 | Restaurar SP ION (versión original)
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
        [ID],
        [CONTRATO],
        [NOMBRE],
        [IMPORTE],
        [MONEDA],
        [CLAVE_BAN],
        [FECHA_REPORTE],
        [FECHA_EXTRACCION]
    FROM [SILVER].[RR].[050_ENT_RC_CTACOB_INSUMO]
    WHERE [FECHA_REPORTE] >= @FechaIni
      AND [FECHA_REPORTE] <  @FechaFin;
END;
GO

-- ============================================================
-- SECTION R02 | Restaurar SP SILVER (versión original — self-select)
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

    DECLARE @SQL             NVARCHAR(MAX);
    DECLARE @MensajeError    NVARCHAR(MAX) = '';
    DECLARE @ExitoEjecucion  BIT           = 1;
    DECLARE @FilasInsertadas INT           = 0;
    DECLARE @LogMessage      NVARCHAR(MAX) = '';
    DECLARE @DetallesLog     NVARCHAR(MAX) = '';
    DECLARE @FechaInicio     DATETIME      = GETDATE();
    DECLARE @FilasEliminadas INT           = 0;
    DECLARE @NombreJob       NVARCHAR(128) = '[050_ENT_RC_CTACOB_INSUMO] ';
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
            [CLAVE_BAN],
            @FechaIni AS [FECHA_REPORTE]
        FROM [SILVER].[RR].[050_ENT_RC_CTACOB_INSUMO]
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
-- SECTION R03 | Revertir IMPORTE SILVER a numeric(12,6)
-- ============================================================
USE [SILVER]
GO

ALTER TABLE [RR].[050_ENT_RC_CTACOB_INSUMO]
    ALTER COLUMN [IMPORTE] numeric(12,6) NOT NULL;
GO

-- ============================================================
-- SECTION R04 | Eliminar tabla BRONZE.LMDA.RC_CTACOB_INSUMO
-- ============================================================
USE [BRONZE]
GO

IF OBJECT_ID('LMDA.[RC_CTACOB_INSUMO]', 'U') IS NOT NULL
    DROP TABLE [LMDA].[RC_CTACOB_INSUMO];
GO
