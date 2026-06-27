-- ============================================================
-- AJUSTE  021_ENT_SWAPS_CONVO_semanal
-- Periodicidad : Semanal  |  Origen : LMDA (BRONZE.LMDA.SWAP_CONVO) | Layout : Layout_SWAPS_V10_FILE_SWAP_CONVO
-- Reporte      : FILE_SWAP_CONVO
-- ============================================================

-- ============================================================
-- SECTION 00 | BRONZE.[LMDA].[SWAP_CONVO]  — CREATE TABLE
-- ============================================================
USE [BRONZE]
GO

IF NOT EXISTS (
    SELECT 1
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'LMDA' AND TABLE_NAME = 'SWAP_CONVO'
)
BEGIN
    CREATE TABLE [LMDA].[SWAP_CONVO]
    (
        [ID] uniqueidentifier NOT NULL CONSTRAINT [DF_LMDA_SWAP_CONVO_ID] DEFAULT (NEWID()),
        [NUM_ID] varchar(34) NOT NULL,
        [FE_CON_OPE] date NOT NULL,
        [FE_VEN_FLU_R] date NOT NULL,
        [FE_VEN_FLU_E] date NOT NULL,
        [ACT_OPE] numeric(15,0) NOT NULL,
        [MON_ACT_OPE] varchar(3) NOT NULL,
        [ACT_OPE_ME] numeric(15,0) NOT NULL,
        [MON_ACT_OPE_ME] varchar(3) NOT NULL,
        [PAS_OPE] numeric(15,0) NOT NULL,
        [MON_PAS_OPE] varchar(3) NOT NULL,
        [PAS_OPE_MR] numeric(15,0) NOT NULL,
        [MON_PAS_OPE_MR] varchar(3) NOT NULL,
        [DUR_ACT] numeric(15,0) NOT NULL,
        [DUR_PAS] numeric(15,0) NOT NULL,
        [ID_GAR] varchar(20) NOT NULL,
        [NOCIONAL] numeric(15,0) NOT NULL,
        [MON_NOCIONAL] varchar(3) NOT NULL,
        [FECHAINFO] date NOT NULL,
        [FECHA_EXTRACCION] smalldatetime NOT NULL CONSTRAINT [DF_LMDA_SWAP_CONVO_FECHA_EXTRACCION] DEFAULT (GETDATE())
    );
    PRINT 'BRONZE.LMDA.SWAP_CONVO creada.';
END
ELSE
    PRINT 'BRONZE.LMDA.SWAP_CONVO ya existe — sin cambios.';
GO

-- ============================================================
-- SECTION 01 | SILVER.[RR].[021_ENT_SWAPS_CONVO]  — ajuste de estructura
--   01a: DROP columnas obsoletas (no presentes en layout V10)
--   01b: ADD  FECHAINFO date NOT NULL
--   01c: ALTER NOCIONAL y MON_NOCIONAL a NOT NULL
-- ============================================================
USE [SILVER]
GO

-- 01a: DROP columnas obsoletas
IF EXISTS (SELECT 1
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='021_ENT_SWAPS_CONVO' AND COLUMN_NAME='NOCIONAL_VAL')
    ALTER TABLE [RR].[021_ENT_SWAPS_CONVO] DROP COLUMN [NOCIONAL_VAL];
GO
USE [SILVER]
GO
IF EXISTS (SELECT 1
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='021_ENT_SWAPS_CONVO' AND COLUMN_NAME='PAS_OPE_MR_VAL')
    ALTER TABLE [RR].[021_ENT_SWAPS_CONVO] DROP COLUMN [PAS_OPE_MR_VAL];
GO
USE [SILVER]
GO
IF EXISTS (SELECT 1
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='021_ENT_SWAPS_CONVO' AND COLUMN_NAME='PAS_OPE_VAL')
    ALTER TABLE [RR].[021_ENT_SWAPS_CONVO] DROP COLUMN [PAS_OPE_VAL];
GO
USE [SILVER]
GO
IF EXISTS (SELECT 1
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='021_ENT_SWAPS_CONVO' AND COLUMN_NAME='ACT_OPE_ME_VAL')
    ALTER TABLE [RR].[021_ENT_SWAPS_CONVO] DROP COLUMN [ACT_OPE_ME_VAL];
