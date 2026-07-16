-- ============================================================
-- AJUSTE  23_ENT_R04A_MOV_420_24
-- Layout : V1.01_Credito_IFRS9_R04A_MOV_420_24 — Reportes 0420/0424
-- Periodo: Mensual | Origen: LMDA
-- ============================================================
-- S01 | BRONZE — Crear tabla LMDA.R04A_MOV_420_24 (nueva)
-- S02 | SILVER — Ajustar IMPORTE y MONEDA a NOT NULL
-- S03 | SP SILVER — Corregir self-select: leer desde BRONZE
-- ============================================================

-- ============================================================
-- S01 | BRONZE — Crear tabla
-- ============================================================
USE [BRONZE]
GO

IF OBJECT_ID('LMDA.[R04A_MOV_420_24]', 'U') IS NULL
CREATE TABLE [LMDA].[R04A_MOV_420_24] (
    [ID]               uniqueidentifier NOT NULL DEFAULT NEWID(),
    [CUENTA_CREDITO]   varchar(12)      NOT NULL,
    [ETAPA_DETERIORO]  numeric(1,0)     NOT NULL,
    [TIPO_MOV_420_424] numeric(16,2)    NOT NULL,
    [IMPORTE]          numeric(16,2)    NOT NULL,
    [MONEDA]           varchar(3)       NOT NULL,
    [FECHA_INFO]       date             NOT NULL,
    [FECHA_EXTRACCION] smalldatetime    NOT NULL DEFAULT GETDATE(),
    CONSTRAINT [PK_LMDA_R04A_MOV_420_24] PRIMARY KEY ([ID])
);
PRINT '>> BRONZE: tabla LMDA.R04A_MOV_420_24 creada.';
GO

-- ============================================================
-- S02 | SILVER — Ajustar IMPORTE y MONEDA a NOT NULL
-- ============================================================
USE [SILVER]
GO

-- IMPORTE: solo si actualmente es NULL
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='023_ENT_R04A_MOV_420_24'
      AND COLUMN_NAME='IMPORTE' AND IS_NULLABLE='YES'
)
BEGIN
    -- Sanear posibles NULLs antes de aplicar NOT NULL
    UPDATE [RR].[023_ENT_R04A_MOV_420_24] SET [IMPORTE] = 0 WHERE [IMPORTE] IS NULL;
    ALTER TABLE [RR].[023_ENT_R04A_MOV_420_24] ALTER COLUMN [IMPORTE] numeric(16,2) NOT NULL;
    PRINT '>> SILVER: IMPORTE ajustado a NOT NULL.';
END
GO

USE [SILVER]
GO

-- MONEDA: solo si actualmente es NULL
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='023_ENT_R04A_MOV_420_24'
      AND COLUMN_NAME='MONEDA' AND IS_NULLABLE='YES'
)
BEGIN
    UPDATE [RR].[023_ENT_R04A_MOV_420_24] SET [MONEDA] = 'MXN' WHERE [MONEDA] IS NULL;
    ALTER TABLE [RR].[023_ENT_R04A_MOV_420_24] ALTER COLUMN [MONEDA] varchar(3) NOT NULL;
    PRINT '>> SILVER: MONEDA ajustada a NOT NULL.';
END
GO

-- ============================================================
-- S03 | SP SILVER — Corregir self-select, leer desde BRONZE
-- ============================================================
USE [SILVER]
GO

CREATE OR ALTER PROCEDURE [dbo].[023_ENT_R04A_MOV_420_24]
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
    DECLARE @NombreJob       NVARCHAR(128) = '[023_ENT_R04A_MOV_420_24]';
    DECLARE @FechaIni        DATE;
    DECLARE @FechaFin        DATE;

    BEGIN TRY
        SET @FechaIni = DATEFROMPARTS(YEAR(@FechaSistema), MONTH(@FechaSistema), 1);
        SET @FechaFin = DATEADD(MONTH, 1, @FechaIni);

        IF EXISTS (
            SELECT 1 FROM [SILVER].[RR].[023_ENT_R04A_MOV_420_24]
            WHERE [FECHA_INFO] >= @FechaIni
              AND [FECHA_INFO] <  @FechaFin
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[023_ENT_R04A_MOV_420_24]
            WHERE [FECHA_INFO] >= @FechaIni
              AND [FECHA_INFO] <  @FechaFin;

            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

        INSERT INTO [RR].[023_ENT_R04A_MOV_420_24] (
            [CUENTA_CREDITO],
            [ETAPA_DETERIORO],
            [TIPO_MOV_420_424],
            [IMPORTE],
            [MONEDA],
            [FECHA_INFO]
        )
        SELECT
            [CUENTA_CREDITO],
            [ETAPA_DETERIORO],
            [TIPO_MOV_420_424],
            [IMPORTE],
            [MONEDA],
            [FECHA_INFO]
        FROM [BRONZE].[LMDA].[R04A_MOV_420_24]
        WHERE [FECHA_INFO] >= @FechaIni
          AND [FECHA_INFO] <  @FechaFin;

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
        SET @Cuerpo =
            'Se ha producido un error durante la ejecucion de ' + @NombreJob + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) +
            'Detalles del Job:' + CHAR(13) + CHAR(10) +
            '- Nombre del Job: '         + ISNULL(@NombreJob,     'No especificado') + CHAR(13) + CHAR(10) +
            '- Programado por: '         + ISNULL(@ProgramadorJob, 'No especificado') + CHAR(13) + CHAR(10) +
            '- Fecha y hora de inicio: ' + CONVERT(VARCHAR, @FechaInicio,       120)  + CHAR(13) + CHAR(10) +
            '- Fecha y hora de fin: '    + CONVERT(VARCHAR, @FechaFinalizacion,  120)  + CHAR(13) + CHAR(10) +
            '- Duracion: '               + @DuracionEjecucion + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) +
            'Mensaje de Error:' + CHAR(13) + CHAR(10) + @MensajeError + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) +
            'Log de Ejecucion:' + CHAR(13) + CHAR(10) + @DetallesLog;

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
