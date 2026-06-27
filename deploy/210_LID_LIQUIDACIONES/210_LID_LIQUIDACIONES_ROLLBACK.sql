-- ============================================================
-- ROLLBACK  210_LID_LIQUIDACIONES
-- ============================================================

-- ============================================================
-- SECTION R01 | Restaurar SP ION (version original — filtro diario por FECHA_LIQ)
-- ============================================================
USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[210_LID_LIQUIDACIONES]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SELECT
        FORMAT([FECHA_LIQ],      'yyyy/MM/dd') AS [FECHA_LIQ],
        [HORA_LIQ],
        [TIPO_VALOR],
        [TIPO_OBLIGACION],
        [MONTO_PAGOS],
        [MONEDA],
        [ID_PAGOS],
        [FLAG_HORARIO],
        [ID_PAGOS_RET],
        FORMAT([FECHA_EST_PAGO], 'yyyy/MM/dd') AS [FECHA_EST_PAGO],
        [HORA_EST_PAGO],
        [PENALIZACION],
        [MOTIVO_RET],
        [ID_OPERACION],
        [CARACT_LIQUIDACION],
        FORMAT([FECHA_INFO],     'yyyy/MM/dd') AS [FECHA_INFO]
    FROM [SILVER].[RR].[210_LID_LIQUIDACIONES]
    WHERE [FECHA_LIQ] = @FECHA;
END;
GO

-- ============================================================
-- SECTION R02 | Restaurar SP SILVER (version original — filtro diario por FECHA_LIQ)
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

    DECLARE @MensajeError   NVARCHAR(MAX) = '';
    DECLARE @ExitoEjecucion BIT           = 1;
    DECLARE @FilasInsertadas INT          = 0;
    DECLARE @DetallesLog    NVARCHAR(MAX) = '';
    DECLARE @FechaInicio    DATETIME      = GETDATE();
    DECLARE @NombreJob      NVARCHAR(128) = '[210_LID_LIQUIDACIONES]';

    BEGIN TRY
        IF EXISTS (
            SELECT 1 FROM [SILVER].[RR].[210_LID_LIQUIDACIONES]
            WHERE [FECHA_LIQ] = @FechaSistema
        )
            DELETE FROM [SILVER].[RR].[210_LID_LIQUIDACIONES]
            WHERE [FECHA_LIQ] = @FechaSistema;

        INSERT INTO [RR].[210_LID_LIQUIDACIONES] (
            [FECHA_LIQ],[HORA_LIQ],[TIPO_VALOR],[TIPO_OBLIGACION],[MONTO_PAGOS],
            [MONEDA],[ID_PAGOS],[FLAG_HORARIO],[ID_PAGOS_RET],[FECHA_EST_PAGO],
            [HORA_EST_PAGO],[PENALIZACION],[MOTIVO_RET],[ID_OPERACION],[CARACT_LIQUIDACION],[FECHA_INFO]
        )
        SELECT
            [FECHA_LIQ],[HORA_LIQ],[TIPO_VALOR],[TIPO_OBLIGACION],[MONTO_PAGOS],
            [MONEDA],[ID_PAGOS],[FLAG_HORARIO],[ID_PAGOS_RET],[FECHA_EST_PAGO],
            [HORA_EST_PAGO],[PENALIZACION],[MOTIVO_RET],[ID_OPERACION],[CARACT_LIQUIDACION],[FECHA_INFO]
        FROM [BRONZE].[LMDA].[LID_LIQUIDACIONES]
        WHERE [FECHA_LIQ] = @FechaSistema;

        SET @FilasInsertadas = @@ROWCOUNT;
        SET @DetallesLog += 'Filas: ' + CAST(@FilasInsertadas AS NVARCHAR(10)) + CHAR(13) + CHAR(10);
    END TRY
    BEGIN CATCH
        SET @ExitoEjecucion = 0;
        SET @MensajeError   = ERROR_MESSAGE();
        SET @DetallesLog   += 'Error: ' + @MensajeError + CHAR(13) + CHAR(10);
    END CATCH

    INSERT INTO dbo.LogSilverDiario (
        FechaEjecucion, FilasInsertadas, EstadoEjecucion,
        MensajeError, DetallesLog, NombreJob, ProgramadorJob
    )
    VALUES (
        @FechaInicio, @FilasInsertadas,
        CASE WHEN @ExitoEjecucion = 1 THEN 'Exitoso' ELSE 'Error' END,
        CASE WHEN @ExitoEjecucion = 1 THEN NULL ELSE @MensajeError END,
        @DetallesLog, @NombreJob, @ProgramadorJob
    );
END;
GO

-- ============================================================
-- SECTION R03 | INDICE_REPORTES — restaurar frecuencia original
-- ============================================================
USE [ION]
GO

UPDATE [dbo].[INDICE_REPORTES]
SET [frecuencia] = 'Diaria'
WHERE [numero] = 210;
GO