GO
USE [SILVER]
GO
IF EXISTS (SELECT 1
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='021_ENT_SWAPS_CONVO' AND COLUMN_NAME='ACT_OPE_VAL')
    ALTER TABLE [RR].[021_ENT_SWAPS_CONVO] DROP COLUMN [ACT_OPE_VAL];
GO
USE [SILVER]
GO
IF EXISTS (SELECT 1
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='021_ENT_SWAPS_CONVO' AND COLUMN_NAME='FE_CORTE')
    ALTER TABLE [RR].[021_ENT_SWAPS_CONVO] DROP COLUMN [FE_CORTE];
GO
USE [SILVER]
GO
IF EXISTS (SELECT 1
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='021_ENT_SWAPS_CONVO' AND COLUMN_NAME='SEC_SWAP')
    ALTER TABLE [RR].[021_ENT_SWAPS_CONVO] DROP COLUMN [SEC_SWAP];
GO
USE [SILVER]
GO
IF EXISTS (SELECT 1
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='021_ENT_SWAPS_CONVO' AND COLUMN_NAME='OBJ_OPE')
    ALTER TABLE [RR].[021_ENT_SWAPS_CONVO] DROP COLUMN [OBJ_OPE];
GO

-- 01b: ADD FECHAINFO (tabla vacia — se agrega directamente con DEFAULT temporal para NOT NULL)
USE [SILVER]
GO
IF NOT EXISTS (
    SELECT 1
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='021_ENT_SWAPS_CONVO' AND COLUMN_NAME='FECHAINFO'
)
BEGIN
    ALTER TABLE [RR].[021_ENT_SWAPS_CONVO]
        ADD [FECHAINFO] date NOT NULL
            CONSTRAINT [DF_RR_021_ENT_SWAPS_CONVO_FECHAINFO_TMP] DEFAULT ('19000101');

    ALTER TABLE [RR].[021_ENT_SWAPS_CONVO]
        DROP CONSTRAINT [DF_RR_021_ENT_SWAPS_CONVO_FECHAINFO_TMP];

    PRINT 'ADD FECHAINFO OK.';
END
ELSE
    PRINT 'FECHAINFO ya existe — sin cambios.';
GO

-- 01c: NOCIONAL y MON_NOCIONAL a NOT NULL
USE [SILVER]
GO
IF EXISTS (
    SELECT 1
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='021_ENT_SWAPS_CONVO'
    AND COLUMN_NAME='NOCIONAL' AND IS_NULLABLE='YES'
)
BEGIN
    ALTER TABLE [RR].[021_ENT_SWAPS_CONVO]
        ALTER COLUMN [NOCIONAL] numeric(15,0) NOT NULL;
    PRINT 'NOCIONAL -> NOT NULL OK.';
END
GO
USE [SILVER]
GO
IF EXISTS (
    SELECT 1
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='021_ENT_SWAPS_CONVO'
    AND COLUMN_NAME='MON_NOCIONAL' AND IS_NULLABLE='YES'
)
BEGIN
    ALTER TABLE [RR].[021_ENT_SWAPS_CONVO]
        ALTER COLUMN [MON_NOCIONAL] varchar(3) NOT NULL;
    PRINT 'MON_NOCIONAL -> NOT NULL OK.';
END
GO

-- ============================================================
-- SECTION 02 | SP SILVER — [dbo].[021_ENT_SWAPS_CONVO]
--   Origen      : BRONZE.LMDA.SWAP_CONVO
--   Periodicidad: Semanal
--   Control LMDA: FECHAINFO
--   Correcciones:
--     - Self-select eliminado; fuente es BRONZE.LMDA.SWAP_CONVO
--     - Filtro corregido: semanal por FECHAINFO
--     - Columnas obsoletas eliminadas del INSERT
--     - Columnas NOCIONAL, MON_NOCIONAL, FECHAINFO incluidas
-- ============================================================
USE [SILVER]
GO

