-- ============================================================
-- ROLLBACK  154_ENT_SWAPS
-- ============================================================

-- ============================================================
-- SECTION R01 | Restaurar SP ION (versión original)
-- ============================================================
USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[154_ENT_SWAPS]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SELECT
        [ID], [FECHA_EXTRACCION],
        [OFICINA], [CONT], [FE_CON_OPE],
        [FE1_FLU_RE], [FEN_FLU_RE], [FE1_FLU_EN], [FEN_FLU_EN],
        [TIP_DER], [OBJ_OPE], [REV_SWAP], [DET_FLUJO],
        [IMP_BASE], [MDA_IMP], [LIQ_FLU],
        [NU_FLU_RE], [NU_FLU_EN], [INT_FLU_RE], [INT_FLU_EN],
        [TIP_TAS_RE], [TAS_FIJ_RE], [TAS_REF_RE], [REV_TREF_RE],
        [ANIO_RE], [FE_REF_RE], [FA1_TAS_RE], [OP1_TAS_RE], [PT1_TAS_RE],
        [TIP_TAS_EN], [TAS_FIJ_EN], [TAS_REF_EN], [REV_TREF_EN],
        [ANIO_EN], [FE_REF_EN], [FA1_TAS_EN], [OP1_TAS_EN], [PT1_TAS_EN],
        [CUO_COMP], [VEN_ANT], [TER_OPE], [PAQ_EST], [ID_PAQ_EST], [CON_PAQ_EST],
        [BROKER], [SOCIO_LIQ], [CAM_COM], [AG_CAL], [NUM_CONF],
        [NU_ID], [NUM_ID_OP_SBY], [MODIFICA],
        [INTERC_IMP], [IMP_BA_RE], [MDA_IMP_RE], [IMP_BA_EN], [MDA_IMP_EN],
        [PRO_TER], [FECVEN_A], [FECLIQ_A], [IMP_VEN], [MDA_VEN],
        [VTOT_IMPE], [VPAR_IMPR], [VPAR_IMPE],
        [PAG_VENA], [MOT_VENA], [VEN_ANT_CD], [NUM_ID_CP],
        [SEC_SWAP], [CONT_2], [FE_CON_OPE_2],
        [UTI_N], [UTI], [UPI]
    FROM [SILVER].[RR].[154_ENT_SWAPS]
    WHERE [FE_CON_OPE] = @FECHA;
END;
GO

-- ============================================================
-- SECTION R02 | Restaurar SP SILVER (versión original — self-select)
-- ============================================================
USE [SILVER]
GO

