/* ============================================================================
   156_ENT_SWAP_IV_COM_ROLLBACK.sql
   Fin     : Revertir los cambios aplicados por 156_ENT_SWAP_IV_COM_CORRECCION.sql.
   IMPORTANTE:
     - Los datos en FECHAINFO se pierden al hacer DROP COLUMN.
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
CREATE OR ALTER PROCEDURE [dbo].[156_ENT_SWAP_IV_COM]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SELECT
        [ID],
        [FECHA_EXTRACCION],
        [CONT],
        [FECHA],
        [NU_ID],
        [NU_FL_RE],
        [IMP_BA_RE],
        [FEIN_FL_RE],
        [FEIN_VE_RE],
        [SUBY_RE],
        [CVE_TIT_RE],
        [NU_SUBY_RE],
        [CUANT_RE],
        [PRE_SUB_RE],
        [NU_FL_EN],
        [IMP_BA_EN],
        [FEIN_FL_EN],
        [FEIN_VE_EN],
        [SUBY_EN],
        [CVE_TIT_EN],
        [NU_SUBY_EN],
        [CUANT_EN],
        [PRE_SUB_EN],
        [MODIFICA]
    FROM [SILVER].[RR].[156_ENT_SWAP_IV_COM]
    WHERE [FECHA] = @FECHA;

    --EXEC [dbo].[156_ENT_SWAP_IV_COM] @FECHA = '20240420'

    -- Para reportes diarios WHERE FECHA_REPORTE = @Fecha
END;
GO
PRINT '>> ION.dbo.[156_ENT_SWAP_IV_COM] revertido al estado original.';
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
CREATE OR ALTER PROCEDURE [dbo].[156_ENT_SWAP_IV_COM]
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
    DECLARE @NombreJob       NVARCHAR(128) = '[156_ENT_SWAP_IV_COM]';
    DECLARE @FechaIni        DATE,
            @FechaFin        DATE;

    BEGIN TRY
        SET @FechaIni = datefromparts(year(@FechaSistema), month(@FechaSistema), 1)
        SET @FechaFin = Dateadd(month, 1, @FechaIni) --------------------------------------------------------------------------------
            -- QUERY

        IF EXISTS (
            SELECT ID FROM [SILVER].[RR].[156_ENT_SWAP_IV_COM]
            WHERE [FECHA] = @FechaSistema
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[156_ENT_SWAP_IV_COM]
            WHERE [FECHA] = @FechaSistema;

            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

        INSERT INTO [RR].[156_ENT_SWAP_IV_COM] (
            [CONT],
            [FECHA],
            [NU_ID],
            [NU_FL_RE],
            [IMP_BA_RE],
            [FEIN_FL_RE],
            [FEIN_VE_RE],
            [SUBY_RE],
            [CVE_TIT_RE],
            [NU_SUBY_RE],
            [CUANT_RE],
            [PRE_SUB_RE],
            [NU_FL_EN],
            [IMP_BA_EN],
            [FEIN_FL_EN],
            [FEIN_VE_EN],
            [SUBY_EN],
            [CVE_TIT_EN],
            [NU_SUBY_EN],
            [CUANT_EN],
            [PRE_SUB_EN],
            [MODIFICA]
        )
        SELECT
            [CONT],
            [FECHA],
            [NU_ID],
            [NU_FL_RE],
            [IMP_BA_RE],
            [FEIN_FL_RE],
            [FEIN_VE_RE],
            [SUBY_RE],
            [CVE_TIT_RE],
            [NU_SUBY_RE],
            [CUANT_RE],
            [PRE_SUB_RE],
            [NU_FL_EN],
            [IMP_BA_EN],
            [FEIN_FL_EN],
            [FEIN_VE_EN],
            [SUBY_EN],
            [CVE_TIT_EN],
            [NU_SUBY_EN],
            [CUANT_EN],
            [PRE_SUB_EN],
            [MODIFICA]
        FROM [SILVER].[RR].[156_ENT_SWAP_IV_COM]
        WHERE [FECHA] = @FechaSistema;

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
PRINT '>> SILVER.dbo.[156_ENT_SWAP_IV_COM] revertido al estado original.';
GO

/* --------------------------------------------------------------------------
   03 - TABLA: DROP COLUMN FECHAINFO
   -------------------------------------------------------------------------- */
USE [SILVER];
GO
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'RR' AND TABLE_NAME = '156_ENT_SWAP_IV_COM' AND COLUMN_NAME = 'FECHAINFO'
)
BEGIN
    ALTER TABLE [RR].[156_ENT_SWAP_IV_COM]
        DROP COLUMN [FECHAINFO];
    PRINT '>> Columna FECHAINFO eliminada de SILVER.[RR].[156_ENT_SWAP_IV_COM].';
END
ELSE
    PRINT '>> FECHAINFO no existe. Sin cambios.';
GO

PRINT '>> Rollback 156_ENT_SWAP_IV_COM completado.';
GO
