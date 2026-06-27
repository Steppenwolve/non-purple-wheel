/* ============================================================================
   122_ENT_REPORTOS_CANASTA_ROLLBACK.sql
   Fin: Revertir el AJUSTE y restaurar los SPs originales.
        La tabla SILVER y BRONZE no se modifican (solo cambian los SPs).
   ============================================================================ */

/* ----------------------------------------------------------------------------
   01 - SILVER SP: restaurar original (filtro por FECHACONCERTACION, ventana mensual)
   ---------------------------------------------------------------------------- */
USE [SILVER];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[122_ENT_REPORTOS_CANASTA]
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
    DECLARE @NombreJob NVARCHAR(128) = '[122_ENT_REPORTOS_CANASTA]   ';
    DECLARE @FechaIni DATE, @FechaFin DATE;

    BEGIN TRY
        SET @FechaIni = DATEFROMPARTS(YEAR(@FechaSistema), MONTH(@FechaSistema), 1);
        SET @FechaFin = DATEADD(MONTH, 1, @FechaIni);

        IF EXISTS (SELECT ID FROM [SILVER].[RR].[122_ENT_REPORTOS_CANASTA]
                   WHERE [FECHACONCERTACION] = @FechaSistema)
        BEGIN
            DELETE FROM [SILVER].[RR].[122_ENT_REPORTOS_CANASTA]
            WHERE [FECHACONCERTACION] = @FechaSistema;
            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13)+CHAR(10);
        END;

        INSERT INTO [RR].[122_ENT_REPORTOS_CANASTA] (
            [FECHACONCERTACION],[TITULOOBJETOREPORTO],[PRECIOUNITARIOTITULOS],
            [NUMEROTITULOSOBJETOREPORTO],[IMPORTEREPORTO],[HAIRCUT],[FECHA_FIN_COLATERAL],
            [NUMEROIDENTIFICACIONOPERACION],[NUM_ID_CANASTA],[SECCION],
            [EMISION],[SERIE],[TIPOVALOR],[FECHA_INFO]
        )
        SELECT
            C.[FECHACONCERTACION], C.[TITULOOBJETOREPORTO], C.[PRECIOUNITARIOTITULOS],
            C.[NUMEROTITULOSOBJETOREPORTO], C.[IMPORTEREPORTO], C.[HAIRCUT], C.[FECHA_FIN_COLATERAL],
            C.[NUMEROIDENTIFICACIONOPERACION], C.[NUM_ID_CANASTA], C.[SECCION],
            C.[EMISION], C.[SERIE], C.[TIPOVALOR], C.[FECHA_INFO]
        FROM [BRONZE].[LMDA].[CANASTA_REPORTOS] C
        WHERE C.[FECHACONCERTACION] = @FechaSistema;

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

    INSERT INTO dbo.LogSilverDiario
        (FechaEjecucion, FilasInsertadas, EstadoEjecucion, MensajeError, DetallesLog, NombreJob, ProgramadorJob)
    VALUES (@FechaInicio, @FilasInsertadas,
        CASE WHEN @ExitoEjecucion=1 THEN 'Exitoso' ELSE 'Error' END,
        CASE WHEN @ExitoEjecucion=1 THEN NULL ELSE @MensajeError END,
        @DetallesLog, @NombreJob, @ProgramadorJob);
END;
GO
PRINT '>> Restaurado SILVER.dbo.[122_ENT_REPORTOS_CANASTA] (SP original).';
GO

/* ----------------------------------------------------------------------------
   02 - ION SP: restaurar original (filtro por FECHACONCERTACION)
   ---------------------------------------------------------------------------- */
USE [ION];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[122_ENT_REPORTOS_CANASTA]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    SELECT
        FORMAT(C.[FECHACONCERTACION],       'yyyy/MM/dd') AS FECHACONCERTACION,
        C.[TITULOOBJETOREPORTO]                           AS TITULOOBJETOREPORTO,
        C.[PRECIOUNITARIOTITULOS]                         AS PRECIOUNITARIOTITULOS,
        C.[NUMEROTITULOSOBJETOREPORTO]                    AS NUMEROTITULOSOBJETOREPORTO,
        C.[IMPORTEREPORTO]                                AS IMPORTEREPORTO,
        C.[HAIRCUT]                                       AS HAIRCUT,
        FORMAT(C.[FECHA_FIN_COLATERAL],     'yyyy/MM/dd') AS FECHA_FIN_COLATERAL,
        C.[NUMEROIDENTIFICACIONOPERACION]                 AS NUMEROIDENTIFICACIONOPERACION,
        C.[NUM_ID_CANASTA]                                AS NUM_ID_CANASTA,
        C.[SECCION]                                       AS SECCION,
        C.[EMISION]                                       AS EMISION,
        C.[SERIE]                                         AS SERIE,
        C.[TIPOVALOR]                                     AS TIPOVALOR,
        FORMAT(C.[FECHA_INFO],              'yyyy/MM/dd') AS FECHA_INFO
    FROM [SILVER].[RR].[122_ENT_REPORTOS_CANASTA] C
    WHERE C.[FECHACONCERTACION] = @FECHA;
END;
GO
PRINT '>> Restaurado ION.dbo.[122_ENT_REPORTOS_CANASTA] (SP original).';
GO
PRINT '>> Rollback 122_ENT_REPORTOS_CANASTA completado.';
GO
