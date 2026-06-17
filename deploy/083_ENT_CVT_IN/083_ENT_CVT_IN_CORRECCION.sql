/* ============================================================================
   083_ENT_CVT_IN_CORRECCION.sql
   Reporte : CVT_IN  (Custodia / Incumplimientos - Diaria)
   Fin     : Corregir hallazgos detectados vs. Layout_CVT_IN_V3.xlsx:
               1. SILVER.RR.[083_ENT_CVT_IN] - ADD FECHA_INFO date
               2. SILVER.dbo.[083_ENT_CVT_IN] - eliminar ventana mensual
                  (codigo muerto), usar @FechaDia, incluir FECHA_INFO
               3. ION.dbo.[083_ENT_CVT_IN]   - remover ID y FECHA_EXTRACCION,
                  agregar FECHA_INFO, eliminar comentarios muertos
   Idempotente : cada bloque verifica estado antes de actuar.
   Entorno destino: SILVER e ION (mismo servidor).
   ============================================================================ */

/* --------------------------------------------------------------------------
   00 - PREFLIGHT
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id = o.schema_id
    WHERE s.name = 'RR' AND o.name = '083_ENT_CVT_IN' AND o.type = 'U'
)
BEGIN
    RAISERROR('Preflight fallido: SILVER.[RR].[083_ENT_CVT_IN] no existe. Abortando.', 16, 1);
    RETURN;
END
PRINT '>> Preflight OK: SILVER.[RR].[083_ENT_CVT_IN] existe.';
GO

/* --------------------------------------------------------------------------
   01 - TABLA: ADD FECHA_INFO date
        Layout campo #10: FECHA, formato AAAAMMDD.
        Ausente en la tabla original. Se agrega como NULL para compatibilidad
        con datos existentes.
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'RR' AND TABLE_NAME = '083_ENT_CVT_IN' AND COLUMN_NAME = 'FECHA_INFO'
)
BEGIN
    ALTER TABLE [RR].[083_ENT_CVT_IN]
        ADD [FECHA_INFO] date NULL;
    PRINT '>> Columna FECHA_INFO date agregada a SILVER.[RR].[083_ENT_CVT_IN].';
END
ELSE
    PRINT '>> FECHA_INFO ya existe. Sin cambios.';
GO

/* --------------------------------------------------------------------------
   02 - SP SILVER: CREATE OR ALTER con correcciones
        Cambios:
        - Eliminado calculo de ventana mensual (@FechaIni/@FechaFin): codigo muerto.
        - @FechaDia = CAST(@FechaSistema AS DATE) para comparaciones consistentes.
        - FECHA_INFO incluida en INSERT (= @FechaDia) y SELECT.
        - DELETE e IF EXISTS usan @FechaDia en lugar de @FechaSistema (DATETIME).
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[083_ENT_CVT_IN]
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
    DECLARE @FilasEliminadas INT           = 0;
    DECLARE @LogMessage      NVARCHAR(MAX) = '';
    DECLARE @DetallesLog     NVARCHAR(MAX) = '';
    DECLARE @FechaInicio     DATETIME      = GETDATE();
    DECLARE @NombreJob       NVARCHAR(128) = '[083_ENT_CVT_IN]';
    DECLARE @FechaDia        DATE          = CAST(@FechaSistema AS DATE);

    BEGIN TRY
        IF EXISTS (
            SELECT 1 FROM [SILVER].[RR].[083_ENT_CVT_IN]
            WHERE [FECHACONCERTACION] = @FechaDia
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[083_ENT_CVT_IN]
            WHERE [FECHACONCERTACION] = @FechaDia;

            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END

        INSERT INTO [RR].[083_ENT_CVT_IN] (
            [FECHACONCERTACION],
            [NUMEROOPERACIONINCUMPLIDA],
            [SECCION],
            [FECHAREGISTROINCUMPLIMIENTO],
            [TIPOINCUMPLIMIENTO],
            [NUMEROTITULOSINCUMPLIDOS],
            [NUMEROINCUMPLIMIENTO],
            [CAUSANTEINCUMPLIMIENTO],
            [RAZONINCUMPLIMIENTO],
            [TIPOMODIFICACION],
            [FECHA_INFO]
        )
        SELECT
            [FECHACONCERTACION],
            [NUMEROOPERACIONINCUMPLIDA],
            [SECCION],
            [FECHAREGISTROINCUMPLIMIENTO],
            [TIPOINCUMPLIMIENTO],
            [NUMEROTITULOSINCUMPLIDOS],
            [NUMEROINCUMPLIMIENTO],
            [CAUSANTEINCUMPLIMIENTO],
            [RAZONINCUMPLIMIENTO],
            [TIPOMODIFICACION],
            @FechaDia
        FROM [SILVER].[RR].[083_ENT_CVT_IN]
        WHERE [FECHACONCERTACION] = @FechaDia;

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
            'Error en ' + @NombreJob + CHAR(13)+CHAR(10) +
            '- Job: '        + ISNULL(@NombreJob,     'No especificado') + CHAR(13)+CHAR(10) +
            '- Programado: ' + ISNULL(@ProgramadorJob, 'No especificado') + CHAR(13)+CHAR(10) +
            '- Inicio: '     + CONVERT(VARCHAR, @FechaInicio,       120)  + CHAR(13)+CHAR(10) +
            '- Fin: '        + CONVERT(VARCHAR, @FechaFinalizacion,  120)  + CHAR(13)+CHAR(10) +
            '- Duracion: '   + @DuracionEjecucion + CHAR(13)+CHAR(10) +
            'Error: '        + @MensajeError      + CHAR(13)+CHAR(10) +
            'Log: '          + @DetallesLog;
        BEGIN TRY
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = @PerfilCorreo,
                @recipients   = @CorreoNotificacion,
                @subject      = @Asunto,
                @body         = @Cuerpo,
                @body_format  = 'TEXT',
                @importance   = 'High';
            SET @DetallesLog = @DetallesLog + 'Alerta enviada.' + CHAR(13)+CHAR(10);
        END TRY
        BEGIN CATCH
            SET @DetallesLog = @DetallesLog + 'Error al enviar alerta: ' + ERROR_MESSAGE() + CHAR(13)+CHAR(10);
        END CATCH
    END

    INSERT INTO dbo.LogSilverDiario
        (FechaEjecucion, FilasInsertadas, EstadoEjecucion, MensajeError, DetallesLog, NombreJob, ProgramadorJob)
    VALUES (
        @FechaInicio,
        @FilasInsertadas,
        CASE WHEN @ExitoEjecucion = 1 THEN 'Exitoso' ELSE 'Error' END,
        CASE WHEN @ExitoEjecucion = 1 THEN NULL      ELSE @MensajeError END,
        @DetallesLog,
        @NombreJob,
        @ProgramadorJob
    );
END;
GO
PRINT '>> SILVER.dbo.[083_ENT_CVT_IN] actualizado.';
GO

/* --------------------------------------------------------------------------
   03 - SP ION: CREATE OR ALTER con correcciones
        Cambios:
        - Removidos ID y FECHA_EXTRACCION del SELECT.
        - Agregada FECHA_INFO al SELECT.
        - Eliminados comentarios muertos al final.
   -------------------------------------------------------------------------- */
