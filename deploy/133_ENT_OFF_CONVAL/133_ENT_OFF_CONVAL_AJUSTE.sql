-- ============================================================
-- AJUSTE  133_ENT_OFF_CONVAL  |  Layout OFF_FX_V11_OFF_CONVAL
-- Periodicidad : Semanal   |  Origen : LMDA (BRONZE.LMDA.OFF_CONVAL)
-- Reporte      : FILE_OFF_CONVAL
-- ============================================================

-- ============================================================
-- SECTION 00 | BRONZE.[LMDA].[OFF_CONVAL]  — CREATE TABLE
-- ============================================================
USE [BRONZE]
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'LMDA' AND TABLE_NAME = 'OFF_CONVAL'
)
BEGIN
    CREATE TABLE [LMDA].[OFF_CONVAL] (
        [ID]               uniqueidentifier NOT NULL CONSTRAINT [DF_LMDA_OFF_CONVAL_ID] DEFAULT (NEWID()),
        [FE_CON_OPE]       date             NOT NULL,
        [NUM_ID]           varchar(20)      NOT NULL,
        -- PosicionOperacion_V4: S01, S02, C01, C02, P02, P03, NA (hasta 3 chars)
        [POS_OPER]         varchar(3)       NOT NULL,
        [OBJ_OPE]          varchar(2)       NOT NULL,
        [PAQ_EST]          numeric(2,0)     NOT NULL,
        [ID_PAQ_EST]       varchar(20)      NOT NULL,
        [CON_PAQ_EST]      numeric(3,0)     NOT NULL,
        [ACT_OPE]          numeric(15,0)    NOT NULL,
        [MON_ACT_OPE]      varchar(3)       NOT NULL,
        [PAS_OPE]          numeric(15,0)    NOT NULL,
        [MON_PAS_OPE]      varchar(3)       NOT NULL,
        [DUR_ACT]          numeric(5,0)     NOT NULL,
        [DUR_PAS]          numeric(5,0)     NOT NULL,
        [ID_GAR_VG]        varchar(20)      NOT NULL,
        [NOCIONAL]         numeric(15,0)    NULL,
        [MON_NOCIONAL]     varchar(3)       NULL,
        [FECHAINFO]        date             NULL,
        [FECHA_EXTRACCION] smalldatetime    NOT NULL CONSTRAINT [DF_LMDA_OFF_CONVAL_FECHA_EXTRACCION] DEFAULT (GETDATE())
    );
    PRINT 'BRONZE.LMDA.OFF_CONVAL creada.';
END
ELSE
    PRINT 'BRONZE.LMDA.OFF_CONVAL ya existe — sin cambios.';
GO

-- ============================================================
-- SECTION 01 | SILVER.[RR].[133_ENT_OFF_CONVAL]
--   01a: ALTER POS_OPER varchar(1) -> varchar(3)
--        (Catalogo PosicionOperacion_V4: S01,S02,C01,C02,P02,P03,NA)
--   01b: DROP columnas extra no presentes en layout V11:
--        FE_CORTE, ACT_OPE_VAL, PAS_OPE_VAL
-- ============================================================
USE [SILVER]
GO

-- SECTION 01a: POS_OPER varchar(1) -> varchar(3)
-- Catalogo PosicionOperacion_V4 tiene claves de hasta 3 caracteres (S01, S02, C01, C02, P02, P03, NA)
ALTER TABLE [RR].[133_ENT_OFF_CONVAL]
    ALTER COLUMN [POS_OPER] varchar(3) NOT NULL;
GO

USE [SILVER]
GO

-- SECTION 01b: DROP columnas extra
-- FE_CORTE
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='133_ENT_OFF_CONVAL' AND COLUMN_NAME='FE_CORTE'
)
BEGIN
    ALTER TABLE [RR].[133_ENT_OFF_CONVAL] DROP COLUMN [FE_CORTE];
    PRINT 'DROP COLUMN FE_CORTE OK.';
END

-- ACT_OPE_VAL
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='133_ENT_OFF_CONVAL' AND COLUMN_NAME='ACT_OPE_VAL'
)
BEGIN
    ALTER TABLE [RR].[133_ENT_OFF_CONVAL] DROP COLUMN [ACT_OPE_VAL];
    PRINT 'DROP COLUMN ACT_OPE_VAL OK.';
END

-- PAS_OPE_VAL
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='133_ENT_OFF_CONVAL' AND COLUMN_NAME='PAS_OPE_VAL'
)
BEGIN
    ALTER TABLE [RR].[133_ENT_OFF_CONVAL] DROP COLUMN [PAS_OPE_VAL];
    PRINT 'DROP COLUMN PAS_OPE_VAL OK.';
END
GO

