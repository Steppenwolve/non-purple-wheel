/* ============================================================================
   083_ENT_CVT_IN_ROLLBACK.sql
   Fin     : Revertir los cambios aplicados por 083_ENT_CVT_IN_CORRECCION.sql.
   IMPORTANTE:
     - Los datos en FECHA_INFO se pierden al hacer DROP COLUMN.
     - CREATE OR ALTER restaura la definicion PRE-correccion conocida.
   ============================================================================ */

/* --------------------------------------------------------------------------
   01 - SP ION: restaurar definicion original
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

    SELECT
        [ID],
        [FECHA_EXTRACCION],
        [FECHACONCERTACION],
        [NUMEROOPERACIONINCUMPLIDA],
        [SECCION],
        [FECHAREGISTROINCUMPLIMIENTO],
        [TIPOINCUMPLIMIENTO],
        [NUMEROTITULOSINCUMPLIDOS],
        [NUMEROINCUMPLIMIENTO],
        [CAUSANTEINCUMPLIMIENTO],
        [RAZONINCUMPLIMIENTO],
        [TIPOMODIFICACION]
    FROM [SILVER].[RR].[083_ENT_CVT_IN]
    WHERE [FECHACONCERTACION] = @FECHA;

    --EXEC [dbo].[083_ENT_CVT_IN] @FECHA = '20240420'

    -- Para reportes diarios WHERE FECHA_REPORTE = @Fecha
END;
GO
PRINT '>> ION.dbo.[083_ENT_CVT_IN] revertido al estado original.';
GO

/* --------------------------------------------------------------------------
   02 - SP SILVER: restaurar definicion original
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

    DECLARE @SQL             NVARCHAR(MAX);
    DECLARE @MensajeError    NVARCHAR(MAX) = '';
    DECLARE @ExitoEjecucion  BIT           = 1;
    DECLARE @FilasInsertadas INT           = 0;
    DECLARE @LogMessage      NVARCHAR(MAX) = '';
    DECLARE @DetallesLog     NVARCHAR(MAX) = '';
    DECLARE @FechaInicio     DATETIME      = GETDATE();
    DECLARE @FilasEliminadas INT           = 0;
    DECLARE @NombreJob       NVARCHAR(128) = '[083_ENT_CVT_IN]';
    DECLARE @FechaIni        DATE,
            @FechaFin        DATE;

    BEGIN TRY
        SET @FechaIni = datefromparts(year(@FechaSistema), month(@FechaSistema), 1)
        SET @FechaFin = Dateadd(month, 1, @FechaIni) --------------------------------------------------------------------------------
            -- QUERY

        IF EXISTS (
            SELECT ID FROM [SILVER].[RR].[083_ENT_CVT_IN]
            WHERE [FECHACONCERTACION] = @FechaSistema
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[083_ENT_CVT_IN]
            WHERE [FECHACONCERTACION] = @FechaSistema;

            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

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
            [TIPOMODIFICACION]
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
            [TIPOMODIFICACION]
        FROM [SILVER].[RR].[083_ENT_CVT_IN]
        WHERE [FECHACONCERTACION] = @FechaSistema;

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
            'Se ha producido un error durante la ejecucion de.' + @NombreJob + CHAR(13)+CHAR(10) +
            '- Nombre del Job: '           + ISNULL(@NombreJob,     'No especificado') + CHAR(13)+CHAR(10) +
            '- Programado por: '           + ISNULL(@ProgramadorJob, 'No especificado') + CHAR(13)+CHAR(10) +
            '- Fecha y hora de inicio: '   + CONVERT(VARCHAR, @FechaInicio,      120)   + CHAR(13)+CHAR(10) +
            '- Fecha y hora de fin: '      + CONVERT(VARCHAR, @FechaFinalizacion, 120)   + CHAR(13)+CHAR(10) +
            '- Duracion: '                 + @DuracionEjecucion + CHAR(13)+CHAR(10) +
            'Mensaje de Error: '           + @MensajeError      + CHAR(13)+CHAR(10) +
            'Log: '                        + @DetallesLog;
        BEGIN TRY
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = @PerfilCorreo,
                @recipients   = @CorreoNotificacion,
                @subject      = @Asunto,
                @body         = @Cuerpo,
                @body_format  = 'TEXT',
                @importance   = 'High';
            SET @DetallesLog = @DetallesLog + 'Alerta de error enviada exitosamente.' + CHAR(13)+CHAR(10);
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

    SET @LogMessage = 'Proceso completado y registrado en la tabla de log.';
    PRINT @LogMessage;
END;
GO
PRINT '>> SILVER.dbo.[083_ENT_CVT_IN] revertido al estado original.';
GO

/* --------------------------------------------------------------------------
   03 - TABLA: DROP COLUMN FECHA_INFO
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'RR' AND TABLE_NAME = '083_ENT_CVT_IN' AND COLUMN_NAME = 'FECHA_INFO'
)
BEGIN
    ALTER TABLE [RR].[083_ENT_CVT_IN]
        DROP COLUMN [FECHA_INFO];
    PRINT '>> Columna FECHA_INFO eliminada de SILVER.[RR].[083_ENT_CVT_IN].';
END
ELSE
    PRINT '>> FECHA_INFO no existe. Sin cambios.';
GO

PRINT '>> Rollback 083_ENT_CVT_IN completado.';
GO