CREATE OR ALTER PROCEDURE [dbo].[154_ENT_SWAPS]
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
    DECLARE @NombreJob       NVARCHAR(128) = '[154_ENT_SWAPS]';
    DECLARE @FechaIni DATE, @FechaFin DATE;

    BEGIN TRY
        SET @FechaIni = DATEFROMPARTS(YEAR(@FechaSistema), MONTH(@FechaSistema), 1);
        SET @FechaFin = DATEADD(MONTH, 1, @FechaIni);

        IF EXISTS (
            SELECT ID FROM [SILVER].[RR].[154_ENT_SWAPS]
            WHERE [FE_CON_OPE] = @FechaSistema
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[154_ENT_SWAPS]
            WHERE [FE_CON_OPE] = @FechaSistema;
            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

        INSERT INTO [RR].[154_ENT_SWAPS] (
            [OFICINA],[CONT],[FE_CON_OPE],[FE1_FLU_RE],[FEN_FLU_RE],[FE1_FLU_EN],[FEN_FLU_EN],
            [TIP_DER],[OBJ_OPE],[REV_SWAP],[DET_FLUJO],[IMP_BASE],[MDA_IMP],[LIQ_FLU],
            [NU_FLU_RE],[NU_FLU_EN],[INT_FLU_RE],[INT_FLU_EN],
            [TIP_TAS_RE],[TAS_FIJ_RE],[TAS_REF_RE],[REV_TREF_RE],[ANIO_RE],[FE_REF_RE],[FA1_TAS_RE],[OP1_TAS_RE],[PT1_TAS_RE],
            [TIP_TAS_EN],[TAS_FIJ_EN],[TAS_REF_EN],[REV_TREF_EN],[ANIO_EN],[FE_REF_EN],[FA1_TAS_EN],[OP1_TAS_EN],[PT1_TAS_EN],
            [CUO_COMP],[VEN_ANT],[TER_OPE],[PAQ_EST],[ID_PAQ_EST],[CON_PAQ_EST],[BROKER],[SOCIO_LIQ],[CAM_COM],[AG_CAL],
            [NUM_CONF],[NU_ID],[NUM_ID_OP_SBY],[MODIFICA],[INTERC_IMP],
            [IMP_BA_RE],[MDA_IMP_RE],[IMP_BA_EN],[MDA_IMP_EN],
            [PRO_TER],[FECVEN_A],[FECLIQ_A],[IMP_VEN],[MDA_VEN],[VTOT_IMPE],[VPAR_IMPR],[VPAR_IMPE],
            [PAG_VENA],[MOT_VENA],[VEN_ANT_CD],[NUM_ID_CP],
            [SEC_SWAP],[CONT_2],[FE_CON_OPE_2],[UTI_N],[UTI],[UPI]
        )
        SELECT
            [OFICINA],[CONT],[FE_CON_OPE],[FE1_FLU_RE],[FEN_FLU_RE],[FE1_FLU_EN],[FEN_FLU_EN],
            [TIP_DER],[OBJ_OPE],[REV_SWAP],[DET_FLUJO],[IMP_BASE],[MDA_IMP],[LIQ_FLU],
            [NU_FLU_RE],[NU_FLU_EN],[INT_FLU_RE],[INT_FLU_EN],
            [TIP_TAS_RE],[TAS_FIJ_RE],[TAS_REF_RE],[REV_TREF_RE],[ANIO_RE],[FE_REF_RE],[FA1_TAS_RE],[OP1_TAS_RE],[PT1_TAS_RE],
            [TIP_TAS_EN],[TAS_FIJ_EN],[TAS_REF_EN],[REV_TREF_EN],[ANIO_EN],[FE_REF_EN],[FA1_TAS_EN],[OP1_TAS_EN],[PT1_TAS_EN],
            [CUO_COMP],[VEN_ANT],[TER_OPE],[PAQ_EST],[ID_PAQ_EST],[CON_PAQ_EST],[BROKER],[SOCIO_LIQ],[CAM_COM],[AG_CAL],
            [NUM_CONF],[NU_ID],[NUM_ID_OP_SBY],[MODIFICA],[INTERC_IMP],
            [IMP_BA_RE],[MDA_IMP_RE],[IMP_BA_EN],[MDA_IMP_EN],
            [PRO_TER],[FECVEN_A],[FECLIQ_A],[IMP_VEN],[MDA_VEN],[VTOT_IMPE],[VPAR_IMPR],[VPAR_IMPE],
            [PAG_VENA],[MOT_VENA],[VEN_ANT_CD],[NUM_ID_CP],
            [SEC_SWAP],[CONT_2],[FE_CON_OPE_2],[UTI_N],[UTI],[UPI]
        FROM [SILVER].[RR].[154_ENT_SWAPS]
        WHERE [FE_CON_OPE] = @FechaSistema;

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
--   R03b: UTI_N -> NOT NULL
--   R03c: ADD columnas obsoletas (SEC_SWAP, CONT_2, FE_CON_OPE_2)
-- ============================================================
USE [SILVER]
GO

-- R03a
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='154_ENT_SWAPS' AND COLUMN_NAME='FECHAINFO')
    ALTER TABLE [RR].[154_ENT_SWAPS] DROP COLUMN [FECHAINFO];
GO

USE [SILVER]
GO

-- R03b
ALTER TABLE [RR].[154_ENT_SWAPS] ALTER COLUMN [UTI_N] varchar(52) NOT NULL;
GO

USE [SILVER]
GO

-- R03c
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='154_ENT_SWAPS' AND COLUMN_NAME='SEC_SWAP')
    ALTER TABLE [RR].[154_ENT_SWAPS] ADD [SEC_SWAP] numeric(1,0) NOT NULL CONSTRAINT [DF_RR_154_SEC_SWAP_TMP] DEFAULT (0);
GO

USE [SILVER]
GO

IF EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = 'DF_RR_154_SEC_SWAP_TMP')
    ALTER TABLE [RR].[154_ENT_SWAPS] DROP CONSTRAINT [DF_RR_154_SEC_SWAP_TMP];
GO

USE [SILVER]
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='154_ENT_SWAPS' AND COLUMN_NAME='CONT_2')
    ALTER TABLE [RR].[154_ENT_SWAPS] ADD [CONT_2] varchar(6) NOT NULL CONSTRAINT [DF_RR_154_CONT_2_TMP] DEFAULT ('');
GO

USE [SILVER]
GO

IF EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = 'DF_RR_154_CONT_2_TMP')
    ALTER TABLE [RR].[154_ENT_SWAPS] DROP CONSTRAINT [DF_RR_154_CONT_2_TMP];
GO

USE [SILVER]
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='154_ENT_SWAPS' AND COLUMN_NAME='FE_CON_OPE_2')
    ALTER TABLE [RR].[154_ENT_SWAPS] ADD [FE_CON_OPE_2] date NOT NULL CONSTRAINT [DF_RR_154_FE_CON_OPE_2_TMP] DEFAULT ('19000101');
GO

USE [SILVER]
GO

IF EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = 'DF_RR_154_FE_CON_OPE_2_TMP')
    ALTER TABLE [RR].[154_ENT_SWAPS] DROP CONSTRAINT [DF_RR_154_FE_CON_OPE_2_TMP];
GO

-- ============================================================
-- SECTION R04 | Eliminar tabla BRONZE.LMDA.SWAP
-- ============================================================
USE [BRONZE]
GO

IF OBJECT_ID('LMDA.[SWAP]', 'U') IS NOT NULL
    DROP TABLE [LMDA].[SWAP];
GO
