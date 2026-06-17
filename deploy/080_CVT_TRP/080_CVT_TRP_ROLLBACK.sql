/* ============================================================================
   080_CVT_TRP_ROLLBACK.sql
   Fin     : Revertir los cambios aplicados por 080_CVT_TRP_CORRECCION.sql,
             devolviendo SILVER.[RR].[080_CVT TRP] y ambos SPs al estado
             original previo a la correccion.
   IMPORTANTE:
     - CREATE OR ALTER no preserva la definicion anterior del SP.
       Este rollback restaura la definicion conocida PRE-correccion.
     - Los datos existentes en FECHA_INFO quedaran en NULL tras el DROP
       de esa columna; no es recuperable sin respaldo previo.
   ============================================================================ */

/* --------------------------------------------------------------------------
   01 - TABLA: revertir NUMTITULOS  numeric(12,0) -> int
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
DECLARE @tipo SYSNAME;
SELECT @tipo = DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'RR' AND TABLE_NAME = '080_CVT TRP' AND COLUMN_NAME = 'NUMTITULOS';

IF @tipo = 'numeric'
BEGIN
    ALTER TABLE [RR].[080_CVT TRP]
        ALTER COLUMN [NUMTITULOS] int NOT NULL;
    PRINT '>> NUMTITULOS revertido: numeric(12,0) -> int.';
END
ELSE
    PRINT '>> NUMTITULOS ya es ' + ISNULL(@tipo,'?') + '. Sin cambios.';
GO

/* --------------------------------------------------------------------------
   02 - TABLA: eliminar columna FECHA_INFO
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'RR' AND TABLE_NAME = '080_CVT TRP' AND COLUMN_NAME = 'FECHA_INFO'
)
BEGIN
    ALTER TABLE [RR].[080_CVT TRP]
        DROP COLUMN [FECHA_INFO];
    PRINT '>> Columna FECHA_INFO eliminada de SILVER.[RR].[080_CVT TRP].';
END
ELSE
    PRINT '>> FECHA_INFO no existe. Sin cambios.';
GO

/* --------------------------------------------------------------------------
   03 - SP SILVER: restaurar definicion original (pre-correccion)
        - Ventana mensual presente (aunque no se usaba en WHERE)
        - Sin @FechaDia
        - Sin FECHA_INFO en INSERT/SELECT
        - WHERE usa @FechaSistema directamente
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[080_CVT TRP]
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
    DECLARE @NombreJob       NVARCHAR(128) = '[080_CVT TRP]';
    DECLARE @FechaIni        DATE,
            @FechaFin        DATE;

    BEGIN TRY
        SET @FechaIni = datefromparts(year(@FechaSistema), month(@FechaSistema), 1)
        SET @FechaFin = Dateadd(month, 1, @FechaIni)

        IF EXISTS (
            SELECT ID FROM [SILVER].[RR].[080_CVT TRP]
            WHERE [FECHATRANS] = @FechaSistema
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[080_CVT TRP]
            WHERE [FECHATRANS] = @FechaSistema;

            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

        INSERT INTO [RR].[080_CVT TRP] (
            [INSTCUENTRANS], [FECHATRANS],    [TIPOTRANSCUST],
            [TITULOBJTRANS], [NUMTITULOS],    [CUSTCONTRAPARTE],
            [NUMIDTRANS],    [TIPOMODIFICACION]
        )
        SELECT
            [INSTCUENTRANS], [FECHATRANS],    [TIPOTRANSCUST],
            [TITULOBJTRANS], [NUMTITULOS],    [CUSTCONTRAPARTE],
            [NUMIDTRANS],    [TIPOMODIFICACION]
        FROM [SILVER].[RR].[080_CVT TRP]
        WHERE [FECHATRANS] = @FechaSistema;

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
PRINT '>> SILVER.dbo.[080_CVT TRP] revertido al estado original.';
GO

/* --------------------------------------------------------------------------
   04 - SP ION: restaurar definicion original (pre-correccion)
        - Incluia ID y FECHA_EXTRACCION en el SELECT
        - Sin FECHA_INFO
        - Con comentario muerto al final
   -------------------------------------------------------------------------- */
USE [ION];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[080_CVT TRP]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SELECT
        [ID],
        [FECHA_EXTRACCION],
        [INSTCUENTRANS],
        [FECHATRANS],
        [TIPOTRANSCUST],
        [TITULOBJTRANS],
        [NUMTITULOS],
        [CUSTCONTRAPARTE],
        [NUMIDTRANS],
        [TIPOMODIFICACION]
    FROM [SILVER].[RR].[080_CVT TRP]
    WHERE [FECHATRANS] = @FECHA;
END;
GO
PRINT '>> ION.dbo.[080_CVT TRP] revertido al estado original.';
PRINT '>> Rollback 080_CVT_TRP completado.';
GO
