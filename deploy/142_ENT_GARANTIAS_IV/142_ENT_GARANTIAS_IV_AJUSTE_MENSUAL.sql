-- ============================================================
-- AJUSTE  142_ENT_GARANTIAS_IV — Cambio de periodo Semanal → Mensual
-- ============================================================

-- ============================================================
-- SECTION 01 | SP SILVER — cambiar filtro semanal a mensual
-- ============================================================
USE [SILVER]
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

    DECLARE @MensajeError    NVARCHAR(MAX) = '';
    DECLARE @ExitoEjecucion  BIT           = 1;
    DECLARE @FilasInsertadas INT           = 0;
    DECLARE @LogMessage      NVARCHAR(MAX) = '';
    DECLARE @DetallesLog     NVARCHAR(MAX) = '';
    DECLARE @FechaInicio     DATETIME      = GETDATE();
    DECLARE @FilasEliminadas INT           = 0;
    DECLARE @NombreJob       NVARCHAR(128) = '[142_ENT_GARANTIAS_IV]';
    DECLARE @FechaIni        DATE;
    DECLARE @FechaFin        DATE;
	
	-- 142_ENT_GARANTIAS_IV || Layout_Garantias_V2.xlsx || FILE_GARANTIAS_IV  ||  Mensual

    BEGIN TRY
        SET @FechaIni = DATEFROMPARTS(YEAR(@FechaSistema), MONTH(@FechaSistema), 1);
        SET @FechaFin = DATEADD(MONTH, 1, @FechaIni);

        IF EXISTS (
            SELECT 1 FROM [SILVER].[RR].[142_ENT_GARANTIAS_IV]
            WHERE [FECHAINFO] >= @FechaIni AND [FECHAINFO] < @FechaFin
        )
        BEGIN
            DELETE FROM [SILVER].[RR].[142_ENT_GARANTIAS_IV]
            WHERE [FECHAINFO] >= @FechaIni AND [FECHAINFO] < @FechaFin;
            SET @FilasEliminadas = @@ROWCOUNT;
            SET @LogMessage = 'Registros eliminados: ' + CAST(@FilasEliminadas AS NVARCHAR(10));
            PRINT @LogMessage;
            SET @DetallesLog = @DetallesLog + @LogMessage + CHAR(13) + CHAR(10);
        END;

        INSERT INTO [RR].[142_ENT_GARANTIAS_IV]
            ([OFICINA], [CONT], [NETEO_POS], [TIP_CONTRAT], [EXP_POT], [RSG_MAX], [FECHAINFO])
        SELECT
            R.[OFICINA], R.[CONT], R.[NETEO_POS], R.[TIP_CONTRAT], R.[EXP_POT], R.[RSG_MAX], R.[FECHAINFO]
        FROM [BRONZE].[LMDA].[GARANTIAS_IV] R
        WHERE R.[FECHAINFO] >= @FechaIni AND R.[FECHAINFO] < @FechaFin;

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

    IF @ExitoEjecucion = 0
        AND @CorreoNotificacion IS NOT NULL
        AND @PerfilCorreo IS NOT NULL
    BEGIN
        DECLARE @Asunto NVARCHAR(255) = 'ALERTA: Error en ' + @NombreJob;
        DECLARE @Cuerpo NVARCHAR(MAX) =
            'Error en ' + @NombreJob + CHAR(13) + CHAR(10) +
            '- Programado por: ' + ISNULL(@ProgramadorJob, 'No especificado') + CHAR(13) + CHAR(10) +
            '- Inicio: '         + CONVERT(VARCHAR, @FechaInicio, 120)         + CHAR(13) + CHAR(10) +
            '- Mensaje: '        + @MensajeError + CHAR(13) + CHAR(10) +
            'Log:' + CHAR(13) + CHAR(10) + @DetallesLog;
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
            SET @DetallesLog = @DetallesLog + 'Error al enviar alerta: ' + ERROR_MESSAGE() + CHAR(13) + CHAR(10);
        END CATCH
    END

    INSERT INTO dbo.LogSilverDiario
        (FechaEjecucion, FilasInsertadas, EstadoEjecucion, MensajeError, DetallesLog, NombreJob, ProgramadorJob)
    VALUES
        (@FechaInicio, @FilasInsertadas,
         CASE WHEN @ExitoEjecucion = 1 THEN 'Exitoso' ELSE 'Error' END,
         CASE WHEN @ExitoEjecucion = 1 THEN NULL      ELSE @MensajeError END,
         @DetallesLog, @NombreJob, @ProgramadorJob);
END;
GO

-- ============================================================
-- SECTION 02 | INDICE_REPORTES — actualizar frecuencia a Mensual
-- ============================================================
USE [ION]
GO

UPDATE [dbo].[INDICE_REPORTES]
SET [frecuencia] = 'Mensual'
WHERE [numero] = 142;
GO

-- ============================================================
-- SECTION 03 | SP ION — cambiar filtro semanal a mensual
-- ============================================================
USE [ION]
GO

CREATE OR ALTER PROCEDURE [dbo].[142_ENT_GARANTIAS_IV]
    @FECHA DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @FechaIni DATE = DATEFROMPARTS(YEAR(@FECHA), MONTH(@FECHA), 1);
    DECLARE @FechaFin DATE = DATEADD(MONTH, 1, @FechaIni);
	-- 142_ENT_GARANTIAS_IV || Layout_Garantias_V2.xlsx || FILE_GARANTIAS_IV  ||  Mensual
    SELECT
        [OFICINA]                           AS [OFICINA],
        [CONT]                              AS [CONT],
        [NETEO_POS]                         AS [NETEO_POS],
        [TIP_CONTRAT]                       AS [TIP_CONTRAT],
        [EXP_POT]                           AS [EXP_POT],
        [RSG_MAX]                           AS [RSG_MAX],
        FORMAT([FECHAINFO], 'yyyy/MM/dd')   AS [FECHAINFO]
    FROM [SILVER].[RR].[142_ENT_GARANTIAS_IV]
    WHERE [FECHAINFO] >= @FechaIni AND [FECHAINFO] < @FechaFin;
END;
GO
