-- ============================================================
-- ROLLBACK  125_ENT_ACLME
-- Revierte lo aplicado por 125_ENT_ACLME_AJUSTE.sql:
--   * Restaura el SP SILVER a su definicion original (stub prod)
--   * Restaura el SP ION a su definicion original (passthrough)
--   * Elimina el registro 125 de INDICE_REPORTES
-- NO se tocan las tablas (BRONZE.LMDA.ACLME / SILVER.RR.125_ENT_ACLME)
-- ni los datos cargados; ya existian antes del ajuste.
-- ============================================================

-- ------------------------------------------------------------
-- SP SILVER — restaurar stub original
-- ------------------------------------------------------------
USE [SILVER]
GO
CREATE OR ALTER PROCEDURE [dbo].[125_ENT_ACLME]
    @CorreoNotificacion NVARCHAR(255) = NULL,
    @PerfilCorreo       NVARCHAR(255) = NULL,
    @ProgramadorJob     NVARCHAR(128) = NULL,
    @FechaSistema       DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @MensajeError NVARCHAR(MAX) = '';
    DECLARE @ExitoEjecucion BIT = 1;
    DECLARE @FilasInsertadas INT = 0;
    DECLARE @LogMessage NVARCHAR(MAX) = '';
    DECLARE @DetallesLog NVARCHAR(MAX) = '';
    DECLARE @FechaInicio DATETIME = GETDATE();
    DECLARE @FilasEliminadas INT = 0;
    DECLARE @NombreJob NVARCHAR(128) = '[125_ENT_ACLME] ';
    DECLARE @FechaIni DATE, @FechaFin DATE;

    BEGIN TRY
        SET @FechaIni = datefromparts(year(@FechaSistema), month(@FechaSistema), 1);
        SET @FechaFin = Dateadd(month, 1, @FechaIni);

        IF EXISTS (SELECT ID FROM [SILVER].[RR].[125_ENT_ACLME] WHERE [FECHA_INFO] = @FechaSistema)
        BEGIN
            DELETE FROM [SILVER].[RR].[125_ENT_ACLME] WHERE [FECHA_INFO] = @FechaSistema;
            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

        INSERT INTO [RR].[125_ENT_ACLME] (
            [TIPO_OPERACION], [AMORTIZACION], [IMPORTE_AMORTIZACION], [FECHA_AMORTIZACION],
            [NUMERO_IDENTIFICACION], [MONEDA], [RESERVAS], [FECHA_INFO])
        SELECT [TIPO_OPERACION], [AMORTIZACION], [IMPORTE_AMORTIZACION], [FECHA_AMORTIZACION],
            [NUMERO_IDENTIFICACION], [MONEDA], [RESERVAS], [FECHA_INFO]
        FROM [SILVER].[RR].[125_ENT_ACLME]
        WHERE [FECHA_INFO] = @FechaSistema;

        SET @FilasInsertadas = @@ROWCOUNT;
        SET @LogMessage = 'Proceso completado. Filas totales: ' + CAST(@FilasInsertadas AS NVARCHAR(10));
        PRINT @LogMessage;
        SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
    END TRY
    BEGIN CATCH
        SET @ExitoEjecucion = 0;
        SET @MensajeError = ERROR_MESSAGE();
        SET @LogMessage = 'Error durante la ejecución: ' + @MensajeError;
        PRINT @LogMessage;
        SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
    END CATCH

    INSERT INTO dbo.LogSilverDiario (FechaEjecucion, FilasInsertadas, EstadoEjecucion, MensajeError, DetallesLog, NombreJob, ProgramadorJob)
    VALUES (@FechaInicio, @FilasInsertadas,
            CASE WHEN @ExitoEjecucion = 1 THEN 'Exitoso' ELSE 'Error' END,
            CASE WHEN @ExitoEjecucion = 1 THEN NULL ELSE @MensajeError END,
            @DetallesLog, @NombreJob, @ProgramadorJob);
    PRINT 'Proceso completado y registrado en la tabla de log.';
END;
GO

-- ------------------------------------------------------------
-- SP ION — restaurar passthrough original
-- ------------------------------------------------------------
USE [ION]
GO
CREATE OR ALTER PROCEDURE [dbo].[125_ENT_ACLME]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SELECT
        [ID],
        [FECHA_EXTRACCION],
        [TIPO_OPERACION],
        [AMORTIZACION],
        [IMPORTE_AMORTIZACION],
        [FECHA_AMORTIZACION],
        [NUMERO_IDENTIFICACION],
        [MONEDA],
        [RESERVAS],
        [FECHA_INFO]
    FROM [SILVER].[RR].[125_ENT_ACLME]
    WHERE [FECHA_INFO] = @FECHA;
END;
GO

-- ------------------------------------------------------------
-- INDICE_REPORTES — quitar registro 125
-- ------------------------------------------------------------
USE [ION]
GO
DELETE FROM [dbo].[INDICE_REPORTES] WHERE [numero] = 125;
GO

-- ------------------------------------------------------------
-- Catálogo — eliminar tabla creada por el ajuste
-- ------------------------------------------------------------
USE [BRONZE]
GO
IF OBJECT_ID('[RR].[CATALOGO_TIPO_OPERACION_ACLME]', 'U') IS NOT NULL
    DROP TABLE [RR].[CATALOGO_TIPO_OPERACION_ACLME];
GO
