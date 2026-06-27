-- ============================================================
-- ROLLBACK  084_ENT_TENENCIA_PRECIO
-- ============================================================

-- ============================================================
-- SECTION R01 | Restaurar SP ION (con ID, FECHA_EXTRACCION, FECHA_REPORTE)
-- ============================================================
USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[084_ENT_TENENCIA_PRECIO]
    @FECHA DATE
AS
BEGIN
    DECLARE @FechaIni DATE = DATEADD(DAY, -((DATEPART(WEEKDAY, @FECHA) + 5) % 7), @FECHA);
    DECLARE @FechaFin DATE = DATEADD(DAY, 7, @FechaIni);

    SELECT
        [ID],
        [FECHA_EXTRACCION],
        [TITULO_OBJETO],
        [PRECIO_VAL_MERCADO],
        [CLASIFICACION_CONTABLE],
        [Restriccion],
        [Custodio],
        [FechaValor],
        [Cliente],
        [NoTitulosCliente],
        [NoTitulosCedidos],
        [NoTitulosGarantia],
        [FECHA_REPORTE]
    FROM [SILVER].[RR].[084_ENT_TENENCIA_PRECIO]
    WHERE [FECHA_REPORTE] >= @FechaIni AND [FECHA_REPORTE] < @FechaFin;
END;
GO

-- ============================================================
-- SECTION R02 | Restaurar SP SILVER (auto-referencia original)
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

    BEGIN TRY
        IF EXISTS (
            SELECT ID FROM [SILVER].[RR].[084_ENT_TENENCIA_PRECIO]
            WHERE [FECHA_REPORTE] >= @FechaIni AND [FECHA_REPORTE] < @FechaFin
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[084_ENT_TENENCIA_PRECIO]
            WHERE [FECHA_REPORTE] >= @FechaIni AND [FECHA_REPORTE] < @FechaFin;
            SET @FilasEliminadas = @@ROWCOUNT;
            PRINT 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
        END;

        INSERT INTO [RR].[084_ENT_TENENCIA_PRECIO] (
            [TITULO_OBJETO],[PRECIO_VAL_MERCADO],[CLASIFICACION_CONTABLE],
            [Restriccion],[Custodio],[FechaValor],[Cliente],
            [NoTitulosCliente],[NoTitulosCedidos],[NoTitulosGarantia],[FECHA_REPORTE]
        )
        SELECT
            [TITULO_OBJETO],[PRECIO_VAL_MERCADO],[CLASIFICACION_CONTABLE],
            [Restriccion],[Custodio],[FechaValor],[Cliente],
            [NoTitulosCliente],[NoTitulosCedidos],[NoTitulosGarantia],
            @FechaIni AS [FECHA_REPORTE]
        FROM [SILVER].[RR].[084_ENT_TENENCIA_PRECIO]
        WHERE [FECHA_REPORTE] >= @FechaIni AND [FECHA_REPORTE] < @FechaFin;

        SET @FilasInsertadas = @@ROWCOUNT;
        PRINT 'Filas: ' + CAST(@FilasInsertadas AS NVARCHAR(10));
    END TRY
    BEGIN CATCH
        SET @ExitoEjecucion = 0;
        SET @MensajeError = ERROR_MESSAGE();
        PRINT 'Error: ' + @MensajeError;
    END CATCH

    INSERT INTO dbo.LogSilverDiario (
        FechaEjecucion,FilasInsertadas,EstadoEjecucion,
        MensajeError,DetallesLog,NombreJob,ProgramadorJob
    ) VALUES (
        @FechaInicio,@FilasInsertadas,
        CASE WHEN @ExitoEjecucion=1 THEN 'Exitoso' ELSE 'Error' END,
        CASE WHEN @ExitoEjecucion=1 THEN NULL ELSE @MensajeError END,
        '',@NombreJob,@ProgramadorJob
    );
END;
GO

-- ============================================================
-- SECTION R03 | Revertir sp_rename en SILVER
-- ============================================================
USE [SILVER]
GO

IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='084_ENT_TENENCIA_PRECIO' AND COLUMN_NAME='TITULOOBJETO'
)
BEGIN
    EXEC sp_rename 'RR.[084_ENT_TENENCIA_PRECIO].TITULOOBJETO', 'TITULO_OBJETO', 'COLUMN';
    PRINT 'sp_rename TITULOOBJETO -> TITULO_OBJETO OK.';
END

IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='084_ENT_TENENCIA_PRECIO' AND COLUMN_NAME='FECHA_INFO'
)
BEGIN
    EXEC sp_rename 'RR.[084_ENT_TENENCIA_PRECIO].FECHA_INFO', 'FECHA_REPORTE', 'COLUMN';
    PRINT 'sp_rename FECHA_INFO -> FECHA_REPORTE OK.';
END
GO

-- ============================================================
-- SECTION R04 | BRONZE — DROP tabla (descomentar si no habia datos)
-- ============================================================
-- USE [BRONZE]
-- GO
-- IF OBJECT_ID('LMDA.TENENCIA_PRECIO','U') IS NOT NULL
--     DROP TABLE [LMDA].[TENENCIA_PRECIO];
-- GO