-- ============================================================
-- SECTION 02 | SP SILVER — [dbo].[133_ENT_OFF_CONVAL]
--   Origen : BRONZE.LMDA.OFF_CONVAL
--   Periodicidad : Semanal
--   Control LMDA : FECHAINFO
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

    DECLARE @MensajeError     NVARCHAR(MAX) = '';
    DECLARE @ExitoEjecucion   BIT           = 1;
    DECLARE @FilasInsertadas  INT           = 0;
    DECLARE @LogMessage       NVARCHAR(MAX) = '';
    DECLARE @DetallesLog      NVARCHAR(MAX) = '';
    DECLARE @FechaInicio      DATETIME      = GETDATE();
    DECLARE @FilasEliminadas  INT           = 0;
    DECLARE @NombreJob        NVARCHAR(128) = '[133_ENT_OFF_CONVAL] ';

    DECLARE @FechaIni DATE = DATEADD(DAY, -((DATEPART(WEEKDAY, @FechaSistema) + 5) % 7), CAST(@FechaSistema AS DATE));
    DECLARE @FechaFin DATE = DATEADD(DAY, 7, @FechaIni);

    -- POS_OPER: varchar(3) — catalogo PosicionOperacion_V4
    -- Valores validos: S01 (simple inicio), S02 (simple fin), C01 (compuesta inicio),
    --                  C02 (compuesta fin), P02 (precio inicio), P03 (precio periodo), NA (fija)

    BEGIN TRY --------------------------------------------------------------------------------

        IF EXISTS (
            SELECT 1 FROM [SILVER].[RR].[133_ENT_OFF_CONVAL]
            WHERE [FECHAINFO] >= @FechaIni AND [FECHAINFO] < @FechaFin
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[133_ENT_OFF_CONVAL]
            WHERE [FECHAINFO] >= @FechaIni AND [FECHAINFO] < @FechaFin;

            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

        INSERT INTO [RR].[133_ENT_OFF_CONVAL] (
            [FE_CON_OPE],
            [NUM_ID],
            [POS_OPER],
            [OBJ_OPE],
            [PAQ_EST],
            [ID_PAQ_EST],
            [CON_PAQ_EST],
            [ACT_OPE],
            [MON_ACT_OPE],
            [PAS_OPE],
            [MON_PAS_OPE],
            [DUR_ACT],
            [DUR_PAS],
            [ID_GAR_VG],
            [NOCIONAL],
            [MON_NOCIONAL],
            [FECHAINFO]
        )
        SELECT
            O.[FE_CON_OPE],
            O.[NUM_ID],
            O.[POS_OPER],
            O.[OBJ_OPE],
            O.[PAQ_EST],
            O.[ID_PAQ_EST],
            O.[CON_PAQ_EST],
            O.[ACT_OPE],
            O.[MON_ACT_OPE],
            O.[PAS_OPE],
            O.[MON_PAS_OPE],
            O.[DUR_ACT],
            O.[DUR_PAS],
            O.[ID_GAR_VG],
            O.[NOCIONAL],
            O.[MON_NOCIONAL],
            O.[FECHAINFO]
        FROM [BRONZE].[LMDA].[OFF_CONVAL] O
        WHERE O.[FECHAINFO] >= @FechaIni AND O.[FECHAINFO] < @FechaFin;

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
        SET @Cuerpo = 'Se ha producido un error durante la ejecución de ' + @NombreJob + CHAR(13) + CHAR(10)
            + 'Mensaje de Error:' + CHAR(13) + CHAR(10) + @MensajeError + CHAR(13) + CHAR(10)
            + 'Log de Ejecución:' + CHAR(13) + CHAR(10) + @DetallesLog;

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

    PRINT 'Proceso completado y registrado en la tabla de log.';
END;
GO

-- ============================================================
-- SECTION 03 | SP ION — [dbo].[133_ENT_OFF_CONVAL]
--   17 columnas del layout (ORDEN 1-17), fechas FORMAT yyyy/MM/dd
--   Filtro semanal por FECHAINFO
--   FECHAINFO se expone (es ORDEN 17 en el layout)
-- ============================================================
USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[133_ENT_OFF_CONVAL]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @FechaIni DATE = DATEADD(DAY, -((DATEPART(WEEKDAY, @FECHA) + 5) % 7), @FECHA);
    DECLARE @FechaFin DATE = DATEADD(DAY, 7, @FechaIni);

    -- POS_OPER: varchar(3) — catalogo PosicionOperacion_V4
    -- Valores validos: S01, S02, C01, C02, P02, P03, NA

    SELECT
        FORMAT(O.[FE_CON_OPE], 'yyyy/MM/dd') AS [FE_CON_OPE],
        O.[NUM_ID]                            AS [NUM_ID],
        O.[POS_OPER]                          AS [POS_OPER],
        O.[OBJ_OPE]                           AS [OBJ_OPE],
        O.[PAQ_EST]                           AS [PAQ_EST],
        O.[ID_PAQ_EST]                        AS [ID_PAQ_EST],
        O.[CON_PAQ_EST]                       AS [CON_PAQ_EST],
        O.[ACT_OPE]                           AS [ACT_OPE],
        O.[MON_ACT_OPE]                       AS [MON_ACT_OPE],
        O.[PAS_OPE]                           AS [PAS_OPE],
        O.[MON_PAS_OPE]                       AS [MON_PAS_OPE],
        O.[DUR_ACT]                           AS [DUR_ACT],
        O.[DUR_PAS]                           AS [DUR_PAS],
        O.[ID_GAR_VG]                         AS [ID_GAR_VG],
        O.[NOCIONAL]                          AS [NOCIONAL],
        O.[MON_NOCIONAL]                      AS [MON_NOCIONAL],
        FORMAT(O.[FECHAINFO], 'yyyy/MM/dd')   AS [FECHAINFO]
    FROM [SILVER].[RR].[133_ENT_OFF_CONVAL] O
    WHERE O.[FECHAINFO] >= @FechaIni AND O.[FECHAINFO] < @FechaFin;

END;
GO

-- ============================================================
-- SECTION 04 | INDICE_REPORTES — corregir frecuencia
-- ============================================================
USE [ION]
GO

UPDATE [dbo].[INDICE_REPORTES]
SET [frecuencia] = 'Semanal'
WHERE [numero] = 133 AND [frecuencia] <> 'Semanal';

IF @@ROWCOUNT > 0
    PRINT 'INDICE_REPORTES 133: frecuencia actualizada a Semanal.';
ELSE
    PRINT 'INDICE_REPORTES 133: ya estaba en Semanal.';
GO