CREATE OR ALTER PROCEDURE [dbo].[021_ENT_SWAPS_CONVO]
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
    DECLARE @NombreJob       NVARCHAR(128) = '[021_ENT_SWAPS_CONVO] ';

    -- Semanal
    DECLARE @FechaIni DATE = DATEADD(DAY, -((DATEPART(WEEKDAY, @FechaSistema) + 5) % 7), CAST(@FechaSistema AS DATE));
    DECLARE @FechaFin DATE = DATEADD(DAY, 7, @FechaIni);
    -- AJUSTE  021_ENT_SWAPS_CONVO_semanal
    -- Periodicidad : Semanal  |  Origen : LMDA (BRONZE.LMDA.SWAP_CONVO) | Layout : Layout_SWAPS_V10_FILE_SWAP_CONVO
    -- Reporte      : FILE_SWAP_CONVO
    BEGIN TRY

        IF EXISTS (
            SELECT 1
    FROM [SILVER].[RR].[021_ENT_SWAPS_CONVO]
    WHERE [FECHAINFO] >= @FechaIni AND [FECHAINFO] < @FechaFin
        )
        BEGIN
        DELETE FROM [SILVER].[RR].[021_ENT_SWAPS_CONVO]
            WHERE [FECHAINFO] >= @FechaIni AND [FECHAINFO] < @FechaFin;

        SET @FilasEliminadas = @@ROWCOUNT;
        SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
        PRINT @LogMessage;
        SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
    END;

        INSERT INTO [RR].[021_ENT_SWAPS_CONVO]
        (
        [NUM_ID],
        [FE_CON_OPE],
        [FE_VEN_FLU_R],
        [FE_VEN_FLU_E],
        [ACT_OPE],
        [MON_ACT_OPE],
        [ACT_OPE_ME],
        [MON_ACT_OPE_ME],
        [PAS_OPE],
        [MON_PAS_OPE],
        [PAS_OPE_MR],
        [MON_PAS_OPE_MR],
        [DUR_ACT],
        [DUR_PAS],
        [ID_GAR],
        [NOCIONAL],
        [MON_NOCIONAL],
        [FECHAINFO]
        )
    SELECT
        T.[NUM_ID],
        T.[FE_CON_OPE],
        T.[FE_VEN_FLU_R],
        T.[FE_VEN_FLU_E],
        T.[ACT_OPE],
        T.[MON_ACT_OPE],
        T.[ACT_OPE_ME],
        T.[MON_ACT_OPE_ME],
        T.[PAS_OPE],
        T.[MON_PAS_OPE],
        T.[PAS_OPE_MR],
        T.[MON_PAS_OPE_MR],
        T.[DUR_ACT],
        T.[DUR_PAS],
        T.[ID_GAR],
        T.[NOCIONAL],
        T.[MON_NOCIONAL],
        T.[FECHAINFO]
    FROM [BRONZE].[LMDA].[SWAP_CONVO] T
    WHERE T.[FECHAINFO] >= @FechaIni AND T.[FECHAINFO] < @FechaFin;

        SET @FilasInsertadas = @@ROWCOUNT;
        SET @LogMessage = 'Proceso completado. Filas totales: ' + CAST(@FilasInsertadas AS NVARCHAR(10));
        PRINT @LogMessage;
        SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);

    END TRY

    BEGIN CATCH
        SET @ExitoEjecucion = 0;
        SET @MensajeError   = ERROR_MESSAGE();
        SET @LogMessage     = 'Error durante la ejecucion: ' + @MensajeError;
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
        SET @Cuerpo = 'Se ha producido un error durante la ejecucion de ' + @NombreJob + CHAR(13) + CHAR(10)
            + 'Mensaje de Error:' + CHAR(13) + CHAR(10) + @MensajeError + CHAR(13) + CHAR(10)
            + 'Log de Ejecucion:' + CHAR(13) + CHAR(10) + @DetallesLog;

        BEGIN TRY
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = @PerfilCorreo,
                @recipients   = @CorreoNotificacion,
                @subject      = @Asunto,
                @body         = @Cuerpo,
                @body_format  = 'TEXT',
                @importance   = 'High';
        END TRY
        BEGIN CATCH
            PRINT 'Error al enviar alerta: ' + ERROR_MESSAGE();
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

    PRINT 'Proceso completado y registrado en la tabla de log.';
END;
GO

