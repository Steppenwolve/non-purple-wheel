-- ============================================================
-- AJUSTE  093_ENT_CF — Migrar control de fecha a FECHA_EXTRACCION
-- FECHA_INFO se elimina: el ETL nunca la popula (siempre NULL).
-- El filtro semanal se aplica sobre CAST(FECHA_EXTRACCION AS DATE).
-- FECHA_EXTRACCION NO se expone en la salida del SP ION.
-- ============================================================

-- ============================================================
-- S01 | BRONZE — DROP FECHA_INFO
-- ============================================================
USE [BRONZE]
GO

IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='LMDA' AND TABLE_NAME='CF_I' AND COLUMN_NAME='FECHA_INFO'
)
BEGIN
    ALTER TABLE [LMDA].[CF_I] DROP COLUMN [FECHA_INFO];
    PRINT '>> BRONZE: FECHA_INFO eliminada de LMDA.CF_I.';
END
ELSE
    PRINT '>> BRONZE: FECHA_INFO no existia.';
GO

-- ============================================================
-- S02 | SILVER — DROP FECHA_INFO + FECHA_INICIO/VENC a varchar(10)
-- ============================================================
USE [SILVER]
GO

IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='093_ENT_CF' AND COLUMN_NAME='FECHA_INFO'
)
BEGIN
    ALTER TABLE [RR].[093_ENT_CF] DROP COLUMN [FECHA_INFO];
    PRINT '>> SILVER: FECHA_INFO eliminada de RR.093_ENT_CF.';
END
ELSE
    PRINT '>> SILVER: FECHA_INFO no existia.';
GO

USE [SILVER]
GO

-- FECHA_INICIO: date -> varchar(10) para almacenar DD/MM/YYYY
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='093_ENT_CF'
      AND COLUMN_NAME='FECHA_INICIO' AND DATA_TYPE='date'
)
BEGIN
    ALTER TABLE [RR].[093_ENT_CF] ALTER COLUMN [FECHA_INICIO] varchar(10) NOT NULL;
    PRINT '>> SILVER: FECHA_INICIO cambiada a varchar(10).';
END
GO

USE [SILVER]
GO

-- FECHA_VENC: date -> varchar(10) para almacenar DD/MM/YYYY
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='093_ENT_CF'
      AND COLUMN_NAME='FECHA_VENC' AND DATA_TYPE='date'
)
BEGIN
    ALTER TABLE [RR].[093_ENT_CF] ALTER COLUMN [FECHA_VENC] varchar(10) NOT NULL;
    PRINT '>> SILVER: FECHA_VENC cambiada a varchar(10).';
END
GO

-- ============================================================
-- S03 | SP SILVER — filtro semanal por FECHA_EXTRACCION
-- ============================================================
USE [SILVER]
GO

