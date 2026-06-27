/* ============================================================================
   142_ENT_GARANTIAS_IV_ROLLBACK.sql
   Fin: Revertir el AJUSTE y restaurar el estado original:
        - Renombrar FECHAINFO -> FECHA_REPORTE (sp_rename, preserva datos).
        - Eliminar BRONZE.[LMDA].[GARANTIAS_IV].
        - Restaurar SP SILVER (self-select, filtro por FECHA_REPORTE).
        - Restaurar SP ION (original con ID, FECHA_EXTRACCION, FECHA_REPORTE).
   ============================================================================ */

/* ----------------------------------------------------------------------------
   00 - Eliminar BRONZE.[LMDA].[GARANTIAS_IV]
   ---------------------------------------------------------------------------- */
USE [BRONZE];
GO
IF EXISTS (
    SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
    WHERE s.name='LMDA' AND o.name='GARANTIAS_IV' AND o.type='U'
)
    DROP TABLE [LMDA].[GARANTIAS_IV];
PRINT '>> BRONZE.[LMDA].[GARANTIAS_IV] eliminada (si existia).';
GO

/* ----------------------------------------------------------------------------
   01 - SILVER: renombrar FECHAINFO -> FECHA_REPORTE
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='142_ENT_GARANTIAS_IV' AND COLUMN_NAME='FECHAINFO')
   AND NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
                   WHERE TABLE_SCHEMA='RR' AND TABLE_NAME='142_ENT_GARANTIAS_IV' AND COLUMN_NAME='FECHA_REPORTE')
BEGIN
    EXEC sp_rename '[RR].[142_ENT_GARANTIAS_IV].[FECHAINFO]', 'FECHA_REPORTE', 'COLUMN';
    PRINT '>> Columna FECHAINFO revertida a FECHA_REPORTE.';
END
ELSE
    PRINT '>> Revert rename: ya aplicado o no necesario.';
GO

/* ----------------------------------------------------------------------------
   02 - SILVER SP: restaurar original (self-select, filtro FECHA_REPORTE)
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[142_ENT_GARANTIAS_IV]
    @CorreoNotificacion NVARCHAR(255) = NULL,
    @PerfilCorreo       NVARCHAR(255) = NULL,
    @ProgramadorJob     NVARCHAR(128) = NULL,
    @FechaSistema       DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @MensajeError NVARCHAR(MAX) = '';
    DECLARE @ExitoEjecucion BIT = 1;
    DECLARE @FilasInsertadas INT = 0;
    DECLARE @LogMessage NVARCHAR(MAX) = '';
    DECLARE @DetallesLog NVARCHAR(MAX) = '';
    DECLARE @FechaInicio DATETIME = GETDATE();
    DECLARE @FilasEliminadas INT = 0;
    DECLARE @NombreJob NVARCHAR(128) = '[142_ENT_GARANTIAS_IV]  ';
    DECLARE @FechaIni DATE, @FechaFin DATE;

    BEGIN TRY
        SET @FechaIni = DATEADD(DAY, -(DATEPART(WEEKDAY, @FechaSistema) + 5) % 7, @FechaSistema);
        SET @FechaFin = DATEADD(DAY, 7, @FechaIni);

        IF EXISTS (SELECT ID FROM [SILVER].[RR].[142_ENT_GARANTIAS_IV]
                   WHERE [FECHA_REPORTE] >= @FechaIni AND [FECHA_REPORTE] < @FechaFin)
        BEGIN
            DELETE FROM [SILVER].[RR].[142_ENT_GARANTIAS_IV]
            WHERE [FECHA_REPORTE] >= @FechaIni AND [FECHA_REPORTE] < @FechaFin;
            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13)+CHAR(10);
        END;

        INSERT INTO [RR].[142_ENT_GARANTIAS_IV] (
            [OFICINA],[CONT],[NETEO_POS],[TIP_CONTRAT],[EXP_POT],[RSG_MAX],[FECHA_REPORTE]
        )
        SELECT [OFICINA],[CONT],[NETEO_POS],[TIP_CONTRAT],[EXP_POT],[RSG_MAX],
               @FechaIni AS [FECHA_REPORTE]
        FROM [SILVER].[RR].[142_ENT_GARANTIAS_IV]
        WHERE [FECHA_REPORTE] >= @FechaIni AND [FECHA_REPORTE] < @FechaFin;

        SET @FilasInsertadas = @@ROWCOUNT;
        SET @LogMessage = 'Proceso completado. Filas totales: ' + CAST(@FilasInsertadas AS NVARCHAR(10));
        PRINT @LogMessage;
        SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13)+CHAR(10);
    END TRY
    BEGIN CATCH
        SET @ExitoEjecucion = 0;
        SET @MensajeError = ERROR_MESSAGE();
        SET @DetallesLog = @DetallesLog + 'Error: ' + @MensajeError + CHAR(13)+CHAR(10);
    END CATCH

    IF @ExitoEjecucion=0 AND @CorreoNotificacion IS NOT NULL AND @PerfilCorreo IS NOT NULL
    BEGIN
        DECLARE @Asunto NVARCHAR(255)='ALERTA: Error en ' + @NombreJob;
        DECLARE @Cuerpo NVARCHAR(MAX)='Error en ' + @NombreJob + CHAR(13)+CHAR(10) +
            '- Programado por: ' + ISNULL(@ProgramadorJob,'No especificado') + CHAR(13)+CHAR(10) +
            '- Mensaje: ' + @MensajeError + CHAR(13)+CHAR(10) + 'Log:' + CHAR(13)+CHAR(10) + @DetallesLog;
        BEGIN TRY
            EXEC msdb.dbo.sp_send_dbmail @profile_name=@PerfilCorreo, @recipients=@CorreoNotificacion,
                 @subject=@Asunto, @body=@Cuerpo, @body_format='TEXT', @importance='High';
        END TRY BEGIN CATCH
            SET @DetallesLog = @DetallesLog + 'Error al enviar alerta: ' + ERROR_MESSAGE() + CHAR(13)+CHAR(10);
        END CATCH
    END

    INSERT INTO dbo.LogSilverDiario (FechaEjecucion, FilasInsertadas, EstadoEjecucion,
        MensajeError, DetallesLog, NombreJob, ProgramadorJob)
    VALUES (@FechaInicio, @FilasInsertadas,
        CASE WHEN @ExitoEjecucion=1 THEN 'Exitoso' ELSE 'Error' END,
        CASE WHEN @ExitoEjecucion=1 THEN NULL ELSE @MensajeError END,
        @DetallesLog, @NombreJob, @ProgramadorJob);
END;
GO
PRINT '>> Restaurado SILVER.dbo.[142_ENT_GARANTIAS_IV] (SP original).';
GO

/* ----------------------------------------------------------------------------
   03 - ION SP: restaurar original (con ID, FECHA_EXTRACCION, FECHA_REPORTE)
   ---------------------------------------------------------------------------- */
USE [ION];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[142_ENT_GARANTIAS_IV]
    @FECHA DATE
AS
BEGIN
    DECLARE @FechaIni DATE, @FechaFin DATE;
    SET @FechaIni = DATEADD(DAY, -(DATEPART(WEEKDAY, @FECHA) + 5) % 7, @FECHA);
    SET @FechaFin = DATEADD(DAY, 7, @FechaIni);

    SELECT
        ID, FECHA_EXTRACCION,
        [OFICINA],[CONT],[NETEO_POS],[TIP_CONTRAT],[EXP_POT],[RSG_MAX],[FECHA_REPORTE]
    FROM [SILVER].[RR].[142_ENT_GARANTIAS_IV]
    WHERE [FECHA_REPORTE] >= @FechaIni AND [FECHA_REPORTE] < @FechaFin;
END;
GO
PRINT '>> Restaurado ION.dbo.[142_ENT_GARANTIAS_IV] (SP original).';
GO
PRINT '>> Rollback 142_ENT_GARANTIAS_IV completado.';
GO