-- ============================================================
-- SECTION 03 | SP ION — [dbo].[021_ENT_SWAPS_CONVO]
--   Columnas : ORDEN 1-18 del layout
--   Sin ID ni FECHA_EXTRACCION
--   Fechas   : FORMAT yyyy/MM/dd — FE_CON_OPE(2), FE_VEN_FLU_R(3), FE_VEN_FLU_E(4), FECHAINFO(18)
--   Filtro   : ventana semanal por FECHAINFO
--   Correcciones:
--     - Filtro imposible (>= @FECHA AND < @FECHA) corregido a ventana semanal
--     - ID y FECHA_EXTRACCION eliminados del SELECT
--     - Columnas obsoletas eliminadas; NOCIONAL, MON_NOCIONAL, FECHAINFO incluidas
--     - FORMAT aplicado a todas las fechas
--     - ORDEN 1-18 respetado
-- ============================================================
USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[021_ENT_SWAPS_CONVO]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    -- Semanal
    DECLARE @FechaIni DATE = DATEADD(DAY, -((DATEPART(WEEKDAY, @FECHA) + 5) % 7), @FECHA);
    DECLARE @FechaFin DATE = DATEADD(DAY, 7, @FechaIni);
    -- AJUSTE  021_ENT_SWAPS_CONVO_semanal
    -- Periodicidad : Semanal  |  Origen : LMDA (BRONZE.LMDA.SWAP_CONVO) | Layout : Layout_SWAPS_V10_FILE_SWAP_CONVO
    -- Reporte      : FILE_SWAP_CONVO
    SELECT
        T.[NUM_ID]                               AS [NUM_ID], -- ORDEN 1
        FORMAT(T.[FE_CON_OPE],   'yyyy/MM/dd')  AS [FE_CON_OPE], -- ORDEN 2
        FORMAT(T.[FE_VEN_FLU_R], 'yyyy/MM/dd')  AS [FE_VEN_FLU_R], -- ORDEN 3
        FORMAT(T.[FE_VEN_FLU_E], 'yyyy/MM/dd')  AS [FE_VEN_FLU_E], -- ORDEN 4
        T.[ACT_OPE]                              AS [ACT_OPE], -- ORDEN 5
        T.[MON_ACT_OPE]                          AS [MON_ACT_OPE], -- ORDEN 6
        T.[ACT_OPE_ME]                           AS [ACT_OPE_ME], -- ORDEN 7
        T.[MON_ACT_OPE_ME]                       AS [MON_ACT_OPE_ME], -- ORDEN 8
        T.[PAS_OPE]                              AS [PAS_OPE], -- ORDEN 9
        T.[MON_PAS_OPE]                          AS [MON_PAS_OPE], -- ORDEN 10
        T.[PAS_OPE_MR]                           AS [PAS_OPE_MR], -- ORDEN 11
        T.[MON_PAS_OPE_MR]                       AS [MON_PAS_OPE_MR], -- ORDEN 12
        T.[DUR_ACT]                              AS [DUR_ACT], -- ORDEN 13
        T.[DUR_PAS]                              AS [DUR_PAS], -- ORDEN 14
        T.[ID_GAR]                               AS [ID_GAR], -- ORDEN 15
        T.[NOCIONAL]                             AS [NOCIONAL], -- ORDEN 16
        T.[MON_NOCIONAL]                         AS [MON_NOCIONAL], -- ORDEN 17
        FORMAT(T.[FECHAINFO],    'yyyy/MM/dd')   AS [FECHAINFO]
    -- ORDEN 18
    FROM [SILVER].[RR].[021_ENT_SWAPS_CONVO] T
    WHERE T.[FECHAINFO] >= @FechaIni AND T.[FECHAINFO] < @FechaFin;

END;
GO

-- ============================================================
-- SECTION 04 | INDICE_REPORTES — corregir frecuencia Diaria -> Semanal
-- ============================================================
USE [ION]
GO

UPDATE [dbo].[INDICE_REPORTES]
SET [frecuencia] = 'Semanal'
WHERE [numero] = 21;

SELECT numero, nombre, frecuencia, activo, nombre_archivo
FROM dbo.INDICE_REPORTES
WHERE numero = 21;
GO
