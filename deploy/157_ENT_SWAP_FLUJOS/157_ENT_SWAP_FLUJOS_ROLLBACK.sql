-- ============================================================
-- ROLLBACK  157_ENT_SWAP_FLUJOS
-- ============================================================

-- ============================================================
-- SECTION R01 | Restaurar SP ION (versión original)
-- ============================================================
USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[157_ENT_SWAP_FLUJOS]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SELECT
        [ID],
        [FECHA_EXTRACCION],
        [CONT],
        [FECHA],
        [NU_ID],
        [IMP_BASE],
        [NU_FL_RE],
        [FEIN_FL_RE],
        [FEIN_VE_RE],
        [TIP_TAS_RE],
        [TAS_FIJ_RE],
        [TAS_REF_RE],
        [OP1_TAS_RE],
        [PT1_TAS_RE],
        [FE_REF_RE],
        [NU_FL_EN],
        [FE_IN_FLRE],
        [FE_VE_FLEN],
        [TIP_TAS_EN],
        [TAS_FIJ_EN],
        [TAS_REF_EN],
        [OP1_TAS_EN],
        [PT1_TAS_EN],
        [FE_REF_EN],
        [IMP_BA_EN],
        [IMP_BA_RE],
        [FEIN_FL_EN],
        [FEIN_VE_EN],
        [MODIFICA]
    FROM [SILVER].[RR].[157_ENT_SWAP_FLUJOS]
    WHERE [FECHA] = @FECHA;
END;
GO

-- ============================================================
-- SECTION R02 | Restaurar SP SILVER (versión original — self-select)
-- ============================================================
USE [SILVER]
GO

CREATE OR ALTER PROCEDURE [dbo].[157_ENT_SWAP_FLUJOS]
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
    DECLARE @NombreJob       NVARCHAR(128) = '[157_ENT_SWAP_FLUJOS]';
    DECLARE @FechaIni DATE, @FechaFin DATE;

    BEGIN TRY
        SET @FechaIni = DATEFROMPARTS(YEAR(@FechaSistema), MONTH(@FechaSistema), 1);
        SET @FechaFin = DATEADD(MONTH, 1, @FechaIni);

        IF EXISTS (
            SELECT ID FROM [SILVER].[RR].[157_ENT_SWAP_FLUJOS]
            WHERE [FECHA] = @FechaSistema
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[157_ENT_SWAP_FLUJOS]
            WHERE [FECHA] = @FechaSistema;
            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

        INSERT INTO [RR].[157_ENT_SWAP_FLUJOS] (
            [CONT],[FECHA],[NU_ID],[IMP_BASE],[NU_FL_RE],[FEIN_FL_RE],[FEIN_VE_RE],
            [TIP_TAS_RE],[TAS_FIJ_RE],[TAS_REF_RE],[OP1_TAS_RE],[PT1_TAS_RE],[FE_REF_RE],
            [NU_FL_EN],[FE_IN_FLRE],[FE_VE_FLEN],[TIP_TAS_EN],[TAS_FIJ_EN],[TAS_REF_EN],
            [OP1_TAS_EN],[PT1_TAS_EN],[FE_REF_EN],[IMP_BA_EN],[IMP_BA_RE],
            [FEIN_FL_EN],[FEIN_VE_EN],[MODIFICA]
        )
        SELECT
            [CONT],[FECHA],[NU_ID],[IMP_BASE],[NU_FL_RE],[FEIN_FL_RE],[FEIN_VE_RE],
            [TIP_TAS_RE],[TAS_FIJ_RE],[TAS_REF_RE],[OP1_TAS_RE],[PT1_TAS_RE],[FE_REF_RE],
            [NU_FL_EN],[FE_IN_FLRE],[FE_VE_FLEN],[TIP_TAS_EN],[TAS_FIJ_EN],[TAS_REF_EN],
            [OP1_TAS_EN],[PT1_TAS_EN],[FE_REF_EN],[IMP_BA_EN],[IMP_BA_RE],
            [FEIN_FL_EN],[FEIN_VE_EN],[MODIFICA]
        FROM [SILVER].[RR].[157_ENT_SWAP_FLUJOS]
        WHERE [FECHA] = @FechaSistema;

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

    SET @LogMessage = 'Proceso completado y registrado en la tabla de log.';
    PRINT @LogMessage;
END;
GO

-- ============================================================
-- SECTION R03 | Revertir estructura SILVER
--   R03a: DROP FECHAINFO
--   R03b: FEIN_FL_RE y FE_IN_FLRE -> NOT NULL
-- ============================================================
USE [SILVER]
GO

-- R03a: DROP FECHAINFO
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='157_ENT_SWAP_FLUJOS' AND COLUMN_NAME='FECHAINFO'
)
    ALTER TABLE [RR].[157_ENT_SWAP_FLUJOS] DROP COLUMN [FECHAINFO];
GO

USE [SILVER]
GO

-- R03b: revertir nullabilidad
ALTER TABLE [RR].[157_ENT_SWAP_FLUJOS] ALTER COLUMN [FEIN_FL_RE] date NOT NULL;
ALTER TABLE [RR].[157_ENT_SWAP_FLUJOS] ALTER COLUMN [FE_IN_FLRE] date NOT NULL;
GO

-- ============================================================
-- SECTION R04 | Eliminar tabla BRONZE.LMDA.SWAP_FLUJO
-- ============================================================
USE [BRONZE]
GO

IF OBJECT_ID('LMDA.[SWAP_FLUJO]', 'U') IS NOT NULL
    DROP TABLE [LMDA].[SWAP_FLUJO];
GO
