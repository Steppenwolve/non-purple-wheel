-- ============================================================
-- AJUSTE  154_ENT_SWAPS
-- Layout : Layout_SWAPS_V10_FILE_SWAP.xlsx
-- Periodo: Diaria | Origen: LMDA
-- ============================================================

-- ============================================================
-- SECTION 00 | Crear tabla BRONZE.LMDA.SWAP (nueva)
-- ============================================================
USE [BRONZE]
GO

IF OBJECT_ID('LMDA.[SWAP]', 'U') IS NULL
CREATE TABLE [LMDA].[SWAP] (
    [ID]             uniqueidentifier NOT NULL DEFAULT NEWID(),
    [OFICINA]        varchar(1)       NOT NULL,
    [CONT]           varchar(6)       NOT NULL,
    [FE_CON_OPE]     date             NOT NULL,
    [FE1_FLU_RE]     date             NOT NULL,
    [FEN_FLU_RE]     date             NOT NULL,
    [FE1_FLU_EN]     date             NOT NULL,
    [FEN_FLU_EN]     date             NOT NULL,
    [TIP_DER]        numeric(2,0)     NOT NULL,
    [OBJ_OPE]        varchar(2)       NOT NULL,
    [REV_SWAP]       varchar(5)       NOT NULL,
    [DET_FLUJO]      varchar(2)       NOT NULL,
    [IMP_BASE]       numeric(15,0)    NOT NULL,
    [MDA_IMP]        varchar(3)       NOT NULL,
    [LIQ_FLU]        numeric(2,0)     NOT NULL,
    [NU_FLU_RE]      numeric(3,0)     NOT NULL,
    [NU_FLU_EN]      numeric(3,0)     NOT NULL,
    [INT_FLU_RE]     numeric(3,0)     NOT NULL,
    [INT_FLU_EN]     numeric(3,0)     NOT NULL,
    [TIP_TAS_RE]     varchar(3)       NOT NULL,
    [TAS_FIJ_RE]     numeric(9,6)     NOT NULL,
    [TAS_REF_RE]     varchar(20)      NOT NULL,
    [REV_TREF_RE]    numeric(3,0)     NOT NULL,
    [ANIO_RE]        varchar(1)       NOT NULL,
    [FE_REF_RE]      varchar(3)       NOT NULL,
    [FA1_TAS_RE]     numeric(8,6)     NOT NULL,
    [OP1_TAS_RE]     varchar(1)       NOT NULL,
    [PT1_TAS_RE]     numeric(9,6)     NOT NULL,
    [TIP_TAS_EN]     varchar(3)       NOT NULL,
    [TAS_FIJ_EN]     numeric(9,6)     NOT NULL,
    [TAS_REF_EN]     varchar(20)      NOT NULL,
    [REV_TREF_EN]    numeric(3,0)     NOT NULL,
    [ANIO_EN]        varchar(1)       NOT NULL,
    [FE_REF_EN]      varchar(3)       NOT NULL,
    [FA1_TAS_EN]     numeric(8,6)     NOT NULL,
    [OP1_TAS_EN]     varchar(1)       NOT NULL,
    [PT1_TAS_EN]     numeric(9,6)     NOT NULL,
    [CUO_COMP]       varchar(1)       NOT NULL,
    [VEN_ANT]        varchar(1)       NOT NULL,
    [TER_OPE]        varchar(1)       NOT NULL,
    [PAQ_EST]        numeric(2,0)     NOT NULL,
    [ID_PAQ_EST]     varchar(20)      NOT NULL,
    [CON_PAQ_EST]    numeric(3,0)     NOT NULL,
    [BROKER]         numeric(2,0)     NOT NULL,
    [SOCIO_LIQ]      varchar(6)       NOT NULL,
    [CAM_COM]        numeric(2,0)     NOT NULL,
    [AG_CAL]         varchar(6)       NOT NULL,
    [NUM_CONF]       varchar(34)      NOT NULL,
    [NU_ID]          varchar(34)      NOT NULL,
    [NUM_ID_OP_SBY]  varchar(34)      NOT NULL,
    [MODIFICA]       varchar(5)       NOT NULL,
    [INTERC_IMP]     varchar(1)       NOT NULL,
    [IMP_BA_RE]      numeric(15,0)    NOT NULL,
    [MDA_IMP_RE]     varchar(3)       NOT NULL,
    [IMP_BA_EN]      numeric(15,0)    NOT NULL,
    [MDA_IMP_EN]     varchar(3)       NOT NULL,
    [PRO_TER]        varchar(1)       NOT NULL,
    [FECVEN_A]       date             NOT NULL,
    [FECLIQ_A]       date             NOT NULL,
    [IMP_VEN]        numeric(15,0)    NOT NULL,
    [MDA_VEN]        varchar(3)       NOT NULL,
    [VTOT_IMPE]      numeric(15,0)    NOT NULL,
    [VPAR_IMPR]      numeric(15,0)    NOT NULL,
    [VPAR_IMPE]      numeric(15,0)    NOT NULL,
    [PAG_VENA]       varchar(1)       NOT NULL,
    [MOT_VENA]       numeric(1,0)     NOT NULL,
    [VEN_ANT_CD]     varchar(2)       NOT NULL,
    [NUM_ID_CP]      varchar(34)      NOT NULL,
    [UTI_N]          varchar(52)      NULL,
    [UTI]            varchar(52)      NOT NULL,
    [UPI]            varchar(12)      NOT NULL,
    [FECHAINFO]      date             NOT NULL,
    [FECHA_EXTRACCION] smalldatetime  NOT NULL DEFAULT GETDATE(),
    CONSTRAINT [PK_LMDA_SWAP] PRIMARY KEY ([ID])
);
GO