USE [ION];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[083_ENT_CVT_IN]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    -- NOTA (formato de fecha): el layout marca AAAAMMDD; por estandar (consideracion 12)
    -- la salida se entrega en AAAA/MM/DD via FORMAT(...,'yyyy/MM/dd').
    SELECT
        FORMAT([FECHACONCERTACION], 'yyyy/MM/dd')          AS [FECHACONCERTACION],
        [NUMEROOPERACIONINCUMPLIDA],
        [SECCION],
        FORMAT([FECHAREGISTROINCUMPLIMIENTO], 'yyyy/MM/dd') AS [FECHAREGISTROINCUMPLIMIENTO],
        [TIPOINCUMPLIMIENTO],
        [NUMEROTITULOSINCUMPLIDOS],
        [NUMEROINCUMPLIMIENTO],
        [CAUSANTEINCUMPLIMIENTO],
        [RAZONINCUMPLIMIENTO],
        [TIPOMODIFICACION],
        FORMAT([FECHA_INFO], 'yyyy/MM/dd')                 AS [FECHA_INFO]
    FROM [SILVER].[RR].[083_ENT_CVT_IN]
    WHERE [FECHACONCERTACION] = @FECHA;
END;
GO
PRINT '>> ION.dbo.[083_ENT_CVT_IN] actualizado.';
PRINT '>> Correccion 083_ENT_CVT_IN completada.';
GO
