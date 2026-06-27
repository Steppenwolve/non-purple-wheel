-- ============================================================
-- AJUSTE  157_ENT_SWAP_FLUJOS
-- Layout : Layout_SWAPS_V10_FILE_SWAP_FLUJO.xlsx
-- Periodo: Diaria | Origen: LMDA
-- ============================================================

-- ============================================================
-- SECTION 00 | Crear tabla BRONZE.LMDA.SWAP_FLUJO (nueva)
-- ============================================================
USE [BRONZE]
GO

IF OBJECT_ID('LMDA.[SWAP_FLUJO]', 'U') IS NULL
CREATE TABLE [LMDA].[SWAP_FLUJO]
(
    [ID] uniqueidentifier NOT NULL DEFAULT NEWID(),
    [CONT] varchar(6) NOT NULL,
    [FECHA] date NOT NULL,
    [NU_ID] varchar(34) NOT NULL,
    [IMP_BASE] numeric(15,0) NOT NULL,
    [NU_FL_RE] numeric(3,0) NOT NULL,
    [FEIN_FL_RE] date NULL,
    [FEIN_VE_RE] date NOT NULL,
    [TIP_TAS_RE] varchar(3) NOT NULL,
    [TAS_FIJ_RE] numeric(9,6) NOT NULL,
    [TAS_REF_RE] varchar(20) NOT NULL,
    [OP1_TAS_RE] varchar(1) NOT NULL,
    [PT1_TAS_RE] numeric(9,6) NOT NULL,
    [FE_REF_RE] varchar(3) NOT NULL,
    [NU_FL_EN] numeric(3,0) NOT NULL,
    [FE_IN_FLRE] date NULL,
    [FE_VE_FLEN] date NOT NULL,
    [TIP_TAS_EN] varchar(3) NOT NULL,
    [TAS_FIJ_EN] numeric(9,6) NOT NULL,
    [TAS_REF_EN] varchar(20) NOT NULL,
    [OP1_TAS_EN] varchar(1) NOT NULL,
    [PT1_TAS_EN] numeric(9,6) NOT NULL,
    [FE_REF_EN] varchar(3) NOT NULL,
    [IMP_BA_EN] numeric(15,0) NOT NULL,
    [IMP_BA_RE] numeric(15,0) NOT NULL,
    [FEIN_FL_EN] date NOT NULL,
    [FEIN_VE_EN] date NOT NULL,
    [MODIFICA] varchar(5) NOT NULL,
    [FECHAINFO] date NOT NULL,
    [FECHA_EXTRACCION] smalldatetime NOT NULL DEFAULT GETDATE(),
    CONSTRAINT [PK_LMDA_SWAP_FLUJO] PRIMARY KEY ([ID])
);
GO

-- ============================================================
-- SECTION 01 | Ajustes estructura SILVER.RR.157_ENT_SWAP_FLUJOS
-- ============================================================
USE [SILVER]
GO

IF NOT EXISTS (
    SELECT 1
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='157_ENT_SWAP_FLUJOS' AND COLUMN_NAME='FECHAINFO'
)
BEGIN
    ALTER TABLE [RR].[157_ENT_SWAP_FLUJOS]
        ADD [FECHAINFO] date NOT NULL
        CONSTRAINT [DF_RR_157_FECHAINFO_TMP] DEFAULT ('19000101');
END;
GO

USE [SILVER]
GO

IF EXISTS (SELECT 1
FROM sys.default_constraints
WHERE name = 'DF_RR_157_FECHAINFO_TMP')
    ALTER TABLE [RR].[157_ENT_SWAP_FLUJOS] DROP CONSTRAINT [DF_RR_157_FECHAINFO_TMP];
GO

USE [SILVER]
GO

-- 01b: FEIN_FL_RE — OBLIGATORIO=No → NULL
ALTER TABLE [RR].[157_ENT_SWAP_FLUJOS]
    ALTER COLUMN [FEIN_FL_RE] date NULL;
GO

USE [SILVER]
GO

-- 01c: FE_IN_FLRE — OBLIGATORIO=No → NULL
ALTER TABLE [RR].[157_ENT_SWAP_FLUJOS]
    ALTER COLUMN [FE_IN_FLRE] date NULL;
GO