-- ============================================================
-- SECTION 01 | Ajustes estructura SILVER.RR.154_ENT_SWAPS
-- ============================================================
USE [SILVER]
GO

-- 01a: DROP columnas obsoletas (no presentes en layout V10)
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='154_ENT_SWAPS' AND COLUMN_NAME='SEC_SWAP')
    ALTER TABLE [RR].[154_ENT_SWAPS] DROP COLUMN [SEC_SWAP];
GO

USE [SILVER]
GO

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='154_ENT_SWAPS' AND COLUMN_NAME='CONT_2')
    ALTER TABLE [RR].[154_ENT_SWAPS] DROP COLUMN [CONT_2];
GO

USE [SILVER]
GO

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='154_ENT_SWAPS' AND COLUMN_NAME='FE_CON_OPE_2')
    ALTER TABLE [RR].[154_ENT_SWAPS] DROP COLUMN [FE_CON_OPE_2];
GO

USE [SILVER]
GO

-- 01b: ADD FECHAINFO (ORDEN 71, OBLIGATORIO=SI)
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='154_ENT_SWAPS' AND COLUMN_NAME='FECHAINFO'
)
BEGIN
    ALTER TABLE [RR].[154_ENT_SWAPS]
        ADD [FECHAINFO] date NOT NULL
        CONSTRAINT [DF_RR_154_FECHAINFO_TMP] DEFAULT ('19000101');
END;
GO

USE [SILVER]
GO

IF EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = 'DF_RR_154_FECHAINFO_TMP')
    ALTER TABLE [RR].[154_ENT_SWAPS] DROP CONSTRAINT [DF_RR_154_FECHAINFO_TMP];
GO

USE [SILVER]
GO

-- 01c: UTI_N — OBLIGATORIO=No → NULL
ALTER TABLE [RR].[154_ENT_SWAPS]
    ALTER COLUMN [UTI_N] varchar(52) NULL;
GO

