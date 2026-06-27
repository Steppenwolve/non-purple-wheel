-- ============================================================
-- ROLLBACK  133_ENT_OFF_CONVAL
-- ============================================================

-- ============================================================
-- SECTION R01 | Restaurar SP SILVER (filtro diaria por FE_CON_OPE)
-- ============================================================
USE [SILVER]
GO

CREATE OR ALTER PROCEDURE [dbo].[133_ENT_OFF_CONVAL]
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
    DECLARE @NombreJob       NVARCHAR(128) = '[133_ENT_OFF_CONVAL] ';

    BEGIN TRY

        IF EXISTS (
            SELECT ID FROM [SILVER].[RR].[133_ENT_OFF_CONVAL]
            WHERE [FE_CON_OPE] = @FechaSistema
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[133_ENT_OFF_CONVAL]
            WHERE [FE_CON_OPE] = @FechaSistema;
            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

        INSERT INTO [RR].[133_ENT_OFF_CONVAL] (
            [FE_CON_OPE],[NUM_ID],[POS_OPER],[OBJ_OPE],[PAQ_EST],[ID_PAQ_EST],
            [CON_PAQ_EST],[ACT_OPE],[MON_ACT_OPE],[PAS_OPE],[MON_PAS_OPE],
            [DUR_ACT],[DUR_PAS],[ID_GAR_VG],[NOCIONAL],[MON_NOCIONAL],[FECHAINFO]
        )
        SELECT
            O.[FE_CON_OPE],O.[NUM_ID],O.[POS_OPER],O.[OBJ_OPE],O.[PAQ_EST],O.[ID_PAQ_EST],
            O.[CON_PAQ_EST],O.[ACT_OPE],O.[MON_ACT_OPE],O.[PAS_OPE],O.[MON_PAS_OPE],
            O.[DUR_ACT],O.[DUR_PAS],O.[ID_GAR_VG],O.[NOCIONAL],O.[MON_NOCIONAL],O.[FECHAINFO]
        FROM [BRONZE].[LMDA].[OFF_CONVAL] O
        WHERE O.[FECHAINFO] = @FechaSistema;

        SET @FilasInsertadas = @@ROWCOUNT;
        SET @LogMessage = 'Proceso completado. Filas totales: ' + CAST(@FilasInsertadas AS NVARCHAR(10));
        PRINT @LogMessage;
        SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);

    END TRY
    BEGIN CATCH
        SET @ExitoEjecucion = 0;
        SET @MensajeError   = ERROR_MESSAGE();
        PRINT 'Error: ' + @MensajeError;
        SET @DetallesLog = @DetallesLog + 'Error: ' + @MensajeError + CHAR(13) + CHAR(10);
    END CATCH

    INSERT INTO dbo.LogSilverDiario (
        FechaEjecucion,FilasInsertadas,EstadoEjecucion,
        MensajeError,DetallesLog,NombreJob,ProgramadorJob
    ) VALUES (
        @FechaInicio,@FilasInsertadas,
        CASE WHEN @ExitoEjecucion=1 THEN 'Exitoso' ELSE 'Error' END,
        CASE WHEN @ExitoEjecucion=1 THEN NULL ELSE @MensajeError END,
        @DetallesLog,@NombreJob,@ProgramadorJob
    );
END;
GO

-- ============================================================
-- SECTION R02 | Restaurar SP ION (filtro puntual por FECHAINFO)
-- ============================================================
USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[133_ENT_OFF_CONVAL]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SELECT
        FORMAT(O.[FE_CON_OPE], 'yyyy/MM/dd') AS [FE_CON_OPE],
        O.[NUM_ID],O.[POS_OPER],O.[OBJ_OPE],O.[PAQ_EST],O.[ID_PAQ_EST],
        O.[CON_PAQ_EST],O.[ACT_OPE],O.[MON_ACT_OPE],O.[PAS_OPE],O.[MON_PAS_OPE],
        O.[DUR_ACT],O.[DUR_PAS],O.[ID_GAR_VG],O.[NOCIONAL],O.[MON_NOCIONAL],
        FORMAT(O.[FECHAINFO], 'yyyy/MM/dd') AS [FECHAINFO]
    FROM [SILVER].[RR].[133_ENT_OFF_CONVAL] O
    WHERE O.[FECHAINFO] = @FECHA;

END;
GO

-- ============================================================
-- SECTION R02b | Revertir POS_OPER varchar(3) -> varchar(1)
-- ============================================================
USE [SILVER]
GO

-- Truncar valores de 3 chars antes de reducir (por si hay datos)
UPDATE [RR].[133_ENT_OFF_CONVAL]
SET [POS_OPER] = LEFT([POS_OPER], 1)
WHERE LEN([POS_OPER]) > 1;

ALTER TABLE [RR].[133_ENT_OFF_CONVAL]
    ALTER COLUMN [POS_OPER] varchar(1) NOT NULL;
GO

USE [BRONZE]
GO

UPDATE [LMDA].[OFF_CONVAL]
SET [POS_OPER] = LEFT([POS_OPER], 1)
WHERE LEN([POS_OPER]) > 1;

ALTER TABLE [LMDA].[OFF_CONVAL]
    ALTER COLUMN [POS_OPER] varchar(1) NOT NULL;
GO

-- ============================================================
-- SECTION R03 | Restaurar columnas extra en SILVER
-- ============================================================
USE [SILVER]
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='133_ENT_OFF_CONVAL' AND COLUMN_NAME='FE_CORTE'
)
    ALTER TABLE [RR].[133_ENT_OFF_CONVAL] ADD [FE_CORTE] date NOT NULL CONSTRAINT [DF_133_FE_CORTE] DEFAULT ('1900-01-01');

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='133_ENT_OFF_CONVAL' AND COLUMN_NAME='ACT_OPE_VAL'
)
    ALTER TABLE [RR].[133_ENT_OFF_CONVAL] ADD [ACT_OPE_VAL] numeric(15,0) NOT NULL CONSTRAINT [DF_133_ACT_OPE_VAL] DEFAULT (0);

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='133_ENT_OFF_CONVAL' AND COLUMN_NAME='PAS_OPE_VAL'
)
    ALTER TABLE [RR].[133_ENT_OFF_CONVAL] ADD [PAS_OPE_VAL] numeric(15,0) NOT NULL CONSTRAINT [DF_133_PAS_OPE_VAL] DEFAULT (0);
GO

-- ============================================================
-- SECTION R04 | INDICE_REPORTES — restaurar Diaria
-- ============================================================
USE [ION]
GO

UPDATE [dbo].[INDICE_REPORTES]
SET [frecuencia] = 'Diaria'
WHERE [numero] = 133;
GO

-- ============================================================
-- SECTION R05 | BRONZE — DROP tabla (si no tenía datos antes)
-- ============================================================
-- Descomentar solo si se confirma que la tabla no tenía registros en producción:
-- USE [BRONZE]
-- GO
-- IF OBJECT_ID('LMDA.OFF_CONVAL','U') IS NOT NULL
--     DROP TABLE [LMDA].[OFF_CONVAL];
-- GO