CREATE OR ALTER PROCEDURE [dbo].[093_ENT_CF]
    @CorreoNotificacion NVARCHAR(255) = NULL,
    @PerfilCorreo       NVARCHAR(255) = NULL,
    @ProgramadorJob     NVARCHAR(128) = NULL,
    @FechaSistema       DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @MensajeError NVARCHAR(MAX)='', @ExitoEjecucion BIT=1,
            @FilasInsertadas INT=0, @FilasEliminadas INT=0,
            @LogMessage NVARCHAR(MAX)='', @DetallesLog NVARCHAR(MAX)='',
            @FechaInicio DATETIME=GETDATE(), @NombreJob NVARCHAR(128)='[093_ENT_CF]',
            @FechaIni DATE, @FechaFin DATE;

    BEGIN TRY
        -- Ventana semanal: lunes de la semana de @FechaSistema
        SET @FechaIni = DATEADD(DAY, -(DATEPART(WEEKDAY, @FechaSistema) + 5) % 7, CAST(@FechaSistema AS DATE));
        SET @FechaFin = DATEADD(DAY, 7, @FechaIni);

        -- Limpiar SILVER para la semana (por fecha de extracción)
        IF EXISTS (
            SELECT 1 FROM [SILVER].[RR].[093_ENT_CF]
            WHERE CAST([FECHA_EXTRACCION] AS DATE) >= @FechaIni
              AND CAST([FECHA_EXTRACCION] AS DATE) <  @FechaFin
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[093_ENT_CF]
            WHERE CAST([FECHA_EXTRACCION] AS DATE) >= @FechaIni
              AND CAST([FECHA_EXTRACCION] AS DATE) <  @FechaFin;
            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage; SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13)+CHAR(10);
        END

        -- Insertar desde BRONZE lo cargado en la semana corriente
        -- FECHA_INICIO y FECHA_VENC se convierten a DD/MM/YYYY (CONVERT estilo 103)
        INSERT INTO [RR].[093_ENT_CF] (
            [TIPOOPERACION],[TIPOFONDEO],[FECHA_INICIO],[FECHA_VENC],
            [MONTO_OPER],[MONEDA],[CVE_ACREEDOR],[TIP_REL_ACREED],[CVE_OPERACION]
        )
        SELECT
            R.[TIPOOPERACION], R.[TIPOFONDEO],
            CONVERT(varchar(10), R.[FECHA_INICIO], 103),
            CONVERT(varchar(10), R.[FECHA_VENC],   103),
            R.[MONTO_OPER], R.[MONEDA], R.[CVE_ACREEDOR], R.[TIP_REL_ACREED], R.[CVE_OPERACION]
        FROM [BRONZE].[LMDA].[CF_I] R
        WHERE CAST(R.[FECHA_EXTRACCION] AS DATE) >= @FechaIni
          AND CAST(R.[FECHA_EXTRACCION] AS DATE) <  @FechaFin;

        SET @FilasInsertadas = @@ROWCOUNT;
        SET @LogMessage = 'Proceso completado. Filas totales: ' + CAST(@FilasInsertadas AS NVARCHAR(10));
        PRINT @LogMessage; SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13)+CHAR(10);
    END TRY
    BEGIN CATCH
        SET @ExitoEjecucion=0; SET @MensajeError=ERROR_MESSAGE();
        SET @DetallesLog = @DetallesLog + 'Error durante la ejecucion: ' + @MensajeError + CHAR(13)+CHAR(10);
    END CATCH

    IF @ExitoEjecucion=0 AND @CorreoNotificacion IS NOT NULL AND @PerfilCorreo IS NOT NULL
    BEGIN
        DECLARE @Asunto NVARCHAR(255)='ALERTA: Error en ' + @NombreJob;
        DECLARE @Cuerpo NVARCHAR(MAX)='Error en ' + @NombreJob + CHAR(13)+CHAR(10) +
            '- Programado por: ' + ISNULL(@ProgramadorJob,'No especificado') + CHAR(13)+CHAR(10) +
            '- Inicio: ' + CONVERT(VARCHAR,@FechaInicio,120) + CHAR(13)+CHAR(10) +
            '- Mensaje: ' + @MensajeError + CHAR(13)+CHAR(10) + 'Log:' + CHAR(13)+CHAR(10) + @DetallesLog;
        BEGIN TRY
            EXEC msdb.dbo.sp_send_dbmail @profile_name=@PerfilCorreo, @recipients=@CorreoNotificacion,
                 @subject=@Asunto, @body=@Cuerpo, @body_format='TEXT', @importance='High';
        END TRY BEGIN CATCH
            SET @DetallesLog = @DetallesLog + 'Error al enviar alerta: ' + ERROR_MESSAGE() + CHAR(13)+CHAR(10);
        END CATCH
    END

    INSERT INTO dbo.LogSilverDiario
        (FechaEjecucion, FilasInsertadas, EstadoEjecucion, MensajeError, DetallesLog, NombreJob, ProgramadorJob)
    VALUES (@FechaInicio, @FilasInsertadas,
        CASE WHEN @ExitoEjecucion=1 THEN 'Exitoso' ELSE 'Error' END,
        CASE WHEN @ExitoEjecucion=1 THEN NULL ELSE @MensajeError END,
        @DetallesLog, @NombreJob, @ProgramadorJob);
END;
GO

-- ============================================================
-- S04 | SP ION — filtro semanal por FECHA_EXTRACCION, 9 cols
-- ============================================================
USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[093_ENT_CF]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @FechaIni DATE, @FechaFin DATE;
    SET @FechaIni = DATEADD(DAY, -(DATEPART(WEEKDAY, @FECHA) + 5) % 7, @FECHA);
    SET @FechaFin = DATEADD(DAY, 7, @FechaIni);

    SELECT
        [TIPOOPERACION]                         AS TIPOOPERACION,   -- ORDEN 1
        [TIPOFONDEO]                            AS TIPOFONDEO,      -- ORDEN 2
        [FECHA_INICIO]                          AS FECHA_INICIO,    -- ORDEN 3
        [FECHA_VENC]                            AS FECHA_VENC,      -- ORDEN 4
        [MONTO_OPER]                            AS MONTO_OPER,      -- ORDEN 5
        [MONEDA]                                AS MONEDA,          -- ORDEN 6
        [CVE_ACREEDOR]                          AS CVE_ACREEDOR,    -- ORDEN 7
        [CVE_OPERACION]                         AS CVE_OPERACION,   -- ORDEN 8
        [TIP_REL_ACREED]                        AS TIP_REL_ACREED   -- ORDEN 9
    FROM [SILVER].[RR].[093_ENT_CF]
    WHERE CAST([FECHA_EXTRACCION] AS DATE) >= @FechaIni
      AND CAST([FECHA_EXTRACCION] AS DATE) <  @FechaFin;
END;
GO