-- ============================================================
-- SECTION 02 | SP SILVER — corregir self-select, campo control
--              y agregar FECHAINFO
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
    -- AJUSTE  157_ENT_SWAP_FLUJOS
    -- Layout : Layout_SWAPS_V10_FILE_SWAP_FLUJO.xlsx
    -- Periodo: Diaria | Origen: LMDA
    BEGIN TRY

        IF EXISTS (
            SELECT ID
    FROM [SILVER].[RR].[157_ENT_SWAP_FLUJOS]
    WHERE [FECHAINFO] = @FechaSistema
        )
        BEGIN
        DELETE FROM [SILVER].[RR].[157_ENT_SWAP_FLUJOS]
            WHERE [FECHAINFO] = @FechaSistema;

        SET @FilasEliminadas = @@ROWCOUNT;
        SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
        PRINT @LogMessage;
        SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
    END;

        INSERT INTO [RR].[157_ENT_SWAP_FLUJOS]
        (
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
        [MODIFICA],
        [FECHAINFO]
        )
    SELECT
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
        [MODIFICA],
        [FECHAINFO]
    FROM [BRONZE].[LMDA].[SWAP_FLUJO]
    WHERE [FECHAINFO] = @FechaSistema;

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

    DECLARE @Asunto             NVARCHAR(255);
    DECLARE @Cuerpo             NVARCHAR(MAX);
    DECLARE @FechaFinalizacion  DATETIME = GETDATE();
    DECLARE @DuracionEjecucion  VARCHAR(20) =
        CAST(DATEDIFF(SECOND, @FechaInicio, @FechaFinalizacion) AS VARCHAR(10)) + ' segundos';

    IF @ExitoEjecucion = 0
        AND @CorreoNotificacion IS NOT NULL
        AND @PerfilCorreo IS NOT NULL
    BEGIN
        SET @Asunto = 'ALERTA: Error en ' + ISNULL(@NombreJob, 'Job Desconocido');
        SET @Cuerpo =
            'Se ha producido un error durante la ejecución de.' + @NombreJob + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) +
            'Detalles del Job:' + CHAR(13) + CHAR(10) +
            '- Nombre del Job: '         + ISNULL(@NombreJob,      'No especificado') + CHAR(13) + CHAR(10) +
            '- Programado por: '         + ISNULL(@ProgramadorJob,  'No especificado') + CHAR(13) + CHAR(10) +
            '- Fecha y hora de inicio: ' + CONVERT(VARCHAR, @FechaInicio,        120)  + CHAR(13) + CHAR(10) +
            '- Fecha y hora de fin: '    + CONVERT(VARCHAR, @FechaFinalizacion,   120)  + CHAR(13) + CHAR(10) +
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
        (
        FechaEjecucion, FilasInsertadas, EstadoEjecucion,
        MensajeError, DetallesLog, NombreJob, ProgramadorJob
        )
    VALUES
        (
            @FechaInicio,
            @FilasInsertadas,
            CASE WHEN @ExitoEjecucion = 1 THEN 'Exitoso' ELSE 'Error' END,
            CASE WHEN @ExitoEjecucion = 1 THEN NULL ELSE @MensajeError END,
            @DetallesLog,
            @NombreJob,
            @ProgramadorJob
    );

    SET @LogMessage = 'Proceso completado y registrado en la tabla de log.';
    PRINT @LogMessage;
END;
GO

-- ============================================================
-- SECTION 03 | SP ION — corregir campo control, FORMAT fechas,
--              quitar ID/FECHA_EXTRACCION, respetar ORDEN 1-28
-- ============================================================
USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[157_ENT_SWAP_FLUJOS]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    -- AJUSTE  157_ENT_SWAP_FLUJOS
    -- Layout : Layout_SWAPS_V10_FILE_SWAP_FLUJO.xlsx
    -- Periodo: Diaria | Origen: LMDA
    SELECT
        T.[CONT]                                    AS [CONT], -- ORDEN  1
        FORMAT(T.[FECHA],      'yyyy/MM/dd')        AS [FECHA], -- ORDEN  2
        T.[NU_ID]                                   AS [NU_ID], -- ORDEN  3
        T.[IMP_BASE]                                AS [IMP_BASE], -- ORDEN  4
        T.[NU_FL_RE]                                AS [NU_FL_RE], -- ORDEN  5
        FORMAT(T.[FEIN_FL_RE], 'yyyy/MM/dd')        AS [FEIN_FL_RE], -- ORDEN  6
        FORMAT(T.[FEIN_VE_RE], 'yyyy/MM/dd')        AS [FEIN_VE_RE], -- ORDEN  7
        T.[TIP_TAS_RE]                              AS [TIP_TAS_RE], -- ORDEN  8
        T.[TAS_FIJ_RE]                              AS [TAS_FIJ_RE], -- ORDEN  9
        T.[TAS_REF_RE]                              AS [TAS_REF_RE], -- ORDEN 10
        T.[OP1_TAS_RE]                              AS [OP1_TAS_RE], -- ORDEN 11
        T.[PT1_TAS_RE]                              AS [PT1_TAS_RE], -- ORDEN 12
        T.[FE_REF_RE]                               AS [FE_REF_RE], -- ORDEN 13
        T.[NU_FL_EN]                                AS [NU_FL_EN], -- ORDEN 14
        FORMAT(T.[FE_IN_FLRE], 'yyyy/MM/dd')        AS [FE_IN_FLRE], -- ORDEN 15
        FORMAT(T.[FE_VE_FLEN], 'yyyy/MM/dd')        AS [FE_VE_FLEN], -- ORDEN 16
        T.[TIP_TAS_EN]                              AS [TIP_TAS_EN], -- ORDEN 17
        T.[TAS_FIJ_EN]                              AS [TAS_FIJ_EN], -- ORDEN 18
        T.[TAS_REF_EN]                              AS [TAS_REF_EN], -- ORDEN 19
        T.[OP1_TAS_EN]                              AS [OP1_TAS_EN], -- ORDEN 20
        T.[PT1_TAS_EN]                              AS [PT1_TAS_EN], -- ORDEN 21
        T.[FE_REF_EN]                               AS [FE_REF_EN], -- ORDEN 22
        T.[IMP_BA_EN]                               AS [IMP_BA_EN], -- ORDEN 23
        T.[IMP_BA_RE]                               AS [IMP_BA_RE], -- ORDEN 24
        FORMAT(T.[FEIN_FL_EN], 'yyyy/MM/dd')        AS [FEIN_FL_EN], -- ORDEN 25
        FORMAT(T.[FEIN_VE_EN], 'yyyy/MM/dd')        AS [FEIN_VE_EN], -- ORDEN 26
        T.[MODIFICA]                                AS [MODIFICA], -- ORDEN 27
        FORMAT(T.[FECHAINFO],  'yyyy/MM/dd')        AS [FECHAINFO]
    -- ORDEN 28
    FROM [SILVER].[RR].[157_ENT_SWAP_FLUJOS] T
    WHERE T.[FECHAINFO] = @FECHA;
END;
GO