-- ============================================================
-- SECTION 02 | SP SILVER — corregir self-select, campo control,
--              agregar FECHAINFO, quitar columnas obsoletas
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

    BEGIN TRY

        IF EXISTS (
            SELECT ID FROM [SILVER].[RR].[154_ENT_SWAPS]
            WHERE [FECHAINFO] = @FechaSistema
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[154_ENT_SWAPS]
            WHERE [FECHAINFO] = @FechaSistema;

            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

        INSERT INTO [RR].[154_ENT_SWAPS] (
            [OFICINA],
            [CONT],
            [FE_CON_OPE],
            [FE1_FLU_RE],
            [FEN_FLU_RE],
            [FE1_FLU_EN],
            [FEN_FLU_EN],
            [TIP_DER],
            [OBJ_OPE],
            [REV_SWAP],
            [DET_FLUJO],
            [IMP_BASE],
            [MDA_IMP],
            [LIQ_FLU],
            [NU_FLU_RE],
            [NU_FLU_EN],
            [INT_FLU_RE],
            [INT_FLU_EN],
            [TIP_TAS_RE],
            [TAS_FIJ_RE],
            [TAS_REF_RE],
            [REV_TREF_RE],
            [ANIO_RE],
            [FE_REF_RE],
            [FA1_TAS_RE],
            [OP1_TAS_RE],
            [PT1_TAS_RE],
            [TIP_TAS_EN],
            [TAS_FIJ_EN],
            [TAS_REF_EN],
            [REV_TREF_EN],
            [ANIO_EN],
            [FE_REF_EN],
            [FA1_TAS_EN],
            [OP1_TAS_EN],
            [PT1_TAS_EN],
            [CUO_COMP],
            [VEN_ANT],
            [TER_OPE],
            [PAQ_EST],
            [ID_PAQ_EST],
            [CON_PAQ_EST],
            [BROKER],
            [SOCIO_LIQ],
            [CAM_COM],
            [AG_CAL],
            [NUM_CONF],
            [NU_ID],
            [NUM_ID_OP_SBY],
            [MODIFICA],
            [INTERC_IMP],
            [IMP_BA_RE],
            [MDA_IMP_RE],
            [IMP_BA_EN],
            [MDA_IMP_EN],
            [PRO_TER],
            [FECVEN_A],
            [FECLIQ_A],
            [IMP_VEN],
            [MDA_VEN],
            [VTOT_IMPE],
            [VPAR_IMPR],
            [VPAR_IMPE],
            [PAG_VENA],
            [MOT_VENA],
            [VEN_ANT_CD],
            [NUM_ID_CP],
            [UTI_N],
            [UTI],
            [UPI],
            [FECHAINFO]
        )
        SELECT
            [OFICINA],
            [CONT],
            [FE_CON_OPE],
            [FE1_FLU_RE],
            [FEN_FLU_RE],
            [FE1_FLU_EN],
            [FEN_FLU_EN],
            [TIP_DER],
            [OBJ_OPE],
            [REV_SWAP],
            [DET_FLUJO],
            [IMP_BASE],
            [MDA_IMP],
            [LIQ_FLU],
            [NU_FLU_RE],
            [NU_FLU_EN],
            [INT_FLU_RE],
            [INT_FLU_EN],
            [TIP_TAS_RE],
            [TAS_FIJ_RE],
            [TAS_REF_RE],
            [REV_TREF_RE],
            [ANIO_RE],
            [FE_REF_RE],
            [FA1_TAS_RE],
            [OP1_TAS_RE],
            [PT1_TAS_RE],
            [TIP_TAS_EN],
            [TAS_FIJ_EN],
            [TAS_REF_EN],
            [REV_TREF_EN],
            [ANIO_EN],
            [FE_REF_EN],
            [FA1_TAS_EN],
            [OP1_TAS_EN],
            [PT1_TAS_EN],
            [CUO_COMP],
            [VEN_ANT],
            [TER_OPE],
            [PAQ_EST],
            [ID_PAQ_EST],
            [CON_PAQ_EST],
            [BROKER],
            [SOCIO_LIQ],
            [CAM_COM],
            [AG_CAL],
            [NUM_CONF],
            [NU_ID],
            [NUM_ID_OP_SBY],
            [MODIFICA],
            [INTERC_IMP],
            [IMP_BA_RE],
            [MDA_IMP_RE],
            [IMP_BA_EN],
            [MDA_IMP_EN],
            [PRO_TER],
            [FECVEN_A],
            [FECLIQ_A],
            [IMP_VEN],
            [MDA_VEN],
            [VTOT_IMPE],
            [VPAR_IMPR],
            [VPAR_IMPE],
            [PAG_VENA],
            [MOT_VENA],
            [VEN_ANT_CD],
            [NUM_ID_CP],
            [UTI_N],
            [UTI],
            [UPI],
            [FECHAINFO]
        FROM [BRONZE].[LMDA].[SWAP]
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
            '- Fecha y hora de inicio: ' + CONVERT(VARCHAR, @FechaInicio,       120)   + CHAR(13) + CHAR(10) +
            '- Fecha y hora de fin: '    + CONVERT(VARCHAR, @FechaFinalizacion,  120)   + CHAR(13) + CHAR(10) +
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

    SET @LogMessage = 'Proceso completado y registrado en la tabla de log.';
    PRINT @LogMessage;
END;
GO

-- ============================================================
-- SECTION 03 | SP ION — corregir campo control, FORMAT fechas,
--              quitar ID/FECHA_EXTRACCION/obsoletos, ORDEN 1-71
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
        T.[OFICINA]                                 AS [OFICINA],        -- ORDEN  1
        T.[CONT]                                    AS [CONT],           -- ORDEN  2
        FORMAT(T.[FE_CON_OPE],  'yyyy/MM/dd')       AS [FE_CON_OPE],    -- ORDEN  3
        FORMAT(T.[FE1_FLU_RE],  'yyyy/MM/dd')       AS [FE1_FLU_RE],    -- ORDEN  4
        FORMAT(T.[FEN_FLU_RE],  'yyyy/MM/dd')       AS [FEN_FLU_RE],    -- ORDEN  5
        FORMAT(T.[FE1_FLU_EN],  'yyyy/MM/dd')       AS [FE1_FLU_EN],    -- ORDEN  6
        FORMAT(T.[FEN_FLU_EN],  'yyyy/MM/dd')       AS [FEN_FLU_EN],    -- ORDEN  7
        T.[TIP_DER]                                 AS [TIP_DER],        -- ORDEN  8
        T.[OBJ_OPE]                                 AS [OBJ_OPE],        -- ORDEN  9
        T.[REV_SWAP]                                AS [REV_SWAP],       -- ORDEN 10
        T.[DET_FLUJO]                               AS [DET_FLUJO],      -- ORDEN 11
        T.[IMP_BASE]                                AS [IMP_BASE],       -- ORDEN 12
        T.[MDA_IMP]                                 AS [MDA_IMP],        -- ORDEN 13
        T.[LIQ_FLU]                                 AS [LIQ_FLU],        -- ORDEN 14
        T.[NU_FLU_RE]                               AS [NU_FLU_RE],      -- ORDEN 15
        T.[NU_FLU_EN]                               AS [NU_FLU_EN],      -- ORDEN 16
        T.[INT_FLU_RE]                              AS [INT_FLU_RE],     -- ORDEN 17
        T.[INT_FLU_EN]                              AS [INT_FLU_EN],     -- ORDEN 18
        T.[TIP_TAS_RE]                              AS [TIP_TAS_RE],     -- ORDEN 19
        T.[TAS_FIJ_RE]                              AS [TAS_FIJ_RE],     -- ORDEN 20
        T.[TAS_REF_RE]                              AS [TAS_REF_RE],     -- ORDEN 21
        T.[REV_TREF_RE]                             AS [REV_TREF_RE],    -- ORDEN 22
        T.[ANIO_RE]                                 AS [ANIO_RE],        -- ORDEN 23
        T.[FE_REF_RE]                               AS [FE_REF_RE],      -- ORDEN 24
        T.[FA1_TAS_RE]                              AS [FA1_TAS_RE],     -- ORDEN 25
        T.[OP1_TAS_RE]                              AS [OP1_TAS_RE],     -- ORDEN 26
        T.[PT1_TAS_RE]                              AS [PT1_TAS_RE],     -- ORDEN 27
        T.[TIP_TAS_EN]                              AS [TIP_TAS_EN],     -- ORDEN 28
        T.[TAS_FIJ_EN]                              AS [TAS_FIJ_EN],     -- ORDEN 29
        T.[TAS_REF_EN]                              AS [TAS_REF_EN],     -- ORDEN 30
        T.[REV_TREF_EN]                             AS [REV_TREF_EN],    -- ORDEN 31
        T.[ANIO_EN]                                 AS [ANIO_EN],        -- ORDEN 32
        T.[FE_REF_EN]                               AS [FE_REF_EN],      -- ORDEN 33
        T.[FA1_TAS_EN]                              AS [FA1_TAS_EN],     -- ORDEN 34
        T.[OP1_TAS_EN]                              AS [OP1_TAS_EN],     -- ORDEN 35
        T.[PT1_TAS_EN]                              AS [PT1_TAS_EN],     -- ORDEN 36
        T.[CUO_COMP]                                AS [CUO_COMP],       -- ORDEN 37
        T.[VEN_ANT]                                 AS [VEN_ANT],        -- ORDEN 38
        T.[TER_OPE]                                 AS [TER_OPE],        -- ORDEN 39
        T.[PAQ_EST]                                 AS [PAQ_EST],        -- ORDEN 40
        T.[ID_PAQ_EST]                              AS [ID_PAQ_EST],     -- ORDEN 41
        T.[CON_PAQ_EST]                             AS [CON_PAQ_EST],    -- ORDEN 42
        T.[BROKER]                                  AS [BROKER],         -- ORDEN 43
        T.[SOCIO_LIQ]                               AS [SOCIO_LIQ],      -- ORDEN 44
        T.[CAM_COM]                                 AS [CAM_COM],        -- ORDEN 45
        T.[AG_CAL]                                  AS [AG_CAL],         -- ORDEN 46
        T.[NUM_CONF]                                AS [NUM_CONF],       -- ORDEN 47
        T.[NU_ID]                                   AS [NU_ID],          -- ORDEN 48
        T.[NUM_ID_OP_SBY]                           AS [NUM_ID_OP_SBY],  -- ORDEN 49
        T.[MODIFICA]                                AS [MODIFICA],       -- ORDEN 50
        T.[INTERC_IMP]                              AS [INTERC_IMP],     -- ORDEN 51
        T.[IMP_BA_RE]                               AS [IMP_BA_RE],      -- ORDEN 52
        T.[MDA_IMP_RE]                              AS [MDA_IMP_RE],     -- ORDEN 53
        T.[IMP_BA_EN]                               AS [IMP_BA_EN],      -- ORDEN 54
        T.[MDA_IMP_EN]                              AS [MDA_IMP_EN],     -- ORDEN 55
        T.[PRO_TER]                                 AS [PRO_TER],        -- ORDEN 56
        FORMAT(T.[FECVEN_A],    'yyyy/MM/dd')       AS [FECVEN_A],       -- ORDEN 57
        FORMAT(T.[FECLIQ_A],    'yyyy/MM/dd')       AS [FECLIQ_A],       -- ORDEN 58
        T.[IMP_VEN]                                 AS [IMP_VEN],        -- ORDEN 59
        T.[MDA_VEN]                                 AS [MDA_VEN],        -- ORDEN 60
        T.[VTOT_IMPE]                               AS [VTOT_IMPE],      -- ORDEN 61
        T.[VPAR_IMPR]                               AS [VPAR_IMPR],      -- ORDEN 62
        T.[VPAR_IMPE]                               AS [VPAR_IMPE],      -- ORDEN 63
        T.[PAG_VENA]                                AS [PAG_VENA],       -- ORDEN 64
        T.[MOT_VENA]                                AS [MOT_VENA],       -- ORDEN 65
        T.[VEN_ANT_CD]                              AS [VEN_ANT_CD],     -- ORDEN 66
        T.[NUM_ID_CP]                               AS [NUM_ID_CP],      -- ORDEN 67
        T.[UTI_N]                                   AS [UTI_N],          -- ORDEN 68
        T.[UTI]                                     AS [UTI],            -- ORDEN 69
        T.[UPI]                                     AS [UPI],            -- ORDEN 70
        FORMAT(T.[FECHAINFO],   'yyyy/MM/dd')       AS [FECHAINFO]       -- ORDEN 71
    FROM [SILVER].[RR].[154_ENT_SWAPS] T
    WHERE T.[FECHAINFO] = @FECHA;
END;
GO
